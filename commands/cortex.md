---
name: cortex
description: Top-level dotcortex command namespace for sync and promotion workflows
---

# cortex

Top-level command namespace. Each subcommand delegates to its dedicated command file — follow that file exactly.

Supported subcommands:
- `/cortex sync` → `/cortex-sync` (pull team context, rebuild views)
- `/cortex push knowledge <file>` → `/cortex-push`
- `/cortex push skill <name>` → `/cortex-push`
- `/cortex push command <name>` → `/cortex-push`
- `/cortex context add|sync|remove` → `/context`
