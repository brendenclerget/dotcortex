---
name: init-org
description: First-time org setup — create the shared org repo (teams' context + tasks), then first team and first project
---

# init-org

The org repo is ONE git repo your whole org pulls into their code folder. It holds every team's context and every project's tasks:

```
<org-repo>/
├── REGISTRY.md                       # team_key → prefix → owner (collision check lives here)
└── teams/<team_key>/
    ├── skills/  commands/  knowledge/  templates/  memory/
    ├── policy/workflow_policy.json
    └── projects/<project_key>/       # that project's task tree (.ticket_counter, BACKLOG.md, TODO.md, archive/)
```

dotcortex (this tool) is installed per-machine and renders the base; the org repo carries everything your org adds on top.

## Steps

1. Ask: create new or clone existing?
   - **New:** ask org name + remote URL (may be added later). `git init` a folder next to the user's projects (e.g. `~/code/<org>-cortex`), write `REGISTRY.md` (header + empty table), commit. Add the remote and push if a URL was given.
   - **Existing:** `git clone <url>` into the code folder. Done — this IS how a teammate onboards.
2. If the org repo has no teams yet, run `/init-team` now (first team).
3. Then run `/init-project` for the first project.
4. Report: org repo path, remote, and the one-liner teammates run: clone the org repo, then `/init-project <team> <project>` inside their project workspace.
