---
name: cortex-push
description: Promote local knowledge/skills from canonical .dotcortex into org project scope via branch + PR
---

# cortex-push

Promote project-level context to org-level context.

Supported subcommands:
- `/cortex push knowledge <file>`
- `/cortex push skill <name>`

## Preconditions

1. `.dotcortex/config.json` exists.
2. `config.org` is connected.
3. `config.org.push_enabled` is true.

If any precondition fails, stop with a clear error.

## /cortex push knowledge <file>

1. Resolve source file under `.dotcortex/knowledge/`.
2. Copy into `.dotcortex/org/projects/<project_key>/knowledge/` (preserve relative structure if needed).
3. If destination exists, apply configured conflict policy (prompt / overwrite / fail).
4. Create branch: `promote/knowledge/<slug>`.
5. Commit and push.
6. Open PR with generated title/body; if `gh` auth is unavailable, print manual PR commands.
7. Report branch and PR URL (or manual fallback steps).

## /cortex push skill <name>

1. Resolve source skill dir under `.dotcortex/skills/<name>/`.
2. Copy into `.dotcortex/org/projects/<project_key>/skills/<name>/`.
3. Apply destination conflict policy.
4. Create branch: `promote/skill/<slug>`.
5. Commit and push.
6. Open PR or provide manual fallback.
7. Report output details.

Arguments: $ARGUMENTS
