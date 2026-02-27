# How dotcortex Works

## The Context System

Claude Code reads specific files to build context about your project:

1. **`CLAUDE.md`** (project root) — Always loaded. Contains project rules, workflow constraints, and quick-start commands.
2. **`.claude/memory/MEMORY.md`** — Always loaded (first 200 lines). Persistent index of knowledge files, workflow preferences, and cross-cutting patterns.
3. **`.claude/skills/`** — Auto-invoked based on keyword triggers. Framework-specific conventions and best practices.
4. **`.claude/knowledge/`** — Read on demand. Detailed reference for specific domains (API patterns, gotchas, architecture decisions).
5. **`.claude/commands/`** — User-invocable slash commands (`/command-name`).
6. **`.tasks/`** (or configured path) — Optional ticket-based task management.

## File Roles

### CLAUDE.md
The "constitution" of your project context. Every conversation loads this first. Keep it concise — it should contain:
- What the project is
- Critical workflow rules (what Claude should/shouldn't do)
- Stack overview
- Quick start commands

### MEMORY.md
Your persistent memory across sessions. The first 200 lines are always loaded, so keep the most important information at the top. Use it for:
- Repository layout tables
- Workflow preferences
- Knowledge file index (so Claude knows what to read when)
- Hot context (cross-cutting patterns that apply to most work)

### Skills
Self-contained guides for specific domains. Each skill has:
- **Auto-invoke triggers** — Keywords that cause the skill to load automatically
- **Conventions** — Framework best practices
- **Patterns** — How things should be done in this project
- **Gotchas** — Known pitfalls

Skills are generated based on your detected stack during `/cortex-init` and enriched over time.

### Knowledge Files
Detailed reference material organized by domain. Unlike skills (which are prescriptive), knowledge files are descriptive — they document what exists, what was decided, and what to watch out for.

Common knowledge files:
- `architecture-decisions.md` — ADRs with context, decision, and consequences
- `patterns-and-gotchas.md` — Technical surprises with fixes
- `api-patterns.md` — API conventions, error formats, auth patterns
- `frontend-patterns.md` — Component patterns, state management, styling
- `data-model.md` — Schema conventions, query patterns

### Tasks (Optional)
A lightweight, file-based ticket system. Each ticket is a markdown file with status, priority, acceptance criteria, and git references. Features include:
- Automatic ticket numbering with configurable prefix
- Parent/child ticket relationships for feature breakdown
- Archive system (completed tickets are moved, never deleted)
- Backlog management with priority sections
- Knowledge extraction on ticket completion

## The Init Flow

`/cortex-init` runs through 5 phases:

1. **Scan** — Detects languages, frameworks, project structure, existing docs
2. **Interview** — Asks about project purpose, workflow rules, task management preferences
3. **Research** — Generates framework-appropriate skills based on detected stack
4. **Generate** — Creates all files based on scan + interview results
5. **Summary** — Reports what was created and suggests next steps

## Git Tracking Strategy

Each category of files can be independently tracked or ignored:

| Category | Tracked | Use Case |
|----------|---------|----------|
| Tasks | Yes | Team shares ticket state |
| Tasks | No | Personal workflow only |
| Tasks | Separate repo | Independent of feature branches |
| Skills/Knowledge | Yes | All contributors get same context |
| Skills/Knowledge | No | Personal reference only |
| Memory | Yes | Shared index across team |
| Memory | No | Each dev maintains their own |

## Growing Your Context Over Time

The initial scaffolding is just the starting point. Context grows through:

1. **Ticket completion** — When marking tickets done, the PM skill extracts lasting learnings into knowledge files
2. **Manual additions** — Add patterns, gotchas, or decisions directly to knowledge files anytime
3. **Memory updates** — Add hot context patterns to MEMORY.md as you discover cross-cutting rules
4. **Skill refinement** — Update skills with project-specific conventions as they emerge

The system is designed to start sparse and get richer naturally through use.
