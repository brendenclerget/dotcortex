---
name: cortex
description: Top-level dotcortex command namespace for sync and promotion workflows
---

# cortex

Top-level command namespace.

Supported subcommands:
- `/cortex sync`
- `/cortex push knowledge <file>`
- `/cortex push skill <name>`

## sync

Equivalent behavior to `/cortex-sync`:
1. Read `.dotcortex/config.json`.
2. Sync org state if connected.
3. Rebuild tool views from canonical `.dotcortex/`.

## push knowledge <file>

Equivalent behavior to `/cortex-push knowledge <file>`.

## push skill <name>

Equivalent behavior to `/cortex-push skill <name>`.

If subcommand is missing or invalid, show usage with examples.

Arguments: $ARGUMENTS
