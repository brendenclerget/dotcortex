#!/bin/bash
set -euo pipefail

if [ -z "${TARGET_DIR:-}" ]; then
  echo "Migration error: TARGET_DIR is required."
  exit 1
fi

copy_dir_non_destructive() {
  local src="$1"
  local dst="$2"

  mkdir -p "$dst"

  if [ ! -d "$src" ]; then
    return 0
  fi

  # Prefer rsync for clean non-overwrite copy behavior.
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --ignore-existing "$src"/ "$dst"/
    return 0
  fi

  # Fallback for environments without rsync.
  cp -R -n "$src"/. "$dst"/
}

legacy_knowledge="$TARGET_DIR/.claude/knowledge"
legacy_memory="$TARGET_DIR/.claude/memory"
canonical_knowledge="$TARGET_DIR/.dotcortex/knowledge"
canonical_memory="$TARGET_DIR/.dotcortex/memory"

if [ ! -d "$legacy_knowledge" ] && [ ! -d "$legacy_memory" ]; then
  echo "  - no legacy knowledge/memory directories found"
  exit 0
fi

mkdir -p "$TARGET_DIR/.dotcortex"

migrated_any=0

if [ -d "$legacy_knowledge" ]; then
  copy_dir_non_destructive "$legacy_knowledge" "$canonical_knowledge"
  echo "  - migrated knowledge: .claude/knowledge -> .dotcortex/knowledge (non-destructive)"
  migrated_any=1
fi

if [ -d "$legacy_memory" ]; then
  copy_dir_non_destructive "$legacy_memory" "$canonical_memory"
  echo "  - migrated memory: .claude/memory -> .dotcortex/memory (non-destructive)"
  migrated_any=1
fi

if [ "$migrated_any" -eq 0 ]; then
  echo "  - nothing to migrate for project context"
fi
