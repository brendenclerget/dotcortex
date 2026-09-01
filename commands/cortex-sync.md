---
name: cortex-sync
description: Pull the team context (if connected) and rebuild tool views via the resolution engine
---

# cortex-sync

Synchronize context state and regenerate views. This command is a thin wrapper — the engine does the work.

## Steps

1. Read `.dotcortex/config.json`. If missing, stop and instruct the user to run `/cortex-init`.
2. Collect the configured checkout paths — `config.context_repo.checkout_path` and `config.task_repo.checkout_path` (resolve symlinks; these may be one shared org checkout). Pull each UNIQUE realpath once: `.dotcortex/bin/task-tx.sh --dir <checkout> --pull-only` (the helper takes the checkout's lock, so pulls never race mutations).
3. Rebuild: `.dotcortex/bin/rebuild-views.sh --root <project-root>` — resolves org→team (team wins, overrides reported) and repoints `.claude/*` + `.agents/skills`. Do not re-describe or re-implement resolution here. Then regenerate other tool views per `config.tools` (AGENTS.md / GEMINI.md / `.cursor/rules/*.mdc`) if resolved content changed.
4. Ensure `.tasks -> .dotcortex/tasks`.
5. (Task checkout already pulled in step 2 when configured — never assume a hardcoded path.)
6. Reload team policy if it changed (same as `/context sync` step 3).
7. Report: what was pulled, overrides in effect (OVERRIDE lines from the engine), and stale overrides — evaluated by grepping each overriding team file's frontmatter for `based_on_org_version:` and comparing to `install-info.json.dotcortex_version` (older = stale; absent = unversioned deliberate override).
