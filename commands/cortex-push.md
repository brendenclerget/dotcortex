---
name: cortex-push
description: Promote team-layer context (knowledge/skills/commands) into the org base via branch + PR
---

# cortex-push

Promote **team → org**. The org base is the dotcortex repo the org installs from; changes to it are reviewed, so promotion is always branch + PR — never a direct push.

Supported subcommands:
- `/cortex push knowledge <file>`
- `/cortex push skill <name>`
- `/cortex push command <name>`

## Preconditions

1. `.dotcortex/config.json` exists and `config.context_repo` is connected (the thing being promoted lives in the team layer).
2. The asset exists in `.dotcortex/layers/team/`.

If a precondition fails, stop with a clear error.

## Steps

1. Identify the org repo: `source` in config (the org's dotcortex repo). Clone to a temp dir and create a branch `promote/<team_key>/<asset-name>`.
2. Copy the asset from the team layer into the org base at the right profile path (`base/pm/skills/<name>/`, `base/pm/commands/<name>.md`, `base/<profile>/knowledge/<file>.md` — knowledge is a first-class staged category, rendered into installed org layers like commands/skills/templates). **De-brand on the way in**: replace project/team-specific values with the render tokens (`{{TICKET_PREFIX}}`, `{{TASKS_DIR}}`, …) and run `scripts/check-debrand.sh` on the changed paths.
3. Commit on the branch with a message naming the origin team and why it generalizes; push the branch; open a PR (`gh pr create`) with a summary of what the asset does and where it came from.
4. After the PR merges and a release is tagged, teams pick it up via `/cortex-update`. The team may then delete its local copy (the override becomes stale — `/context sync` will flag it) or keep a deliberate divergence with `based_on_org_version` metadata.
5. Report: branch, PR URL, and the post-merge cleanup note.
