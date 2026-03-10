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
