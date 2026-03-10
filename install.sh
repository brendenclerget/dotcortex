#!/bin/bash
set -euo pipefail

# dotcortex installer/upgrader
# Usage:
#   /path/to/dotcortex/install.sh [target-directory]
#   /path/to/dotcortex/install.sh --yes [target-directory]

DOTCORTEX_DIR="$(cd "$(dirname "$0")" && pwd)"
MIGRATIONS_DIR="$DOTCORTEX_DIR/migrations"

AUTO_YES=0
RUN_MIGRATIONS=0
TASKS_SOURCE_OVERRIDE=""
TASKS_MODE_OVERRIDE=""
TARGET_INPUT=""
INTERACTIVE=0

if [ -t 0 ]; then
  INTERACTIVE=1
fi

usage() {
  cat <<EOF
Usage: $0 [options] [target-directory]

Options:
  -y, --yes           Non-interactive defaults for prompts
      --with-migrations  Run legacy migration scripts before bootstrap
      --tasks-from PATH  Force legacy task source path for migration 001
      --tasks-mode MODE  Force legacy task migration mode: copy|move|skip
  -h, --help          Show this help
EOF
}

detect_dotcortex_version() {
  local version

  if version="$(git -C "$DOTCORTEX_DIR" describe --tags --abbrev=0 2>/dev/null)"; then
    echo "$version"
    return 0
  fi

  if version="$(git -C "$DOTCORTEX_DIR" rev-parse --short HEAD 2>/dev/null)"; then
    echo "$version"
    return 0
  fi

  echo "dev"
}

read_json_value() {
  local file="$1"
  local key="$2"

  if [ ! -f "$file" ]; then
    return 1
  fi

  sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$file" | head -n 1
}

write_install_metadata() {
  local metadata_file="$TARGET_DIR/.dotcortex/install-info.json"
  local version_file="$TARGET_DIR/.dotcortex/version"
  local now_utc
  local now_date
  local installed_at
  local previous_version
  local previous_version_json

  now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  now_date="$(date -u +"%Y-%m-%d")"
  installed_at="$(read_json_value "$metadata_file" "installed_at" || true)"

  if [ -z "$installed_at" ]; then
    installed_at="$now_utc"
  fi

  previous_version=""
  if [ -f "$version_file" ]; then
    previous_version="$(cat "$version_file")"
  fi

  if [ -n "$previous_version" ]; then
    previous_version_json="\"$previous_version\""
  else
    previous_version_json="null"
  fi

  echo "$DOTCORTEX_VERSION" > "$version_file"

  cat > "$metadata_file" <<EOF
{
  "schema_version": 1,
  "dotcortex_version": "$DOTCORTEX_VERSION",
  "previous_dotcortex_version": $previous_version_json,
  "installed_at": "$installed_at",
  "updated_at": "$now_utc",
  "last_migrated_at": "$now_utc",
  "updated_on": "$now_date",
  "install_mode": "$INSTALL_MODE",
  "migration_state_dir": ".dotcortex/.migrations"
}
EOF
}

run_migrations() {
  local state_dir="$TARGET_DIR/.dotcortex/.migrations"
  local script
  local migration_id
  local marker

  if [ "$RUN_MIGRATIONS" -eq 0 ]; then
    echo "Migration mode: skipped (use --with-migrations to enable)"
    return 0
  fi

  if [ ! -d "$MIGRATIONS_DIR" ]; then
    return 0
  fi

  mkdir -p "$state_dir"

  while IFS= read -r script; do
    migration_id="$(basename "$script" .sh)"
    marker="$state_dir/$migration_id.applied"

    if [ -f "$marker" ]; then
      continue
    fi

    echo "Running migration: $migration_id"
    TARGET_DIR="$TARGET_DIR" \
      DOTCORTEX_DIR="$DOTCORTEX_DIR" \
      DOTCORTEX_VERSION="$DOTCORTEX_VERSION" \
      INSTALL_MODE="$INSTALL_MODE" \
      INTERACTIVE="$INTERACTIVE" \
      AUTO_YES="$AUTO_YES" \
      TASKS_SOURCE_OVERRIDE="$TASKS_SOURCE_OVERRIDE" \
      TASKS_MODE_OVERRIDE="$TASKS_MODE_OVERRIDE" \
      "$script"

    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$marker"
  done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '[0-9][0-9][0-9]_*.sh' | sort)
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -y|--yes)
      AUTO_YES=1
      ;;
    --with-migrations)
      RUN_MIGRATIONS=1
      ;;
    --tasks-from)
      TASKS_SOURCE_OVERRIDE="${2:-}"
      shift
      ;;
    --tasks-mode)
      TASKS_MODE_OVERRIDE="${2:-}"
      shift
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
      if [ -n "$TARGET_INPUT" ]; then
        echo "Error: Multiple target directories provided."
        usage
        exit 1
      fi
      TARGET_INPUT="$1"
      ;;
  esac
  shift
done

if [ -z "$TARGET_INPUT" ]; then
  if [ "$INTERACTIVE" -eq 1 ]; then
    DEFAULT_DIR="$(pwd)"
    echo "No target directory provided."
    echo "Press Enter to use current directory, or type/paste a different path."
    read -e -r -p "Install target [$DEFAULT_DIR]: " TARGET_INPUT
    TARGET_INPUT="${TARGET_INPUT:-$DEFAULT_DIR}"
  else
    TARGET_INPUT="."
  fi
fi

if ! TARGET_DIR="$(cd "$TARGET_INPUT" 2>/dev/null && pwd)"; then
  echo "Error: Target directory does not exist: $TARGET_INPUT"
  exit 1
fi

DOTCORTEX_VERSION="$(detect_dotcortex_version)"
INSTALL_MODE="install"

if [ -d "$TARGET_DIR/.dotcortex" ] || [ -d "$TARGET_DIR/.claude" ]; then
  INSTALL_MODE="upgrade"
fi

if [ "$RUN_MIGRATIONS" -eq 0 ] && { [ -n "$TASKS_SOURCE_OVERRIDE" ] || [ -n "$TASKS_MODE_OVERRIDE" ]; }; then
  echo "Warning: --tasks-from/--tasks-mode were provided but migrations are disabled."
  echo "Use --with-migrations if you want installer-driven legacy task migration."
fi

echo ".cortex installer"
echo "=================="
echo "Source:    $DOTCORTEX_DIR"
echo "Target:    $TARGET_DIR"
echo "Mode:      $INSTALL_MODE"
echo "Version:   $DOTCORTEX_VERSION"
echo ""

mkdir -p "$TARGET_DIR/.dotcortex/backups"
mkdir -p "$TARGET_DIR/.dotcortex/.migrations"

run_migrations

# Ensure canonical/bootstrap paths exist after migration checks.
mkdir -p "$TARGET_DIR/.dotcortex/commands"
mkdir -p "$TARGET_DIR/.claude/commands"

# Copy bootstrap commands to canonical location
cp "$DOTCORTEX_DIR/commands/cortex-init.md" "$TARGET_DIR/.dotcortex/commands/cortex-init.md"
cp "$DOTCORTEX_DIR/commands/cortex-update.md" "$TARGET_DIR/.dotcortex/commands/cortex-update.md"

# Rebuild minimal symlink view for bootstrap commands
rm -f "$TARGET_DIR/.claude/commands/cortex-init.md" "$TARGET_DIR/.claude/commands/cortex-update.md"
ln -s "../../.dotcortex/commands/cortex-init.md" "$TARGET_DIR/.claude/commands/cortex-init.md"
ln -s "../../.dotcortex/commands/cortex-update.md" "$TARGET_DIR/.claude/commands/cortex-update.md"

write_install_metadata

echo "Installed:"
echo "  .dotcortex/commands/cortex-init.md"
echo "  .dotcortex/commands/cortex-update.md"
echo "  .claude/commands/cortex-init.md -> .dotcortex/commands/cortex-init.md"
echo "  .claude/commands/cortex-update.md -> .dotcortex/commands/cortex-update.md"
echo "  .dotcortex/version"
echo "  .dotcortex/install-info.json"
echo ""
echo "Migration state:"
echo "  .dotcortex/.migrations/"
echo "Backups (when created):"
echo "  .dotcortex/backups/"
echo ""
echo "Next steps:"
echo "  1. Open Claude Code in $TARGET_DIR"
echo "  2. Run /cortex-init to scaffold or repair project context"
echo ""
echo "The init command will set up skills, knowledge, memory,"
echo "and optionally task management — all tailored to your stack."
