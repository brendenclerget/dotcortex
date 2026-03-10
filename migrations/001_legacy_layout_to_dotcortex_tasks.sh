#!/bin/bash
set -eo pipefail

if [ -z "${TARGET_DIR:-}" ]; then
  echo "Migration error: TARGET_DIR is required."
  exit 1
fi

INTERACTIVE="${INTERACTIVE:-0}"
AUTO_YES="${AUTO_YES:-0}"
TASKS_SOURCE_OVERRIDE="${TASKS_SOURCE_OVERRIDE:-}"
TASKS_MODE_OVERRIDE="${TASKS_MODE_OVERRIDE:-}"

prompt_yes_no() {
  local message="$1"
  local default="${2:-n}"
  local suffix
  local response

  if [ "$AUTO_YES" -eq 1 ]; then
    echo "y"
    return 0
  fi

  if [ "$INTERACTIVE" -ne 1 ]; then
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

create_pre_migration_backup() {
  local backup_root="$TARGET_DIR/.dotcortex/backups"
  local stamp
  local archive
  local include_paths=()

  mkdir -p "$backup_root"
  stamp="$(date -u +"%Y%m%dT%H%M%SZ")"
  archive="$backup_root/pre-migration-$stamp.tar.gz"

  for path in ".claude" ".tasks" "claude_tasks" ".claude/tasks" "tasks"; do
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

read_legacy_tasks_dir() {
  local config_file
  local parsed

  for config_file in "$TARGET_DIR/.claude/.localmem.json" "$TARGET_DIR/.claude/.dotcortex.json"; do
    if [ -f "$config_file" ]; then
      parsed="$(sed -n 's/.*"tasks_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$config_file" | head -n 1)"
      if [ -n "$parsed" ]; then
        echo "$parsed"
        return 0
      fi
    fi
  done

  echo ""
}

legacy_layout_detected=0
for marker in \
  ".claude/.localmem.json" \
  ".claude/.dotcortex.json" \
  ".claude/skills" \
  ".claude/knowledge" \
  ".claude/memory" \
  "claude_tasks" \
  ".claude/tasks"; do
  if [ -e "$TARGET_DIR/$marker" ]; then
    legacy_layout_detected=1
    break
  fi
done

if [ "$legacy_layout_detected" -ne 1 ]; then
  echo "  - no legacy layout markers found"
  exit 0
fi

echo "  - legacy layout detected (.claude/ and/or legacy task paths)"
echo "  - recommendation: back up .claude and task folders before migration"

backup_response="$(prompt_yes_no "Create an automatic pre-migration backup archive now?" "y")"
if [ "$backup_response" = "y" ]; then
  backup_archive="$(create_pre_migration_backup)"
  if [ -n "$backup_archive" ]; then
    echo "  - backup created: $backup_archive"
  else
    echo "  - nothing to back up yet"
  fi
else
  continue_without_backup="$(prompt_yes_no "Continue without backup?" "n")"
  if [ "$continue_without_backup" != "y" ]; then
    echo "  - migration skipped. Re-run install when backup is ready."
    exit 0
  fi
fi

mkdir -p "$TARGET_DIR/.dotcortex/tasks"

legacy_tasks_dir="$(read_legacy_tasks_dir)"
CANDIDATES=()

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

add_candidate "$TASKS_SOURCE_OVERRIDE"
add_candidate "$legacy_tasks_dir"
add_candidate "claude_tasks"
add_candidate ".tasks"
add_candidate ".claude/tasks"
add_candidate "tasks"

detected_tasks_source=""
if [ "${#CANDIDATES[@]}" -gt 0 ]; then
  detected_tasks_source="${CANDIDATES[0]}"
fi

if [ -z "$detected_tasks_source" ]; then
  echo "  - no existing task directory found; created canonical .dotcortex/tasks"
  exit 0
fi

if [ -n "$TASKS_SOURCE_OVERRIDE" ]; then
  if ! path_exists_in_target "$TASKS_SOURCE_OVERRIDE"; then
    echo "  - error: TASKS_SOURCE_OVERRIDE path not found: $TASKS_SOURCE_OVERRIDE"
    exit 1
  fi
  detected_tasks_source="$TASKS_SOURCE_OVERRIDE"
elif [ "$INTERACTIVE" -eq 1 ] && [ "$AUTO_YES" -ne 1 ] && [ "${#CANDIDATES[@]}" -gt 1 ]; then
  echo "  - multiple task source candidates detected:"
  idx=1
  for candidate in "${CANDIDATES[@]}"; do
    echo "    [$idx] $candidate"
    idx=$((idx + 1))
  done

  selected_idx=""
  read -r -p "Choose task source [1]: " selected_idx || true
  selected_idx="${selected_idx:-1}"

  if [[ "$selected_idx" =~ ^[0-9]+$ ]] && [ "$selected_idx" -ge 1 ] && [ "$selected_idx" -le "${#CANDIDATES[@]}" ]; then
    detected_tasks_source="${CANDIDATES[$((selected_idx - 1))]}"
  fi
elif [ "$INTERACTIVE" -eq 1 ] && [ "$AUTO_YES" -ne 1 ]; then
  chosen_source=""
  read -r -p "Task directory to migrate from [$detected_tasks_source]: " chosen_source || true
  detected_tasks_source="${chosen_source:-$detected_tasks_source}"
fi

source_abs="$(to_abs_path "$detected_tasks_source")"
target_abs="$TARGET_DIR/.dotcortex/tasks"

if [ "$source_abs" = "$target_abs" ]; then
  echo "  - tasks already in canonical location"
else
  migration_mode="${TASKS_MODE_OVERRIDE:-copy}"
  if [ -n "$TASKS_MODE_OVERRIDE" ]; then
    case "$migration_mode" in
      copy|move|skip) ;;
      *)
        echo "  - error: invalid TASKS_MODE_OVERRIDE '$TASKS_MODE_OVERRIDE' (expected copy|move|skip)"
        exit 1
        ;;
    esac
  elif [ "$AUTO_YES" -ne 1 ] && [ "$INTERACTIVE" -eq 1 ]; then
    user_choice=""
    read -r -p "Migrate tasks into .dotcortex/tasks: [m]ove/[c]opy/[s]kip (default: copy): " user_choice || true
    user_choice="$(printf "%s" "$user_choice" | tr '[:upper:]' '[:lower:]')"
    case "$user_choice" in
      m|move) migration_mode="move" ;;
      s|skip) migration_mode="skip" ;;
      *) migration_mode="copy" ;;
    esac
  fi

  if [ "$migration_mode" = "skip" ]; then
    echo "  - task migration skipped; existing tasks left at $detected_tasks_source"
  else
    if [ -d "$source_abs" ]; then
      cp -R "$source_abs"/. "$target_abs"/
    else
      echo "  - warning: source task path is not a directory: $detected_tasks_source"
    fi

    if [ "$migration_mode" = "move" ] && [ -e "$source_abs" ]; then
      if [ -L "$source_abs" ] || [ -f "$source_abs" ]; then
        rm -f "$source_abs"
      else
        rm -rf "$source_abs"
      fi
    fi

    echo "  - task migration complete ($migration_mode): $detected_tasks_source -> .dotcortex/tasks"
  fi
fi

# Canonical compatibility view for orchestration.
if [ -e "$TARGET_DIR/.tasks" ] || [ -L "$TARGET_DIR/.tasks" ]; then
  rm -rf "$TARGET_DIR/.tasks"
fi

if ! ln -s ".dotcortex/tasks" "$TARGET_DIR/.tasks" 2>/dev/null; then
  mkdir -p "$TARGET_DIR/.tasks"
  cp -R "$TARGET_DIR/.dotcortex/tasks"/. "$TARGET_DIR/.tasks"/ 2>/dev/null || true
  echo "  - symlink unavailable, created .tasks as a copy"
else
  echo "  - linked .tasks -> .dotcortex/tasks"
fi
