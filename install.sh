#!/bin/bash
set -e

# localmem installer
# Usage: /path/to/localmem/install.sh [target-directory]

LOCALMEM_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "localmem installer"
echo "=================="
echo "Source:  $LOCALMEM_DIR"
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
cp "$LOCALMEM_DIR/commands/localmem-init.md" "$TARGET_DIR/.claude/commands/localmem-init.md"
cp "$LOCALMEM_DIR/commands/localmem-update.md" "$TARGET_DIR/.claude/commands/localmem-update.md"

echo "Installed:"
echo "  .claude/commands/localmem-init.md"
echo "  .claude/commands/localmem-update.md"
echo ""
echo "Next steps:"
echo "  1. Open Claude Code in $TARGET_DIR"
echo "  2. Run /localmem-init to scaffold your project context"
echo ""
echo "The init command will set up skills, knowledge, memory,"
echo "and optionally task management — all tailored to your stack."
