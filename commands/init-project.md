---
name: init-project
description: Add a project under a team and wire THIS workspace to the org repo (config, render, views, tasks)
argument-hint: <team-key> <project-name>
---

# init-project

Run inside the project workspace. Requires the org repo cloned somewhere in the code folder (ask for its path; offer `/init-org` clone-existing if it's missing) and the team to exist (`/init-team` if not).

## Step 0: Fresh workspace or explicit conversion

If `.dotcortex/config.json` already exists here (a standalone `/cortex-init` workspace), do NOT silently rewrite it. Confirm the conversion with the user, then:
- Preserve `managed_files`, `config.local.json`, existing generated content, and project/user choices that the team does not own (`profiles`, `tools`, `linear`, `git_autonomy`, `symlinks`, `project_name`, and `component_repos`). The conversion changes only the team-owned prefix/policy, repo connection/storage fields, and symlink topology unless the user explicitly asks for another change.
- The team's prefix and policy WIN over the standalone values — say what changes.
- Migrate existing local tasks into the org namespace as one scoped transaction (files move into `teams/<team>/projects/<project>/`; the old `.dotcortex/tasks` dir is then replaced by the symlink).
- If `.dotcortex/layers/team/` exists as a real directory with local content, apply `/context add`'s merge-local-content rule (move aside, offer to carry into the org repo) before creating the symlink.
- Ambiguous collisions (e.g. local tasks AND a populated org namespace for the same project) → stop and ask; never merge by guesswork.

## Steps

1. Read the team's row from `REGISTRY.md` (prefix) and `teams/<team>/policy/workflow_policy.json` (policy — inherited, no interview). Normalize `<project-name>` to a kebab-case `project_key`.
2. Scaffold the task tree if absent: `teams/<team>/projects/<project_key>/` with `.ticket_counter` ("1"), `BACKLOG.md`, `TODO.md`, `archive/.gitkeep` — landed via one `task-tx.sh` transaction against the org repo.
3. If `.dotcortex/` doesn't exist here, run `install.sh` from the dotcortex checkout first.
4. Write `.dotcortex/config.json` — the COMPLETE canonical shape from cortex-init Phase 4.9 (valid JSON, schema-valid, strict-renderable). Fill every field:
   - `prefix`: the team's registered prefix
   - `tasks_dir`: `.dotcortex/tasks`
   - `project_name`: the workspace directory name (or user-supplied)
   - `component_repos`: from a quick scan (nested git repos), else `["<project_name>"]`
   - `profiles`: preserve the existing selection on conversion; on a fresh workspace use `["core", "pm"]` by default and add `review`/packs only if the user opts in when asked (review needs the Q17 values in `config.local.json`)
   - `workflow_policy`: the team's inherited policy, verbatim
   - `linear`: preserve the existing choice on conversion; on a fresh workspace use the team setting if present, else `{ "enabled": false }`
   - `task_repo`: `{url: <org remote URL, or the absolute checkout path if remote-less>, checkout_path: <org checkout path>, branch: <org checkout's current branch>, team_key, project_key}`
   - `context_repo`: same `url`/`checkout_path`/`branch` + `team_key` (one shared checkout is fine — it's the org repo)
   - `task_storage`: `separate_repo`, `task_remote`: true (false if remote-less); preserve `symlinks`, `git_autonomy`, `tools`, and `git_tracking` on conversion, otherwise use `true`, `manual`, ask (default `["claude"]`), and all true respectively
   - `managed_files`: `{}` on a fresh workspace; preserved on conversion (Step 0)
5. Wire the layers and tasks:
   - `.dotcortex/layers/team` → symlink to `<org-repo>/teams/<team>`
   - `.dotcortex/tasks` → symlink to `<org-repo>/teams/<team>/projects/<project_key>`; `.tasks` → `.dotcortex/tasks`
6. Generate the project pieces FIRST. Draft stack skills/knowledge per cortex-init Phase 3/4 in a temporary location and generalize them (no machine paths, secrets, or project-private instructions). Never overwrite an existing team asset by filename: new files and additive knowledge changes may land via a `task-tx.sh` scoped commit; a same-name skill/command/template or a substantive knowledge conflict stops for an explicit merge decision. If nothing is approved, leave the org checkout untouched. CLAUDE.md (marker blocks from the inherited policy) is project-root, not shared.
7. THEN render + resolve, exactly as cortex-init Phase 4.5/4.6: staging from enabled profiles → `.dotcortex/bin/render.sh --strict` into `layers/org` → `.dotcortex/bin/rebuild-views.sh` (the rebuild publishes both the rendered base and the just-committed team-layer content).
8. Report: prefix, where tasks live, remote-less caveat if applicable, and that every mutation syncs through the org repo automatically.

`/cortex-init` remains the full standalone interview (solo installs, no org). In an org, this command is the everyday entry point.
