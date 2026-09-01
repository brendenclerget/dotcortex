# README Review Packet (for Codex)

Post-v1.5.0 audit of `README.md`. The repo just shipped a full rebuild (see `TASK-team-readiness.md` for contracts); the README still describes the pre-rebuild system. This doc contains: (A) audit findings, (B) the current README verbatim, (C) the proposed replacement. Review request: check (C) against the actual repo state and the frozen contracts — flag anything the proposed text claims that the code/commands don't deliver, anything stale it still carries, and anything shipped that it fails to mention.

---

## A. Audit findings (current README vs shipped v1.5.0)

| # | Section | Problem | Severity |
|---|---|---|---|
| 1 | Task Management diagram | Shows **numbered subtasks** (`APP-002-login-endpoint.md` under `APP-001/`) — directly contradicts the shipped letter-children rule (`APP-001a`, `APP-001b`; children never consume counter numbers) | HIGH — teaches users the exact anti-pattern the rebuild fixed |
| 2 | Team Sync | Documents **four sync modes** (solo/manual/auto/bookends). Shipped reality: ONE contract — every mutation is an immediate scoped commit+push; bookends were removed as unsafe | HIGH — describes removed behavior |
| 3 | Org Hierarchy | Describes the **deleted** three-scope model (`.dotcortex/org/`, org-project overlays, local-wins precedence). Shipped: two layers, org→team, **team wins**, projects own no context | HIGH — wrong architecture |
| 4 | PM Commands table | `/ticket-implement` renamed `/implement`; `/org *` replaced by `/context`; `/cortex push` is now **team→org**; missing entirely: `/ticket-close`, `/todo`, `/fix`, `/implement-review`, `/commit`, `/design-implement` | HIGH — wrong + incomplete command surface |
| 5 | Project Structure | Missing `bin/` (render/rebuild/task-tx engines), `base/` (profiles: core/pm/review/packs), `schemas/`, `tests/`, `sources/`; still lists deleted `org.md` and top-level `skills/`/`templates/` (moved into `base/`) | MED — wrong repo map |
| 6 | Task Management | No mention of the **namespaced shared task repo** (`teams/<team>/projects/<project>/`) — the headline team feature — nor `scripts/migrate-task-repo.sh`; ticket templates shown in tasks dir but now resolve at `.dotcortex/templates/` | MED |
| 7 | Missing sections | Nothing on: install profiles, **workflow policy** (rendered CLAUDE.md marker blocks), **Linear mode**, **cross-model review profile** (reviewer tiers), layer resolution (`layers/org` → `layers/team`), release-tag versioning | MED — the new value props are invisible |
| 8 | How It Works | Generation step doesn't mention the deterministic render pipeline (staging → `render.sh --strict` → manifest → `rebuild-views.sh`) — determinism is a core selling point for teams | MED |
| 9 | Updating | True but undersells: updates now check out the exact release tag and do a real three-way merge against the recorded `base_version` | LOW |
| 10 | Follow-Up Tasks | Letter suffixes are now the rule for ALL subtasks, not just mid-work follow-ups | LOW |
| 11 | Stack-Detected Skills table | Still accurate in spirit (Phase 3 generation unchanged) — keep | OK |
| 12 | Quick Start / install | Accurate; could note the installer also ships the engine (`.dotcortex/bin/`) + schema into the project | LOW |

## B. Current README (verbatim)

````markdown
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-light.svg">
    <img alt=".cortex" src="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-light.svg" width="280">
  </picture>
</p>

<p align="center">
  <strong>Give Claude Code a brain for your codebase.</strong>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> ·
  <a href="#what-gets-generated">What Gets Generated</a> ·
  <a href="#task-management">Task Management</a> ·
  <a href="#team-sync">Team Sync</a> ·
  <a href="ROADMAP.md">Roadmap</a>
</p>

<p align="center">
  <a href="https://github.com/brendenclerget/dotcortex/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-blue.svg" alt="MIT License"></a>
  <a href="https://claude.com/claude-code"><img src="https://img.shields.io/badge/built%20for-Claude%20Code-blueviolet" alt="Built for Claude Code"></a>
</p>

---

`.cortex` scans your project, interviews you about your workflow, and scaffolds the full `.dotcortex/` canonical context structure (with `.claude/` as a generated tool view) — **skills, knowledge, memory, and task management** — tailored to your detected stack.

One command. Persistent context. Every session starts smarter.

## Quick Start

```bash
# 1. Clone dotcortex
git clone https://github.com/brendenclerget/dotcortex.git ~/dotcortex

# 2. Install into your project
~/dotcortex/install.sh /path/to/your/project
#    or interactive prompt (no path typing):
~/dotcortex/install.sh
#    or non-interactive defaults:
~/dotcortex/install.sh --yes /path/to/your/project

# 3. Open Claude Code in your project and run:
/cortex-init
```

The init command walks you through a short interview, scans your codebase, and generates everything.

If you run `install.sh` again in an existing repo, it runs in upgrade mode:
- records installer version metadata in `.dotcortex/version` and `.dotcortex/install-info.json`
- preserves existing context by default (migrations are opt-in)

If you need legacy migration during install upgrade:
```bash
~/dotcortex/install.sh --with-migrations --tasks-from .tasks --tasks-mode move /path/to/project
```

Manual task migration (run anytime, independent of installer migration markers):
```bash
~/dotcortex/scripts/migrate-tasks.sh --from /path/to/old/tasks --mode move /path/to/project
```

## How It Works

```
┌─────────────────────────────────────────────────────┐
│  /cortex-init                                       │
│                                                     │
│  1. Scan     Detect languages, frameworks, ORM,     │
│              project structure, existing docs       │
│                                                     │
│  2. Interview  Ask about workflow, guardrails,      │
│                task management preferences          │
│                                                     │
│  3. Research   Generate framework-specific skills   │
│                based on your actual stack            │
│                                                     │
│  4. Generate   Write CLAUDE.md, memory, knowledge,  │
│                skills, and optional PM system        │
│                                                     │
│  5. Summary    Report what was created              │
└─────────────────────────────────────────────────────┘
```

## What Gets Generated

### Always Created

| File | Purpose |
|:-----|:--------|
| `CLAUDE.md` | Project overview, workflow rules, quick start commands |
| `.dotcortex/memory/MEMORY.md` | Repo layout, workflow prefs, knowledge index |
| `.dotcortex/knowledge/architecture-decisions.md` | ADRs — starts empty, fills up as you work |
| `.dotcortex/knowledge/patterns-and-gotchas.md` | Technical footguns and fixes |

### Stack-Detected Skills

`.cortex` detects your stack and generates domain skills with real best practices — not boilerplate.

| Detected | Generated Skill | Knowledge |
|:---------|:----------------|:----------|
| Rails | `rails-backend` | `api-patterns.md` |
| Next.js | `nextjs` | `frontend-patterns.md` |
| React Native / Expo | `react-native` | `frontend-patterns.md` |
| Django / FastAPI | `python-backend` | `api-patterns.md` |
| Go (gin, chi, echo) | `go-backend` | `api-patterns.md` |
| Any ORM | — | `data-model.md` |

Skills auto-invoke based on context keywords. Mention "backend" or "migration" and the Rails skill loads automatically. They start generic and get enriched with project-specific patterns as you work.

## Task Management

> *Optional — you choose during init.*

A lightweight, file-based ticket system that lives in your repo. No external tools, no context switching.

```
.dotcortex/tasks/
├── .ticket_counter
├── BACKLOG.md
├── APP-001-auth-flow/
│   ├── APP-001-auth-flow.md          # parent ticket
│   ├── APP-002-login-endpoint.md     # subtask
│   └── APP-003-session-management.md # subtask
├── APP-004-fix-cors.md               # standalone ticket
└── archive/2026-02/                  # completed work

.tasks -> .dotcortex/tasks/           # compatibility symlink
```

### PM Commands

| Command | What It Does |
|:--------|:-------------|
| `/pm new <desc>` | Create a ticket |
| `/pm done <id>` | Mark complete and archive |
| `/pm status` | Show all tickets by status |
| `/ticket-new` | Create parent ticket with subtask breakdown |
| `/ticket-breakdown <id>` | Break existing ticket into subtasks |
| `/ticket-refine <id>` | Update ticket state from git history |
| `/ticket-status <id> <status> [owner]` | Set status + assignee, sync backlog, commit |
| `/ticket-implement <id>` | Validate readiness, mark IN_PROGRESS, then implement |
| `/ticket-audit <id>` | Generate a paste-ready audit prompt for an external reviewer |
| `/next` | Get a recommendation on what to work on |
| `/backlog` | Show prioritized backlog |
| `/standup` | Progress summary from git + ticket state |
| `/cortex-sync` | Rebuild tool views from `.dotcortex/` and sync org layer if connected |
| `/org add <repo>` | Connect project to org context repo |
| `/org sync` | Pull latest org context and rebuild views |
| `/org remove` | Disconnect org repo and rebuild local-only views |
| `/cortex push knowledge <file>` | Promote local knowledge to org project scope via branch + PR |
| `/cortex push skill <name>` | Promote local skill to org project scope via branch + PR |

### Follow-Up Tasks

Tasks discovered during work get suffixed to the parent: `APP-045a`, `APP-045b`. They don't consume the ticket counter and stay grouped with the work that spawned them.

## Multi-Tool

Claude Code is the primary target, but the same canonical `.dotcortex/` drives generated views for **OpenAI Codex CLI** (`AGENTS.md`, `.agents/skills/`), **Gemini CLI** (`GEMINI.md`, `.gemini/skills/`), and **Cursor** (`.cursor/rules/*.mdc`) — pick your tools during init and every agent reads the same brain.

## Knowledge System

Knowledge files start empty and grow organically:

- **On ticket completion** — the PM skill extracts lasting learnings (gotchas, decisions, patterns)
- **Manual entries** — add patterns directly anytime
- **Cross-session** — everything persists in `.dotcortex/` so the next session picks up where you left off

```
.dotcortex/knowledge/
├── architecture-decisions.md   # ADRs with context + consequences
├── patterns-and-gotchas.md     # Technical surprises with fixes
├── api-patterns.md             # API conventions, error formats
├── frontend-patterns.md        # Component patterns, state mgmt
└── data-model.md               # Schema conventions, query patterns
```

## Org Hierarchy

When org mode is enabled, context is layered in two scopes:

- Org-global: `.dotcortex/org/{commands,skills,knowledge,RULES.md}` (applies everywhere)
- Org-project: `.dotcortex/org/projects/<project_key>/{commands,skills,knowledge,tasks}` (per-project overlay)

Tool views are rebuilt with precedence:
1. Org-global
2. Org-project
3. Local canonical `.dotcortex/*` (local wins)

## Git Tracking

During setup, you choose independently whether to track each layer:

| Layer | Tracked | Use Case |
|:------|:--------|:---------|
| Commands | ✓ / ✗ | Share slash commands with team or keep personal |
| Skills | ✓ / ✗ | Share context or keep personal |
| Knowledge | ✓ / ✗ | Team knowledge base or personal notes |
| Memory | ✓ / ✗ | Shared index or per-developer |
| Tasks | repo / ignore / separate | Flexible task storage |

## Team Sync

Multiple engineers using Claude Code on the same project? Tasks can sync:

| Mode | Behavior |
|:-----|:---------|
| **Solo** | No sync — you're the only one |
| **Manual** | Run `/pm sync` when you want to push/pull |
| **Auto on mutation** | Pushes after creates/updates, pulls before reads |
| **Session bookends** | Pulls at session start, pushes at session end |

## Updating

```bash
# Inside Claude Code:
/cortex-update
```

Pulls the latest dotcortex, auto-updates files you haven't modified, and walks you through conflicts where both upstream and your version changed. Your project-specific files are never touched.

## Non-Destructive

If existing context already exists (`.dotcortex/` or legacy `.claude/`), `/cortex-init` detects it and offers to **augment** rather than overwrite. Existing files are preserved unless you explicitly choose to replace them.

## Project Structure

```
dotcortex/
├── install.sh                    # One-command installer
├── commands/
│   ├── cortex-init.md            # Bootstrap command
│   ├── cortex-update.md          # Update command
│   ├── cortex.md                 # Top-level namespace command
│   ├── cortex-sync.md            # Rebuild/sync command
│   ├── org.md                    # Org lifecycle commands
│   ├── cortex-push.md            # Project -> org promotion commands
│   ├── pm.md                     # Core PM commands
│   ├── ticket-new.md             # Feature planning
│   ├── ticket-breakdown.md       # Subtask creation
│   ├── ticket-refine.md          # Git-aware refinement
│   ├── ticket-status.md          # Status + assignee transitions
│   ├── ticket-implement.md       # Pick up + implement workflow
│   ├── ticket-audit.md           # Generate external-reviewer prompt
│   ├── next.md                   # Work recommendations
│   ├── backlog.md                # Backlog view
│   ├── standup.md                # Progress recap
│   └── pm-sync.md                # Team sync
├── skills/                       # Installable skills
├── templates/                    # Ticket templates
├── scaffolds/                    # Reference scaffolds
└── docs/                         # Documentation
```

## License

MIT + Commons Clause — free to use, fork, and modify. Cannot be sold or repackaged as a paid product. See [LICENSE](LICENSE).
````

## C. Proposed replacement README

````markdown
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-light.svg">
    <img alt=".cortex" src="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-light.svg" width="280">
  </picture>
</p>

<p align="center">
  <strong>Give Claude Code a brain for your codebase — and your whole team the same one.</strong>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> ·
  <a href="#what-gets-installed">What Gets Installed</a> ·
  <a href="#task-management">Task Management</a> ·
  <a href="#teams">Teams</a> ·
  <a href="ROADMAP.md">Roadmap</a>
</p>

<p align="center">
  <a href="https://github.com/brendenclerget/dotcortex/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-blue.svg" alt="MIT License"></a>
  <a href="https://claude.com/claude-code"><img src="https://img.shields.io/badge/built%20for-Claude%20Code-blueviolet" alt="Built for Claude Code"></a>
</p>

---

`.cortex` scans your project, interviews you about your workflow, and installs a complete `.dotcortex/` context system — **skills, commands, knowledge, memory, and task management** — tailored to your stack. The base install is **deterministic**: same release tag + same config produce byte-identical output, rendered through a real pipeline with a hash manifest — not improvised per machine. (Per-machine bits — your reviewer CLI paths — live in a gitignored overlay and are the one deliberate exception.)

One command. Persistent context. Every session — and every teammate — starts smarter.

## Quick Start

```bash
# 1. Clone dotcortex
git clone https://github.com/brendenclerget/dotcortex.git ~/dotcortex

# 2. Install into your project (ships the render engine + bootstrap commands)
~/dotcortex/install.sh /path/to/your/project
#    non-interactive: ~/dotcortex/install.sh --yes /path/to/your/project

# 3. Open Claude Code in your project and run:
/cortex-init
```

The init interview configures your ticket prefix, task storage, workflow policy, and optional integrations, then renders the base through the deterministic pipeline and generates the project-specific pieces (CLAUDE.md, stack skills, knowledge scaffolds).

Re-running `install.sh` on an existing project refreshes the engine, schema, and bootstrap commands only — rendered content updates via `/cortex-update` (which checks out the exact latest release tag and does a true three-way merge against what you originally installed, so your local edits survive).

## How It Works

```
┌──────────────────────────────────────────────────────────┐
│  /cortex-init                                            │
│                                                          │
│  1. Scan       Detect languages, frameworks, ORM,        │
│                structure, existing docs and tasks        │
│                                                          │
│  2. Interview  Workflow policy, task storage, team       │
│                context, Linear, cross-model review       │
│                                                          │
│  3. Research   Generate stack-specific skills from       │
│                your actual frameworks                    │
│                                                          │
│  4. Render     Deterministic pipeline: selected          │
│                profiles → token render (--strict) →      │
│                manifest → resolved views                 │
│                                                          │
│  5. Generate   CLAUDE.md (marker blocks) + project       │
│                skills/knowledge/memory into YOUR layer,  │
│                published by the view rebuild             │
└──────────────────────────────────────────────────────────┘
```

Two kinds of content, deliberately separate:
- **Rendered base** (identical for identical inputs — same release tag, profiles, and config): PM commands, review workflow, templates — from `base/` profiles, tracked in a manifest with hashes and the release tag they came from.
- **Generated context** (unique to your project): stack skills, knowledge, and memory are written fresh from the scan + interview into your team/local layer (`.dotcortex/layers/team/`) and published to the resolved views by the rebuild; `CLAUDE.md` lives at the project root with its rules blocks rendered from config inside managed markers. None of it is touched by updates.

## What Gets Installed

### Install profiles

| Profile | Contents | Default |
|:--------|:---------|:--------|
| `core` | Instruction scaffolds (marker-block CLAUDE.md template), `/commit` | always |
| `pm` | Full ticket system: pm-agent skill, 13 commands, TODO queue, templates, backlog validation | on |
| `review` | `/fix` + `/implement-review` — cross-model review workflow | opt-in (interview; needs a second model family's CLI) |
| `testing` | Maestro mobile UI automation skill | opt-in (interview) |
| `design` | `/design-implement` — code-first design parity from in-repo design artifacts | opt-in (interview) |
| `launch-planning` | MVP scoping + execution lanes | **future — shipped disabled** |

### Stack-detected skills (generated, not templated)

| Detected | Generated Skill |
|:---------|:----------------|
| Rails | `rails-backend` |
| Next.js | `nextjs` |
| React Native / Expo | `react-native` |
| Django / FastAPI | `python-backend` |
| Go (gin, chi, echo) | `go-backend` |

Skills auto-invoke on context keywords; project-specific learnings accrue alongside them through `/ticket-close` knowledge extraction and team-layer promotion.

### Workflow policy

Who runs tests? Who starts servers? Who may create tickets? These are **config, not folklore**: `config.workflow_policy` holds resolved values (e.g. `test_execution: user_only`, `ticket_creation: followups_only`), and the CLAUDE.md rules block is rendered from it inside managed markers — edit the config, never the block. Teams inherit policy from their team context; agents across every session behave the same way.

## Task Management

> *Optional — you choose during init.*

File-based tickets in git. No external tools required — and **Linear-aware** when you want it: with Linear mode enabled, commands create/update linked issues through the Linear MCP when it's connected; when it isn't, they pause and ask you to connect (continuing markdown-only needs your explicit say-so). With Linear off, everything is pure markdown.

```
.dotcortex/tasks/
├── .ticket_counter
├── BACKLOG.md
├── TODO.md                            # ordered next-work queue (/todo)
├── APP-041-auth-flow/
│   ├── APP-041-auth-flow.md           # parent ticket
│   ├── APP-041a-login-endpoint.md     # letter child — consumes no number
│   └── APP-041b-session-management.md # letter child
├── APP-042-fix-cors.md                # standalone ticket
└── archive/2026-09/                   # completed work (moved, never deleted)

.tasks -> .dotcortex/tasks/            # compatibility symlink
```

**Subtasks are letter children** (`APP-041a/b/c`): they never consume counter numbers and stay grouped with the work that spawned them. Top-level IDs are allocated under a transaction lock with push-rejection retry (or taken from the Linear issue) — same-machine sessions serialize on the lock, and cross-machine collisions resolve by re-pull + re-allocate.

### Commands

| Command | What It Does |
|:--------|:-------------|
| `/pm new <desc>` | Create a simple ticket (the everyday entry point for < 4h work) |
| `/pm-sync` | Manual task-repo sync (pull + scoped push) |
| `/ticket-new` | Feature workflow: parent ticket + breakdown for medium/large work (redirects < 4h to `/pm new`) — transactional ID allocation, Linear-first when connected |
| `/implement <id>` | Pick up a ticket: status gate, claim it, reconcile the plan against the current tree, build, honest acceptance-criteria report |
| `/ticket-breakdown <id>` | Break a ticket into letter children |
| `/ticket-refine <id>` | Refine scope; remaining work becomes letter children |
| `/ticket-status <id> <status>` | Status + assignee transition, board sync, scoped commit, Linear mirror |
| `/ticket-close <id>` | Close: verify, archive (move, never delete), update every board, extract knowledge to the team layer, Linear last |
| `/ticket-audit <id>` | Deep per-ticket audit via external-reviewer prompt |
| `/todo` | The canonical ordered next-work queue (lanes, gates, parallel-session collision rules) |
| `/next` · `/backlog` · `/standup` · `/pm` | Recommendations, boards, progress, PM index |
| `/fix` | Paste another agent's review findings — each is **verified against the tree** (CONFIRMED/STALE/REJECTED) before anything is fixed |
| `/implement-review <id>` | Implement, then one-shot **cross-model review** (your work reviewed by the other model family — never by itself; reported SKIPPED if no second family is configured) |
| `/commit` | Multi-repo-aware commit workflow |
| `/context add|sync|remove` | Connect this project to your team's context repo |
| `/cortex-sync` | Pull team context + rebuild views |
| `/cortex push skill|command|knowledge <name>` | Promote a team asset into the org base via branch + PR |
| `/cortex-update` | Update the rendered base from the latest release tag (three-way merge) |

## Teams

Two layers, one baseline:

```
org base   (this repo, installed from a release tag)   ──┐
                                                         ├── resolved views: .dotcortex/{commands,skills,knowledge,templates}
team layer (your team's context repo, cloned locally)  ──┘        team wins on collision — every override is reported
```

- **Org base** — the curated foundation every team installs. Teams branch from it, so behavior is uniform org-wide.
- **Team layer** — your team's repo of skills/knowledge/policy. Join a team: `/context add <repo-url>` (clone + config pointer + rebuild — that's the whole setup). Knowledge **rolls up**: `/ticket-close` extracts learnings into the team layer, so the next engineer inherits them without excavating old projects.
- **Promotion** — `/cortex push` opens a PR to move a proven team asset into the org base.

### Shared task repo

Teams share one namespaced task repo:

```
task-repo/teams/<team>/projects/<project>/   ← your project's tickets
.dotcortex/tasks -> task-repo/teams/<team>/projects/<project>
```

Every task mutation is an **immediate scoped transaction** — pull, stage exactly the touched files (never `git add -A`), commit, push, retry on rejection. No sync modes, no session bookends, no stepping on a teammate's dirty files. Migrating an existing flat task repo is one history-preserving command: `scripts/migrate-task-repo.sh`.

## Multi-Tool

Claude Code is the primary target, but the same canonical `.dotcortex/` drives generated views for **OpenAI Codex CLI** (`AGENTS.md`, `.agents/skills/`), **Gemini CLI** (`GEMINI.md`, `.gemini/skills/`), and **Cursor** (`.cursor/rules/*.mdc`) — pick your tools during init and every agent reads the same brain.

## Knowledge System

Knowledge grows as you work: `/ticket-close` extracts gotchas, decisions, and patterns (with date + code evidence) into the team layer; manual entries are welcome anytime; everything persists across sessions. Facts commit directly; "always do X" rules are not written as knowledge — they become skill/policy change proposals instead.

## Updating

```bash
/cortex-update
```

Checks out the **exact latest release tag**, renders it with your config, and three-way merges against the version you originally installed (recorded per-file in the manifest). Unmodified files auto-update; your edits merge cleanly or get a clear conflict prompt. Generated project content is never touched.

## Non-Destructive, Everywhere

- `/cortex-init` defaults to augmenting existing context; it overwrites only if you explicitly choose Replace.
- The view rebuilder refuses to delete anything it didn't generate — user files in generated directories abort the rebuild with a pointer, they don't vanish.
- Renders are atomic: a strict render that can't resolve every token writes **nothing**.
- Archive = move, never delete.

## Project Structure

```
dotcortex/
├── install.sh                # Installer: bootstrap commands + engine + schema into your project
├── bin/
│   ├── render.sh             # Deterministic token renderer + managed-files manifest
│   ├── rebuild-views.sh      # org→team layer resolution + tool views (.claude, .agents)
│   └── task-tx.sh            # The one git transaction (pull → scoped add → commit → push)
├── base/                     # The shipped base, by install profile
│   ├── profiles.json
│   ├── core/  pm/  review/   # commands, skills, templates per profile
│   └── packs/                # testing, design (opt-in); launch-planning (future, disabled)
├── commands/                 # Bootstrap + lifecycle: cortex-init/update/sync/push, /context
├── schemas/config.schema.json
├── scripts/                  # migrate-task-repo.sh, check-debrand.sh, migrate-tasks.sh
├── sources/                  # Sanitized donor-install extractions (reconciliation inputs)
├── tests/run-tests.sh        # 96 assertions: render, views, installer, transactions, migration
└── docs/reconciliation-matrix.md
```

## License

MIT + Commons Clause — free to use, fork, and modify. Cannot be sold or repackaged as a paid product. See [LICENSE](LICENSE).
````
