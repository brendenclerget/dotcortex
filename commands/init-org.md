---
name: init-org
description: First-time org setup — create the shared org repo (teams' context + tasks), then first team and first project
---

# init-org

The org repo is ONE git repo your whole org pulls into their code folder. It holds every team's context and every project's tasks:

```
<org-repo>/
├── REGISTRY.md                       # team_key | prefix | created (collision check lives here)
└── teams/<team_key>/
    ├── skills/  commands/  knowledge/  templates/  memory/
    ├── policy/workflow_policy.json
    └── projects/<project_key>/       # that project's task tree (.ticket_counter, BACKLOG.md, TODO.md, archive/)
```

dotcortex (this tool) is installed per-machine and renders the base; the org repo carries everything your org adds on top.

## Steps

1. Ask: create new or clone existing?
   - **New:** ask org name + remote URL (may be added later). `git init` a folder next to the user's projects (e.g. `~/code/<org>-cortex`), write `REGISTRY.md` (the canonical header + empty table from `/init-team`), commit. Add the remote and push if a URL was given. **No remote yet → say plainly the org repo is LOCAL-ONLY** (nothing syncs, teammates can't join) until a remote is added; config `url` fields use the absolute checkout path in the meantime and get updated when the remote lands.
   - **Existing:** `git clone <url>` into the code folder. Done — this IS how a teammate onboards.
2. If the org repo has no teams yet, run `/init-team` now (first team).
3. Then run `/init-project` for the first project.
4. Report: org repo path, remote (or local-only warning), and the teammate onboarding steps: clone the org repo into their code folder, run `install.sh` on their project (bootstrap commands must exist before `/init-project` can), then `/init-project <team> <project>` inside the workspace.

`/init-org` is the FIRST-LEAD orchestration command — it runs `/init-team` and `/init-project` itself for the initial setup. Later teams use `/init-team` directly; additional workspaces use `/init-project` directly.
