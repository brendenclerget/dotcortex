---
name: init-team
description: Scaffold a new team in the org repo — context dirs, policy, prefix registration
argument-hint: <team-name>
---

# init-team

Requires an org repo checkout (run `/init-org` first if there isn't one; ask for its path if unknown).

## Steps

1. Interview: team key (kebab-case), ticket prefix (2–6 caps).
2. Policy interview (the same seven `workflow_policy` questions as cortex-init Q15, with the same defaults) → drafted in memory.
3. **Check-then-mutate under ONE lock** — the registry check is only valid against freshly pulled state, held through the write:

```bash
LOCKDIR="$(git -C <org-repo> rev-parse --absolute-git-dir)/dotcortex-tx.lock"
tries=0; until mkdir "$LOCKDIR" 2>/dev/null; do tries=$((tries+1)); [ $tries -ge 60 ] && exit 1; sleep 1; done
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
git -C <org-repo> pull --rebase --autostash   # (skip if remote-less)
# NOW check REGISTRY.md: prefix or team key taken -> release lock, stop, say by whom
# scaffold teams/<key>/{skills,commands,knowledge,templates,memory,projects}/ each with .gitkeep
# write teams/<key>/policy/workflow_policy.json from the drafted answers
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

5. Report + suggest `/init-project <key> <first-project>`.
