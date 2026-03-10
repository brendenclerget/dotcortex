---
name: org
description: Manage org context repo connection (add, sync, remove) for canonical .dotcortex layout
---

# org

Manage org context lifecycle for this project.

Supported subcommands:
- `/org add <repo>`
- `/org sync`
- `/org remove`

## /org add <repo>

1. Validate `.dotcortex/config.json` exists.
2. Clone `<repo>` into `.dotcortex/org` if not already connected.
3. Validate org repo contract:
   - `RULES.md`
   - `knowledge/` (org-global)
   - `skills/` (org-global)
   - `commands/` (org-global)
   - `projects/<project_key>/` (project-scoped overlay)
4. Validate/create project-scoped subtree:
   - `projects/<project_key>/knowledge/`
   - `projects/<project_key>/skills/`
   - `projects/<project_key>/commands/`
   - `projects/<project_key>/tasks/`
5. Set `config.structure_mode = "org_connected"` and write:
   - `config.org.repo`
   - `config.org.project_key`
   - `config.org.push_enabled` (default `true`)
6. Run `/cortex-sync`.

## /org sync

1. Ensure org is connected in config.
2. Pull latest org repo state from `.dotcortex/org`.
3. Run `/cortex-sync`.

## /org remove

1. Ensure org is connected in config.
2. If `.dotcortex/org` has unpushed changes, ask for confirmation before removal/disconnect.
3. Clear org config (`config.org = null`, `config.structure_mode = "single_project"`).
4. Remove or detach `.dotcortex/org` as configured.
5. Run `/cortex-sync` to rebuild views without org layer.

Arguments: $ARGUMENTS
