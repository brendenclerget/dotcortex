---
name: init-project
description: Add a project under a team and wire THIS workspace to the org repo (config, render, views, tasks)
argument-hint: <team-key> <project-name>
---

# init-project

Run inside the project workspace. Requires the org repo cloned somewhere in the code folder (ask for its path; offer `/init-org` clone-existing if it's missing) and the team to exist (`/init-team` if not).

## Steps

1. Read the team's row from `REGISTRY.md` (prefix) and `teams/<team>/policy/workflow_policy.json` (policy — inherited, no interview).
2. Scaffold the task tree if absent: `teams/<team>/projects/<project>/` with `.ticket_counter` ("1"), `BACKLOG.md`, `TODO.md`, `archive/.gitkeep` — landed via one `task-tx.sh` transaction against the org repo.
3. If `.dotcortex/` doesn't exist here, run `install.sh` from the dotcortex checkout first.
4. Write `.dotcortex/config.json`: team's prefix, inherited policy, and both repo blocks pointing at the org repo — `task_repo: {url, checkout_path: <org-repo path>, team_key, project_key}`, `context_repo: {url, checkout_path: <org-repo path>, team_key}`. (One shared checkout is fine — it's the org repo.)
5. Wire the layers and tasks:
   - `.dotcortex/layers/team` → symlink to `<org-repo>/teams/<team>`
   - `.dotcortex/tasks` → symlink to `<org-repo>/teams/<team>/projects/<project>`; `.tasks` → `.dotcortex/tasks`
6. Render + resolve, exactly as cortex-init Phase 4.5/4.6: staging from enabled profiles → `.dotcortex/bin/render.sh --strict` into `layers/org` → `.dotcortex/bin/rebuild-views.sh`.
7. Generate the project pieces (CLAUDE.md with marker blocks from the inherited policy; stack skills into the team layer per cortex-init Phase 3/4).
8. Report: prefix, where tasks live, and that every mutation syncs through the org repo automatically.

`/cortex-init` remains the full standalone interview (solo installs, no org). In an org, this command is the everyday entry point.
