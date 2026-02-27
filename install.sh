#!/bin/bash
set -e

# dotcortex installer
# Usage: /path/to/dotcortex/install.sh [target-directory]

DOTCORTEX_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo ".cortex installer"
echo "=================="
echo "Source:  $DOTCORTEX_DIR"
echo "Target:  $TARGET_DIR"
echo ""

# Verify target exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Target directory does not exist: $TARGET_DIR"
  exit 1
fi

# Create .claude/commands/ if needed
mkdir -p "$TARGET_DIR/.claude/commands"

# Copy the two bootstrap commands
cp "$DOTCORTEX_DIR/commands/cortex-init.md" "$TARGET_DIR/.claude/commands/cortex-init.md"
cp "$DOTCORTEX_DIR/commands/cortex-update.md" "$TARGET_DIR/.claude/commands/cortex-update.md"

echo "Installed:"
echo "  .claude/commands/cortex-init.md"
echo "  .claude/commands/cortex-update.md"
echo ""
echo "Next steps:"
echo "  1. Open Claude Code in $TARGET_DIR"
echo "  2. Run /cortex-init to scaffold your project context"
echo ""
echo "The init command will set up skills, knowledge, memory,"
echo "and optionally task management — all tailored to your stack."
