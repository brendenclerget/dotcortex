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
  <a href="https://github.com/brendenclerget/dotcortex/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://claude.com/claude-code"><img src="https://img.shields.io/badge/built%20for-Claude%20Code-blueviolet" alt="Built for Claude Code"></a>
</p>

---

`.cortex` scans your project, interviews you about your workflow, and scaffolds the full `.claude/` context structure — **skills, knowledge, memory, and task management** — tailored to your detected stack.

One command. Persistent context. Every session starts smarter.

## Quick Start

```bash
# 1. Clone dotcortex
git clone https://github.com/brendenclerget/dotcortex.git ~/dotcortex

# 2. Install into your project
~/dotcortex/install.sh /path/to/your/project

# 3. Open Claude Code in your project and run:
/cortex-init
```

The init command walks you through a short interview, scans your codebase, and generates everything.

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
| `.claude/memory/MEMORY.md` | Repo layout, workflow prefs, knowledge index |
| `.claude/knowledge/architecture-decisions.md` | ADRs — starts empty, fills up as you work |
| `.claude/knowledge/patterns-and-gotchas.md` | Technical footguns and fixes |

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
.tasks/
├── .ticket_counter
├── BACKLOG.md
├── APP-001-auth-flow/
│   ├── APP-001-auth-flow.md          # parent ticket
│   ├── APP-002-login-endpoint.md     # subtask
│   └── APP-003-session-management.md # subtask
├── APP-004-fix-cors.md               # standalone ticket
└── archive/2026-02/                  # completed work
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

### Follow-Up Tasks

Tasks discovered during work get suffixed to the parent: `APP-045a`, `APP-045b`. They don't consume the ticket counter and stay grouped with the work that spawned them.

## Knowledge System

Knowledge files start empty and grow organically:

- **On ticket completion** — the PM skill extracts lasting learnings (gotchas, decisions, patterns)
- **Manual entries** — add patterns directly anytime
- **Cross-session** — everything persists in `.claude/` so the next session picks up where you left off

```
.claude/knowledge/
├── architecture-decisions.md   # ADRs with context + consequences
├── patterns-and-gotchas.md     # Technical surprises with fixes
├── api-patterns.md             # API conventions, error formats
├── frontend-patterns.md        # Component patterns, state mgmt
└── data-model.md               # Schema conventions, query patterns
```

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

If `.claude/` already exists, `/cortex-init` detects it and offers to **augment** rather than overwrite. Existing files are preserved unless you explicitly choose to replace them.

## Project Structure

```
dotcortex/
├── install.sh                    # One-command installer
├── commands/
│   ├── cortex-init.md            # Bootstrap command
│   ├── cortex-update.md          # Update command
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

MIT — see [LICENSE](LICENSE).
