#!/bin/bash
set -eo pipefail

AUTO_YES=0
SKIP_BACKUP=0
SOURCE_OVERRIDE=""
MODE_OVERRIDE=""
TARGET_INPUT="."

usage() {
  cat <<EOF
Usage: $0 [options] [project-root]

Migrate tasks from a legacy folder into canonical .dotcortex/tasks.

Options:
  --from PATH         Source task directory (absolute or relative to project root)
  --mode MODE         copy | move | skip
  --no-backup         Do not create backup archive before migration
  -y, --yes           Non-interactive defaults (backup=yes, mode=copy)
  -h, --help          Show help
EOF
}

prompt_yes_no() {
  local message="$1"
  local default="${2:-n}"
  local suffix
  local response

  if [ "$AUTO_YES" -eq 1 ]; then
    echo "$default"
    return 0
  fi

  if [ "$default" = "y" ]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  response=""
  read -r -p "$message $suffix " response || true
  response="$(printf "%s" "$response" | tr '[:upper:]' '[:lower:]')"

  if [ -z "$response" ]; then
    echo "$default"
  else
    echo "$response"
  fi
}

read_json_value() {
  local file="$1"
  local key="$2"

  if [ ! -f "$file" ]; then
    return 1
  fi

  sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$file" | head -n 1
}

path_exists_in_target() {
  local candidate="$1"
  if [ -z "$candidate" ]; then
    return 1
  fi

  if [ "${candidate#/}" != "$candidate" ]; then
    [ -e "$candidate" ]
    return $?
  fi

  [ -e "$TARGET_DIR/$candidate" ]
}

to_abs_path() {
  local candidate="$1"
  if [ "${candidate#/}" != "$candidate" ]; then
    echo "$candidate"
  else
    echo "$TARGET_DIR/$candidate"
  fi
}

add_candidate() {
  local candidate="$1"
  local existing

  if [ -z "$candidate" ]; then
    return 0
  fi

  if ! path_exists_in_target "$candidate"; then
    return 0
  fi

  for existing in "${CANDIDATES[@]}"; do
    if [ "$existing" = "$candidate" ]; then
      return 0
    fi
  done

  CANDIDATES+=("$candidate")
}

create_backup() {
  local backup_root="$TARGET_DIR/.dotcortex/backups"
  local stamp
  local archive
  local include_paths=()

  mkdir -p "$backup_root"
  stamp="$(date -u +"%Y%m%dT%H%M%SZ")"
  archive="$backup_root/manual-task-migration-$stamp.tar.gz"

  for path in ".claude" ".tasks" "claude_tasks" ".claude/tasks" "tasks" ".dotcortex/tasks"; do
    if [ -e "$TARGET_DIR/$path" ]; then
      include_paths+=("$path")
    fi
  done

  if [ "${#include_paths[@]}" -eq 0 ]; then
    echo ""
    return 0
  fi

  tar -czf "$archive" -C "$TARGET_DIR" "${include_paths[@]}"
  echo "$archive"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --from)
      SOURCE_OVERRIDE="${2:-}"
      shift
      ;;
    --mode)
      MODE_OVERRIDE="${2:-}"
      shift
      ;;
    --no-backup)
      SKIP_BACKUP=1
      ;;
    -y|--yes)
      AUTO_YES=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      TARGET_INPUT="$1"
      ;;
  esac
  shift
done

if ! TARGET_DIR="$(cd "$TARGET_INPUT" 2>/dev/null && pwd)"; then
  echo "Error: Project root does not exist: $TARGET_INPUT"
  exit 1
fi

mkdir -p "$TARGET_DIR/.dotcortex/tasks"

CANDIDATES=()
add_candidate "$SOURCE_OVERRIDE"
add_candidate "$(read_json_value "$TARGET_DIR/.claude/.localmem.json" "tasks_dir" || true)"
add_candidate "$(read_json_value "$TARGET_DIR/.claude/.dotcortex.json" "tasks_dir" || true)"
add_candidate "$(read_json_value "$TARGET_DIR/.dotcortex/config.json" "tasks_dir" || true)"
add_candidate "claude_tasks"
add_candidate ".tasks"
add_candidate ".claude/tasks"
add_candidate "tasks"

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  echo "No task directories found. Nothing to migrate."
  exit 0
fi

selected_source=""
if [ -n "$SOURCE_OVERRIDE" ]; then
  if ! path_exists_in_target "$SOURCE_OVERRIDE"; then
    echo "Error: --from path not found: $SOURCE_OVERRIDE"
    exit 1
  fi
  selected_source="$SOURCE_OVERRIDE"
elif [ "${#CANDIDATES[@]}" -eq 1 ] || [ "$AUTO_YES" -eq 1 ]; then
  selected_source="${CANDIDATES[0]}"
else
  echo "Detected task source candidates:"
  i=1
  for candidate in "${CANDIDATES[@]}"; do
    echo "  [$i] $candidate"
    i=$((i + 1))
  done

  read -r -p "Choose source [1]: " choice || true
  choice="${choice:-1}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#CANDIDATES[@]}" ]; then
    echo "Invalid selection: $choice"
    exit 1
  fi
  selected_source="${CANDIDATES[$((choice - 1))]}"
fi

source_abs="$(to_abs_path "$selected_source")"
target_abs="$TARGET_DIR/.dotcortex/tasks"

if [ "$source_abs" = "$target_abs" ]; then
  echo "Selected source is already canonical (.dotcortex/tasks)."
  exit 0
fi

mode="$MODE_OVERRIDE"
if [ -z "$mode" ]; then
  if [ "$AUTO_YES" -eq 1 ]; then
    mode="copy"
  else
    read -r -p "Migration mode [copy/move/skip] (default: copy): " mode || true
    mode="$(printf "%s" "$mode" | tr '[:upper:]' '[:lower:]')"
    mode="${mode:-copy}"
  fi
fi

case "$mode" in
  copy|move|skip) ;;
  *)
    echo "Error: invalid mode '$mode' (expected copy|move|skip)"
    exit 1
    ;;
esac

echo "Project root: $TARGET_DIR"
echo "Task source:  $selected_source"
echo "Task target:  .dotcortex/tasks"
echo "Mode:         $mode"

if [ "$mode" = "skip" ]; then
  echo "Skipped migration."
  exit 0
fi

if [ "$SKIP_BACKUP" -eq 0 ]; then
  backup_answer="$(prompt_yes_no "Create backup archive before migrating?" "y")"
  if [ "$backup_answer" = "y" ]; then
    backup_archive="$(create_backup)"
    if [ -n "$backup_archive" ]; then
      echo "Backup: $backup_archive"
    fi
  fi
fi

cp -R "$source_abs"/. "$target_abs"/

if [ "$mode" = "move" ]; then
  if [ -L "$source_abs" ] || [ -f "$source_abs" ]; then
    rm -f "$source_abs"
  else
    rm -rf "$source_abs"
  fi
fi

if [ -e "$TARGET_DIR/.tasks" ] || [ -L "$TARGET_DIR/.tasks" ]; then
  rm -rf "$TARGET_DIR/.tasks"
fi

if ! ln -s ".dotcortex/tasks" "$TARGET_DIR/.tasks" 2>/dev/null; then
  mkdir -p "$TARGET_DIR/.tasks"
  cp -R "$TARGET_DIR/.dotcortex/tasks"/. "$TARGET_DIR/.tasks"/ 2>/dev/null || true
  echo "Compatibility view: .tasks copied (symlink unavailable)"
else
  echo "Compatibility view: .tasks -> .dotcortex/tasks"
fi

file_count="$(find "$target_abs" -type f | wc -l | tr -d ' ')"
echo "Done. Canonical task files: $file_count"
