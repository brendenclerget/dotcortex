---
name: cortex-sync
description: Sync org context (if connected) and rebuild tool views from canonical .dotcortex structure
---

# cortex-sync

Synchronize context state and regenerate tool views from canonical `.dotcortex/`.

## Steps

1. Read `.dotcortex/config.json`. If missing, stop and instruct user to run `/cortex-init`.
2. If `config.org` is connected, pull latest in `.dotcortex/org`:
   - Validate clean or safe-to-pull state.
   - Run `git pull --ff-only` when possible.
3. Rebuild `.claude/` view from canonical sources:
   - `.dotcortex/org/*` (org-global, if connected)
   - `.dotcortex/org/projects/<project_key>/*` (org project overlay, if connected)
   - `.dotcortex/*` (local canonical)
   - Collision order: org-global first, org-project second, local third (local wins).
   - Preserve `.claude/settings.local.json`.
4. Ensure `.tasks -> .dotcortex/tasks`.
5. Rebuild selected tool views from `config.tools`:
   - `.agents/skills/`
   - `.gemini/skills/`
   - `.cursor/rules/*.mdc` (if supported/enabled)
6. Report changes and any conflicts/skipped files.

## Notes

- If symlinks are disabled (`config.symlinks = false`), rebuild copies instead of symlinks and warn the user about potential drift.
- This command never modifies user-authored content outside managed/rebuild directories.

Arguments: $ARGUMENTS
