# localmem

Portable context management for [Claude Code](https://claude.com/claude-code). Scaffolds the full `.claude/` context structure — skills, knowledge, memory, and optional task management — tailored to your detected stack.

## What It Does

`/localmem-init` scans your codebase, interviews you about your workflow, researches your detected stack, and generates:

- **`CLAUDE.md`** — Project rules and guardrails
- **`.claude/memory/MEMORY.md`** — Persistent memory index (always loaded)
- **`.claude/knowledge/`** — Extracted project knowledge files
- **`.claude/skills/`** — Framework-specific domain skills
- **`.tasks/`** — Ticket-based task management (optional, path configurable)

## Installation

1. Clone this repo somewhere on your machine:

```bash
git clone https://github.com/brendenclerget/localmem.git ~/localmem
```

2. Run the install script, pointing it at your project:

```bash
~/localmem/install.sh /path/to/your/project
```

This copies two files into your project's `.claude/commands/`:
- `localmem-init.md` — the bootstrap command
- `localmem-update.md` — the update command

3. Open Claude Code in your project and run:

```
/localmem-init
```

The init command scans your codebase, interviews you about your workflow, and scaffolds everything.

## Updating

When new versions of localmem are released, run `/localmem-update` inside Claude Code. It will:

1. Pull the latest localmem from GitHub to a temp directory
2. Compare each managed file against what's installed
3. Auto-update files you haven't modified
4. Show you conflicts where both upstream and your version changed
5. Let you choose: keep yours, take upstream, or review the diff

Your project-specific files (CLAUDE.md, MEMORY.md, knowledge, domain skills) are never touched by updates — only the commands, PM skills, and templates that came from localmem.

## What Gets Generated

### Always Created

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project overview, workflow rules, quick start commands |
| `.claude/memory/MEMORY.md` | Repo layout, workflow prefs, knowledge index |
| `.claude/knowledge/architecture-decisions.md` | ADRs (starts empty) |
| `.claude/knowledge/patterns-and-gotchas.md` | Technical footguns (starts empty) |

### Stack-Dependent

Additional knowledge and skill files based on detected frameworks:

| Detected Stack | Files Generated |
|---------------|----------------|
| Rails | `skills/rails-backend/SKILL.md`, `knowledge/api-patterns.md` |
| Next.js | `skills/nextjs/SKILL.md`, `knowledge/frontend-patterns.md` |
| React Native + Expo | `skills/react-native/SKILL.md`, `knowledge/frontend-patterns.md` |
| Django / FastAPI | `skills/python-backend/SKILL.md`, `knowledge/api-patterns.md` |
| Go | `skills/go-backend/SKILL.md`, `knowledge/api-patterns.md` |
| Any database ORM | `knowledge/data-model.md` |

### Optional: Task Management

If you opt in, you also get:

- `.tasks/` — Ticket files, backlog, templates, archive (path configurable)
- `.claude/skills/pm-agent/SKILL.md` — PM workflow skill
- `.claude/skills/backlog-cleanup/SKILL.md` — Backlog regeneration and triage
- `.claude/skills/feature-planning/SKILL.md` — PRD-driven planning with specs
- `.claude/skills/thinking-modes/SKILL.md` — Extended thinking budget guidance
- `.claude/commands/pm.md` — Core PM commands (`/pm new`, `/pm done`, etc.)
- `.claude/commands/ticket-new.md` — Create parent ticket with subtask breakdown
- `.claude/commands/ticket-breakdown.md` — Break existing ticket into subtasks
- `.claude/commands/ticket-refine.md` — Review progress and update ticket state from git
- `.claude/commands/next.md` — Get recommendations on what to work on next
- `.claude/commands/backlog.md` — Show current prioritized backlog
- `.claude/commands/standup.md` — Progress summary from git + ticket state
- `.claude/commands/pm-sync.md` — Push/pull task state with remote (if team sync enabled)

## Git Tracking

During setup, you choose independently whether to track each layer in git:

- **Commands** — shared or gitignored
- **Skills** — shared or gitignored
- **Knowledge** — shared or gitignored
- **Memory** — shared or gitignored
- **Tasks** — same repo, gitignored, or separate repo

## Team Sync

If multiple engineers use Claude Code on the same project, tasks can sync automatically. During init you choose:

- **Solo** — no sync, you're the only one
- **Manual** — run `/pm sync` when you want to push/pull
- **Auto on mutation** — pushes after ticket creates/updates, pulls before reads
- **Session bookends** — pulls at session start, pushes at session end

## How Skills Work

Generated skills auto-invoke based on context keywords. For example, a Rails skill triggers when you mention "backend", "API", or "migration". Skills contain:

- Framework conventions and best practices
- Common gotchas specific to the framework
- File structure expectations
- Patterns to follow (and anti-patterns to avoid)

Skills start generic and get enriched with project-specific patterns as you work.

## How Knowledge Works

Knowledge files start mostly empty and accumulate entries as you work. When completing tickets (if PM is enabled), the system extracts lasting learnings — gotchas, decisions, patterns — into the appropriate knowledge file.

You can also manually add entries anytime.

## Non-Destructive

If `.claude/` already exists, `/localmem-init` detects it and offers to augment rather than overwrite. Existing files are preserved unless you explicitly choose to replace them.

## Project Structure

```
localmem/
├── install.sh                    # Install script
├── commands/
│   ├── localmem-init.md          # Bootstrap command
│   ├── localmem-update.md        # Update command
│   ├── pm.md                     # Core PM commands
│   ├── ticket-new.md             # Feature + subtask creation
│   ├── ticket-breakdown.md       # Break ticket into subtasks
│   ├── ticket-refine.md          # Refine ticket from git state
│   ├── next.md                   # What to work on next
│   ├── backlog.md                # Show current backlog
│   ├── standup.md                # Progress recap from git + tickets
│   └── pm-sync.md               # Push/pull task state with remote
├── skills/
│   ├── pm-agent/SKILL.md         # PM workflow skill
│   ├── backlog-cleanup/SKILL.md  # Backlog format spec
│   ├── feature-planning/SKILL.md # PRD-driven planning
│   └── thinking-modes/SKILL.md   # Thinking budget guidance
├── templates/
│   ├── simple-ticket-template.md
│   ├── parent-ticket-template.md
│   └── child-ticket-template.md
├── scaffolds/
│   ├── CLAUDE.md.template        # Reference template
│   └── MEMORY.md.template        # Reference template
└── docs/
    └── how-it-works.md           # Detailed guide
```

## License

MIT
