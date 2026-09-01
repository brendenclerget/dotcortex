---
name: init-team
description: Scaffold a new team in the org repo — context dirs, policy, prefix registration
argument-hint: <team-name>
---

# init-team

Requires an org repo checkout (run `/init-org` first if there isn't one; ask for its path if unknown).

## Steps

1. Interview: team key (kebab-case), ticket prefix (2–6 caps).
2. **Registry check:** read `REGISTRY.md`; if the prefix or team key is taken, stop and say by whom.
3. Policy interview (the same seven `workflow_policy` questions as cortex-init Q15, with the same defaults) → `teams/<key>/policy/workflow_policy.json`.
4. Scaffold `teams/<key>/{skills,commands,knowledge,templates,memory}/` (with `.gitkeep`) and an empty `projects/`.
5. Append the team row to `REGISTRY.md`.
6. Land it as one scoped transaction: `<dotcortex>/bin/task-tx.sh --dir <org-repo> --msg "init-team: <key>" teams/<key> REGISTRY.md`
7. Report + suggest `/init-project <key> <first-project>`.
