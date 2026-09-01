---
name: cortex-sync
description: Pull the team context (if connected) and rebuild tool views via the resolution engine
---

# cortex-sync

Synchronize context state and regenerate views. This command is a thin wrapper — the engine does the work.

## Steps

1. Read `.dotcortex/config.json`. If missing, stop and instruct the user to run `/cortex-init`.
2. If `config.context_repo` is set: `.dotcortex/bin/task-tx.sh --dir .dotcortex/layers/team --pull-only`
3. Rebuild: `.dotcortex/bin/rebuild-views.sh --root <project-root>` — resolves org→team (team wins, overrides reported) and repoints `.claude/*` + `.agents/skills`. Do not re-describe or re-implement resolution here.
4. Ensure `.tasks -> .dotcortex/tasks`.
5. If `config.task_repo` is set, also pull the task checkout: `.dotcortex/bin/task-tx.sh --dir .dotcortex/task-repo --pull-only`
6. Report: what was pulled, overrides in effect, any stale-override warnings.
