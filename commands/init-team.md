---
name: init-team
description: Scaffold a new team in the org repo — context dirs, policy, prefix registration
argument-hint: <team-name>
---

# init-team

Requires an org repo checkout (run `/init-org` first if there isn't one; ask for its path if unknown).

## Steps

1. Interview: team key (kebab-case), ticket prefix (2–6 caps), and the team lead (email as it appears on claude.ai): the default owner of the team's decision log.
2. Policy interview (the same eight `workflow_policy` questions as cortex-init Q15, with the same defaults, including `crucial_decisions`; recommend `block` for teams) → drafted in memory.
2b. Linear (cortex-init Q16): does this team attach tickets to Linear issues, and which labels should every issue carry? → `policy/linear.json` (`{"enabled": <bool>, "issue_labels": [..]}`), which `/init-project` inherits. Issues only ever carry light tracking content; the ticket stays the agent's context.
3. **Check-then-mutate under ONE lock** — the registry check is only valid against freshly pulled state, held through the write:

```bash
LOCKDIR="$(git -C <org-repo> rev-parse --absolute-git-dir)/dotcortex-tx.lock"
tries=0; until mkdir "$LOCKDIR" 2>/dev/null; do tries=$((tries+1)); [ $tries -ge 60 ] && exit 1; sleep 1; done
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
git -C <org-repo> pull --rebase --autostash   # (skip if remote-less)
# NOW check REGISTRY.md: prefix or team key taken -> release lock, stop, say by whom
# scaffold teams/<key>/{skills,commands,knowledge,templates,memory,projects,debt}/ each with .gitkeep
# write teams/<key>/policy/workflow_policy.json and policy/linear.json from the drafted answers
# write teams/<key>/policy/orchestration.json:
#   {"worktree_root": "../<workspace>-wt", "branch_prefix": "agent/", "max_agents": 4}
# write teams/<key>/decisions/team.yml (the team decision log; see below)
# append the REGISTRY.md row
git -C <org-repo> add teams/<key> REGISTRY.md
git -C <org-repo> commit -m "init-team: <key>" -- teams/<key> REGISTRY.md
if ! git -C <org-repo> push; then
  git -C <org-repo> pull --rebase
  # STOP HERE and RE-CHECK REGISTRY.md before pushing: a clean rebase of two
  # distinct rows can still smuggle in a duplicate prefix or team key.
  # Duplicate found -> identify and revert our rebased "init-team: <key>"
  # commit, push that safe cancellation, release the lock, and report who owns it.
  # Still unique -> push the rebased commit once.
fi
```

4. **Canonical `REGISTRY.md` format** (created by `/init-org`, one row per team):

```markdown
# Team Registry

| team_key | prefix | created    |
|----------|--------|------------|
| payments | PAY    | 2026-09-01 |
```

5. **Team decision log** scaffold (`decisions/team.yml`; per-feature logs are created later, on request, as `decisions/<feature-slug>.yml` with `scope: feature` and `feature: <parent ticket>`). D-numbers are unique across all of the team's logs:

```yaml
schema: 1
log: team
title: "<Team name> decisions"
scope: team
owner: <team lead email>
updated: "<today>"
milestones: []
decisions: []
```

6. **Agent workspace** (when the team will use the `orchestration` pack): `knowledge/agent-workspace.md` is drafted by `/init-project` from the first workspace's repos (the template ships with the pack), since commands and ports are per repo. Each later project adds its repos' sections to the same file.

7. Report + suggest `/init-project <key> <first-project>`. Mention that the team's boards (ticket and decision) are published on the first `/ticket-board` and `/decision-board` run, and their URLs are recorded in `teams/<key>/boards.json`; share them with the team with at least "can interact" access so teammates can answer.
