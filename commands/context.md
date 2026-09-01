---
name: context
description: Manage the team context connection (add, sync, remove) — the team layer of the two-layer org→team topology
---

# context

A team's context is a git repo. Setup happens once; joining is clone + config pointer + rebuild. Nothing more.

Supported subcommands:
- `/context add <repo-url> [--team <team_key>]`
- `/context sync`
- `/context remove`

## /context add <repo-url>

1. Validate `.dotcortex/config.json` exists (else: run `/cortex-init` first).
2. If `.dotcortex/layers/team/` already exists with LOCAL content (init generates project skills/knowledge/memory there), move it aside (`layers/team-local.bak/`), clone `<repo-url>` into `.dotcortex/layers/team/`, then offer to carry the local content INTO the team repo (copy + one scoped commit via task-tx.sh per category) or leave it in the .bak for manual triage — never silently discard it. If the path is empty/absent, just clone.
3. Sanity-check the contract: the checkout should contain some of `commands/`, `skills/`, `knowledge/`, `templates/`, `policy/`, `memory/`. Warn (don't abort) on an empty repo — a brand-new team starts empty.
4. Write `config.context_repo = {url, checkout_path: ".dotcortex/layers/team", branch: <default branch>, team_key}`.
5. If the team's `policy/workflow_policy.json` exists, **inherit it**: overwrite `config.workflow_policy` with the team values (team policy wins; note the change to the user).
6. Add `.dotcortex/layers/team/` to `.gitignore` (it is its own checkout, never committed to the project repo).
7. Rebuild: `.dotcortex/bin/rebuild-views.sh --root <project-root>` — org→team resolution, overrides reported.
8. Re-render CLAUDE.md marker blocks if the inherited policy changed them.

## /context sync

1. Require `config.context_repo`; else report "no team context connected" and stop.
2. Pull: `.dotcortex/bin/task-tx.sh --dir .dotcortex/layers/team --pull-only`
3. **Reload policy:** re-read `.dotcortex/layers/team/policy/workflow_policy.json`; if it differs from `config.workflow_policy`, update config and re-render the CLAUDE.md/AGENTS.md marker blocks (team policy wins; tell the user what changed).
4. Rebuild views (same engine call as above).
5. Report: overrides in effect (the OVERRIDE lines from the rebuild output), stale overrides, and any policy change. **Stale-override mechanism:** for each overriding team file, grep its frontmatter for a `based_on_org_version:` line; if present and older than `install-info.json.dotcortex_version`, flag it stale ("org base moved — refresh or delete the override"). No line → list it as an unversioned deliberate override.

## /context remove

1. Require `config.context_repo`.
2. Confirm with the user; warn if `.dotcortex/layers/team` has uncommitted/unpushed changes (show them; never discard silently).
3. Remove the `context_repo` block from config, delete the `.dotcortex/layers/team/` checkout, rebuild views.
4. Policy note: the project keeps the (formerly inherited) `workflow_policy` values now recorded in config — tell the user they are theirs to edit now.

## Knowledge capture (used by /ticket-close, not invoked directly)

Writing a learning to the team layer is the same transaction tasks use:

```bash
.dotcortex/bin/task-tx.sh --dir .dotcortex/layers/team \
  --msg "knowledge: <topic> (from <TICKET-ID>)" knowledge/<file>.md
```

Then rebuild views so the resolved `.dotcortex/knowledge/` republishes it.
