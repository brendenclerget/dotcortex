---
name: cortex-init
description: Bootstrap Claude Code context management for any project. Scans codebase, interviews user, generates skills/knowledge/memory.
---

# cortex-init: Context Bootstrap

You are initializing Claude Code's context management system for this project. Follow these phases exactly.

## v1.5 Canonical Rules

Apply these rules throughout all phases (they override older path conventions):

1. `.dotcortex/` is the canonical location for generated context.
2. `.claude/` is a tool view populated from `.dotcortex/` (symlink/copy view depending on environment).
3. `.dotcortex/tasks/` is canonical for tasks.
4. `.tasks/` is always a compatibility view pointing to `.dotcortex/tasks/`.
5. Team/org usage is selectable in interview mode, but canonical paths do not change.

## Phase 0: Resume Check

**Before doing anything else, check for a previous incomplete init.**

Look for `.dotcortex/.init-state.json` in the project root. If it exists, this is a resumed session.

```json
{
  "phase": "interview",
  "scan_results": { ... },
  "answers": {
    "Q1": "A trading card inventory management app",
    "Q2": ["claude", "codex"],
    "Q3": ["ruby", "rails", "react-native", "expo"],
    "Q4": ["no-servers", "no-docs"]
  },
  "last_completed_question": "Q4",
  "generated_files": []
}
```

**If state file exists:**
1. Read it and ask:
   ```
   Found an incomplete dotcortex init (completed through Q4).

     1. Resume where you left off (Recommended)
     2. Start over from scratch
   ```
2. If resume: skip Phase 1 (use saved `scan_results`), skip answered questions, resume at `last_completed_question + 1`
3. If start over: delete the state file and proceed from Phase 1 fresh

**If state file does not exist:**
1. Fresh init — proceed normally from Phase 1

**State file rules:**
- Create `.dotcortex/.init-state.json` at the START of Phase 2 (after scan completes)
- Update it after EVERY question is answered (write the answer + increment `last_completed_question`)
- Update it after each file is generated in Phase 4 (track `generated_files`)
- Delete it at the END of Phase 5 (successful completion)
- If init completes successfully, the state file is gone — re-running `/cortex-init` starts fresh

**Partial Phase 4 recovery:** If the state file has `generated_files` populated, some files were already written. Skip those during generation. This handles the case where init crashed mid-file-generation.

## Phase 1: Codebase Scan

Scan the project automatically (no user input needed yet). Detect:

**Languages & Package Managers:**
- `package.json` → Node.js (check for bun/pnpm/yarn lockfiles)
- `Gemfile` → Ruby
- `Cargo.toml` → Rust
- `go.mod` → Go
- `pyproject.toml` / `requirements.txt` / `Pipfile` → Python
- `pom.xml` / `build.gradle` → Java/Kotlin
- `*.csproj` / `*.sln` → .NET
- `composer.json` → PHP
- `mix.exs` → Elixir
- `pubspec.yaml` → Dart/Flutter

**Frameworks** (parse detected config files):
- `package.json` dependencies → react, next, expo, vue, angular, svelte, express, fastify, nestjs, nuxt, remix, astro, etc.
- `Gemfile` → rails, sinatra, hanami
- `pyproject.toml` / `requirements.txt` → django, flask, fastapi, celery
- `go.mod` → gin, chi, echo, fiber
- `Cargo.toml` → actix, axum, rocket
- `composer.json` → laravel, symfony
- `mix.exs` → phoenix

**Database/ORM:**
- Prisma (`prisma/schema.prisma`)
- ActiveRecord (Rails `db/schema.rb`)
- SQLAlchemy, Django ORM
- TypeORM, Drizzle, Sequelize
- `docker-compose.yml` for postgres/mysql/redis/mongo

**Structure:**
- Monorepo detection: multiple `package.json`, workspaces field, nx.json, turbo.json, pnpm-workspace.yaml
- Directory layout: src/, app/, lib/, components/, pages/, routes/, api/, etc.

**Existing Context:**
- README.md content
- CONTRIBUTING.md
- docs/ folder
- Any existing CLAUDE.md
- Any existing `.dotcortex/` directory
- Any existing `.claude/` directory

**Existing Task Files:**
- Check common task locations: `.tasks/`, `tasks/`, `claude_tasks/`, `.claude/tasks/`
- Look for ticket-like files: `*-[0-9]*.md`, `*.ticket.md`, any markdown with `Status:` and `Priority:` headers
- Check for `.ticket_counter` files
- Check for `BACKLOG.md` or `TODO.md`
- Report what was found — these will be offered for migration into `.dotcortex/tasks/`

**Git Info:**
- Remote URL (`git remote -v`)
- Default branch
- Recent commit message style (last 10 commits)

**Present scan results to user:**

```
## Codebase Scan Results

**Languages:** [detected]
**Frameworks:** [detected]
**Database/ORM:** [detected]
**Package Manager:** [detected]
**Structure:** [monorepo/single-project]
**Existing Docs:** [what was found]
**Git Remote:** [remote URL]

[If .claude/ exists]: ⚠️ Existing .claude/ directory detected. Will augment, not overwrite.
[If .dotcortex/ exists]: Existing canonical layout detected. Init will repair/extend, not re-bootstrap from scratch.
```

Then proceed to Phase 2.

## Phase 2: User Interview

Ask these questions using AskUserQuestion. Adapt based on scan results.

**IMPORTANT: Save state after every answer.** Write the answer to `.dotcortex/.init-state.json` immediately after the user responds to each question. This way, if the session is interrupted, we resume from the next unanswered question — not from scratch.

**Q1: Project overview**
- Question: "What does this project do? (A brief description for CLAUDE.md)"
- Header: "Overview"
- If README.md was found, pre-populate a suggested description as the first option
- Always include an "Other" option for free text

**Q2: AI coding tools** (multi-select)
- Question: "Which AI coding tools do you use? dotcortex will generate compatible config for each."
- Header: "Tools"
- Options:
  - "Claude Code (Recommended)" — `.claude/` view + `CLAUDE.md` from canonical `.dotcortex/`
  - "OpenAI Codex CLI" — `.agents/` directory, `AGENTS.md`
  - "Gemini CLI" — `.gemini/` directory, `GEMINI.md`
  - "Cursor" — `.cursor/rules/` directory, reads `AGENTS.md`

At least one must be selected. Claude Code is pre-selected as the default since dotcortex runs inside it. If only Codex/Gemini/Cursor are selected without Claude Code, warn that dotcortex commands and skills are designed for Claude Code and may have reduced functionality in other tools.

**Q3: Confirm detected stack** (multi-select)
- Question: "Which of these detected technologies are correct? Deselect any false positives."
- Header: "Stack"
- Options: one per detected framework/language (pre-selected)
- This lets users correct false positives from package.json scanning

**Q4: Workflow rules** (multi-select)
- Question: "Which workflow rules should Claude follow?"
- Header: "Rules"
- Options:
  - "Don't start servers or run tests — I'll test manually"
  - "Don't create documentation files unless asked"
  - "Use [detected package manager] only" (show actual detected one)

**Q5: Task management** (single select)
- Question: "Do you want ticket-based task tracking?"
- Header: "Tasks"
- Options:
  - "Yes, full PM system (tickets, backlog, templates)"
  - "Lightweight (just a TODO list in CLAUDE.md)"
  - "No task tracking"

**Q5a: Context mode** (single select)
- Question: "How should this project use dotcortex context?"
- Header: "Mode"
- Options:
  - "Local-only (Recommended for solo/local use)"
  - "Org-connected (shared org repo + project mapping)"

**Q5b: Symlink compatibility** (single select)
- Question: "How should tool views be built?"
- Header: "Views"
- Options:
  - "Symlink views (Recommended)"
  - "Copy views (fallback for symlink-limited environments)"

**Q6: Ticket prefix** (only if Q5 = full PM)
- Question: "What prefix should tickets use? (e.g., APP, PRJ, or leave blank for repo name)"
- Header: "Prefix"
- Options:
  - First 3 letters of repo name, uppercased (e.g., "MYA" for "my-app")
  - "APP"
  - "PRJ"
- Allow free text via Other

**Q6b: Canonical task location** (only if Q5 = full PM)
- Question: "Task storage uses canonical `.dotcortex/tasks/` with `.tasks/` compatibility view. Continue?"
- Header: "Task path"
- Options:
  - "Yes — use canonical task layout (Recommended)"
  - "Cancel init"

**If existing task files were detected in Phase 1 scan**, add a follow-up:

**Q6c: Migrate existing tasks** (only if Q5 = full PM AND existing tasks detected)
- Question: "Found existing task files in `[detected location]` ([N] files, counter at [X]). Migrate them into `.dotcortex/tasks/`?"
- Header: "Migrate"
- Options:
  - "Yes — move files and preserve counter (Recommended)"
  - "Yes — copy files (keep originals in place)"
  - "No — start fresh, ignore existing tasks"

Before applying migration, ask one confirmation question:
- "Have you backed up `.claude/` and your task directories (`claude_tasks/`, `.tasks/`, or `tasks/`)?"  
If not, pause and let the user back up first.

If multiple candidate task directories are detected, ask:
- "Which path should be treated as the source of truth for migration?"  
Default to the path from legacy config (`tasks_dir`) when available.

**If migrating:**
1. Read the existing `.ticket_counter` value (if present) — new counter starts at this number or higher
2. Move/copy all ticket files (`PREFIX-*.md`) into `.dotcortex/tasks/`
3. Move/copy any `archive/` subdirectory
4. Move/copy `BACKLOG.md` if it exists
5. Move/copy templates if they exist
6. If the old location was a different path (e.g., `claude_tasks/`), rename references in CLAUDE.md and MEMORY.md to canonical `.dotcortex/tasks/` (or `.tasks/` where user-facing compatibility is preferred)
7. If "move" was selected and old directory is now empty, remove it
8. Report: "Migrated [N] tickets, counter at [X], [Y] archived"

**Q7: Git tracking** (multi-select, one row per category)
- Question: "Which parts of your Claude context should be tracked in git? (Unselect to gitignore)"
- Header: "Git tracking"
- Options (each independently toggleable):
  - "Commands (.dotcortex/commands/)" — default: tracked
  - "Skills (.dotcortex/skills/)" — default: tracked
  - "Knowledge (.dotcortex/knowledge/)" — default: tracked
  - "Memory (.dotcortex/memory/MEMORY.md)" — default: tracked
- Note: If task management is enabled (Q5), tasks are handled separately in Q8.

**Q8: Task git tracking** (single select, only if Q5 = full PM)
- Question: "How should task files be stored?"
- Header: "Task git"
- Options:
  - "Same repo — tracked in git alongside code"
  - "Gitignored — personal workflow only"
  - "Separate repo — independent of feature branches"

**Q9: Key components** (free text)
- Question: "What are the main components/services? (e.g., 'API server, web frontend, worker queue')"
- Header: "Components"
- Options:
  - Auto-generated from directory scan (e.g., "Backend (api/), Frontend (web/), Workers (jobs/)")
  - Leave blank option

**Q10: Git autonomy** (single select)
- Question: "How far should Claude take code after completing work?"
- Header: "Autonomy"
- Options:
  - "Just write code — I'll handle git myself"
  - "Stage and commit automatically after completing a task"
  - "Commit and push to remote automatically"
  - "Commit, push, and open a PR automatically"

Based on selection, add the appropriate rules to CLAUDE.md:
- Option 1: "Don't auto-commit — only commit when asked"
- Option 2: "After completing a task, stage relevant files and commit with a descriptive message. Don't push."
- Option 3: "After completing a task, stage, commit, and push to the current branch. Don't open PRs."
- Option 4: "After completing a task, stage, commit, push, and open a draft PR."

**Q11: Team sync** (single select, only if Q8 = same repo or separate repo)
- Question: "How should task state sync across collaborators?"
- Header: "Team sync"
- Options:
  - "Solo — no sync needed, I'm the only one"
  - "Manual — sync only when I run /pm sync"
  - "Auto on mutation — push after creates/updates, pull before reads"
  - "Session bookends — pull at session start, push at session end"

Based on selection, configure the pm-agent skill's sync behavior:
- **Solo:** No sync logic added.
- **Manual:** Add `/pm sync` command. No auto-sync.
- **Auto on mutation:** Add sync rules to pm-agent skill:
  - Before `/backlog`, `/next`, `/standup`, `/pm status`: pull latest task state
  - After `/pm new`, `/pm done`, ticket-new, ticket-breakdown: push task changes
  - On conflict: show both versions, let user resolve
- **Session bookends:** Add to CLAUDE.md:
  - "At the start of each session, pull latest task state before doing anything."
  - "Before ending a session, push all task file changes."

**Q12: Guardrails** (free text)
- Question: "Anything else Claude should never do? (e.g., 'never modify the auth module', 'always use TypeScript strict mode')"
- Header: "Guardrails"
- Options:
  - "No special guardrails"
  - Pre-populated common ones based on stack

**Q13: Org repo connection** (only if Q5a = org_connected)
- Question: "Connect to an org context repo?"
- Header: "Org repo"
- Options:
  - "Select existing repo (discover via gh)"
  - "Create new org context repo"
  - "Enter repo URL manually"
  - "Skip for now (continue as local-only)"

**Q14: Org project mapping** (only if Q13 connects repo)
- Question: "What project key should this repo map to in org context?"
- Header: "Org project"
- Options:
  - Auto-detected repo name from `git remote -v` (Recommended)
  - Enter manually

## Phase 3: Stack Research & Skill Generation

For each confirmed framework/technology from Q3, generate a domain skill file. **Do not use pre-written templates** — research the framework and write appropriate best practices.

Each skill should include:

```markdown
---
name: [skill-name]
description: [one-line description]. Auto-invokes when discussing [trigger keywords].
---

# [Framework] Skill

## Auto-Invoke Triggers
- Keywords that should trigger this skill

## Conventions
- Framework-specific conventions
- File structure expectations
- Naming patterns

## Patterns
- Recommended patterns for this framework
- How to handle common operations
- State management approach

## Anti-Patterns
- Common mistakes to avoid
- Framework-specific gotchas

## Project-Specific Notes
[Woven in from component descriptions and scan results]
```

**Examples of what to include by framework:**

| Framework | Key Skill Content |
|-----------|------------------|
| Rails | RESTful conventions, ActiveRecord patterns, migration best practices, service objects, strong params |
| Next.js | App Router vs Pages, Server Components, data fetching patterns, middleware, ISR/SSR/SSG |
| React Native/Expo | Navigation patterns, native module handling, EAS build, platform branching |
| Django | Model-View-Template, ORM query optimization, middleware, management commands |
| FastAPI | Dependency injection, Pydantic models, async/await, middleware |
| Express | Middleware chain, error handling, route organization |
| Vue/Nuxt | Composition API, Pinia state, auto-imports, server routes |
| Go | Error handling idioms, interface patterns, struct embedding, goroutine safety |
| Rust | Ownership patterns, error handling with Result/Option, trait design |
| Laravel | Eloquent patterns, middleware, service providers, artisan commands |

## Phase 4: File Generation

Generate all files based on collected information. Use the scaffolds as structural reference but fill in real content.

**Watermark rule:** Every file generated by dotcortex must include this comment as the first line:
```
<!-- Generated by dotcortex — https://github.com/brendenclerget/dotcortex -->
```
This applies to: CLAUDE.md, MEMORY.md, all knowledge files, all generated skills. It does NOT apply to task ticket files (those are user content).

### 4.1: CLAUDE.md (project root)

Generate at the project root. Include:
- Project overview from Q1
- Stack summary from scan + Q3
- Component map from Q9
- Tool-specific files based on Q2 selections (see section 4.8)
- Workflow rules from Q4
- Guardrails from Q12
- Quick start commands (infer from detected stack — e.g., `npm run dev`, `rails server`, `cargo run`)
- Skill list with auto-invoke triggers

**Always include these safety rules regardless of user selections:**
```markdown
## Git Safety

**NEVER reset, checkout, or restore files from git without asking first.**
Destructive git operations (`git checkout -- <file>`, `git reset --hard`, `git restore`, `git clean -f`) can silently discard uncommitted work from other sessions or agents. Always explain what will be lost and get explicit confirmation before running any command that discards local changes.
```

### 4.2: `.dotcortex/memory/MEMORY.md`

Generate in `.dotcortex/memory/`. Include:
- Repository layout table (from scan — directories, what they contain)
- Workflow preferences (from Q4)
- Knowledge base index table (pointing to all generated knowledge files with "when to read" guidance)
- Empty "Hot Context" section

### 4.3: `.dotcortex/knowledge/` files

**Always create:**
- `architecture-decisions.md` — Header + "No entries yet" placeholder
- `patterns-and-gotchas.md` — Header + "No entries yet" placeholder

**Conditionally create:**
- `api-patterns.md` — If any backend/API framework detected
- `frontend-patterns.md` — If any frontend framework detected
- `data-model.md` — If any database/ORM detected

Each starts with:
```markdown
# [Topic]

_Entries are added here as patterns are discovered during development. Each entry should be 2-5 lines with a ticket reference if applicable._

## Entries

_No entries yet._
```

### 4.4: Domain skills

Write each generated skill to `.dotcortex/skills/[skill-name]/SKILL.md`.

### 4.5: Task system (if Q5 = full PM)

Task paths are fixed in v1.5:
- Canonical: `.dotcortex/tasks/`
- Compatibility view: `.tasks/ -> .dotcortex/tasks/`

Create all of these, replacing `PREFIX` with the chosen prefix from Q6 and `TASKS_DIR` with `.dotcortex/tasks`:

- `.dotcortex/tasks/.ticket_counter` — Contains "1"
- `.dotcortex/tasks/BACKLOG.md` — Empty scaffold with section headers
- `.dotcortex/tasks/archive/` — Empty directory (create with `.gitkeep`)
- `.dotcortex/tasks/templates/simple-ticket-template.md` — Copy from dotcortex templates, replace PREFIX
- `.dotcortex/tasks/templates/parent-ticket-template.md` — Copy from dotcortex templates, replace PREFIX
- `.dotcortex/tasks/templates/child-ticket-template.md` — Copy from dotcortex templates, replace PREFIX
- `.dotcortex/tasks/templates/followup-ticket-template.md` — Copy from dotcortex templates, replace PREFIX
- `.dotcortex/skills/pm-agent/SKILL.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/skills/backlog-cleanup/SKILL.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/skills/feature-planning/SKILL.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/commands/pm.md` — Copy from dotcortex, replace PREFIX
- `.dotcortex/commands/ticket-new.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/commands/ticket-breakdown.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/commands/ticket-refine.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/commands/ticket-close.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/commands/next.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/commands/backlog.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/commands/standup.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR
- `.dotcortex/commands/pm-sync.md` — Copy from dotcortex, replace PREFIX and TASKS_DIR (only if Q11 != solo)
- `.dotcortex/commands/cortex.md` — Copy from dotcortex
- `.dotcortex/commands/cortex-sync.md` — Copy from dotcortex
- `.dotcortex/commands/org.md` — Copy from dotcortex (if Q5a = org_connected)
- `.dotcortex/commands/cortex-push.md` — Copy from dotcortex (if Q5a = org_connected)
- `.tasks` symlink to `.dotcortex/tasks/` (or copy fallback if symlinks are disabled)

**BACKLOG.md scaffold:**
```markdown
# Backlog

## Active Work

_Nothing in progress._

## Prioritized Backlog

_No tickets yet._

## Small Enhancements

| ID | Description | Priority | Status |
|----|-------------|----------|--------|

## Parking Lot

_Ideas and future considerations._
```

### 4.6: Rebuild Tool Views From Canonical Structure

After writing canonical files, rebuild tool views:

1. `.claude/commands`, `.claude/skills`, `.claude/knowledge`, `.claude/memory` from:
   - `.dotcortex/org/*` (org-global, if connected)
   - `.dotcortex/org/projects/<project_key>/*` (org project overlay, if connected)
   - `.dotcortex/*` (local canonical)
2. Preserve `.claude/settings.local.json` (real file, never symlink over it)
3. Use collision order for shared files: org-global first, org-project second, local third (local wins)
4. Ensure `.tasks -> .dotcortex/tasks/`
5. If symlink mode is disabled (`Q5b = copy views`), copy instead of symlink and warn that views can drift

### 4.7: .gitignore rules

Based on Q7 and Q8, append to the project's `.gitignore`:

```
# AI coding tool context
.claude/plans/
```

If Codex selected, also add: `.codex/` (user config, not project context)
If Gemini selected, also add: `.gemini/settings.json` (user config, not project context)
If Cursor selected, also add: `.cursor/` to gitignore EXCEPT `.cursor/rules/` (rules are shared)

Add these conditionally based on Q7 selections:
- If commands unselected: `.dotcortex/commands/`
- If skills unselected: `.dotcortex/skills/`
- If knowledge unselected: `.dotcortex/knowledge/`
- If memory unselected: `.dotcortex/memory/`

Based on Q8:
- If tasks gitignored: add `.dotcortex/tasks/` and `.tasks` to `.gitignore`
- If tasks in separate repo: add `.dotcortex/tasks/` and `.tasks` to `.gitignore` and initialize a separate git repo in `.dotcortex/tasks/`

If the `.gitignore` file doesn't exist, create it. If it does, append (don't overwrite).

### 4.8: Multi-tool support (based on Q2)

Generate additional files for each tool selected in Q2. `.dotcortex/` is canonical — tool directories are views.

**If Codex CLI selected:**

1. Generate `AGENTS.md` at project root with the same content as `CLAUDE.md`
2. Symlink skills into Codex's expected location:
```bash
mkdir -p .agents/skills
# For each skill directory in .dotcortex/skills/:
ln -s ../../.dotcortex/skills/<skill-name> .agents/skills/<skill-name>
```
3. Add `.agents/` to the dotcortex config's `tools` array

**If Gemini CLI selected:**

1. Generate `GEMINI.md` at project root with the same content as `CLAUDE.md`
2. Symlink skills into Gemini's expected location:
```bash
mkdir -p .gemini/skills
# For each skill directory in .dotcortex/skills/:
ln -s ../../.dotcortex/skills/<skill-name> .gemini/skills/<skill-name>
```
3. Add `.gemini/` to the dotcortex config's `tools` array

**If Cursor selected:**

1. If `AGENTS.md` wasn't already created (Codex not selected), generate it with same content as `CLAUDE.md` — Cursor reads AGENTS.md natively
2. Generate `.cursor/rules/` directory with one `.mdc` file per skill:
```
.cursor/rules/
├── pm-agent.mdc
├── backlog-cleanup.mdc
├── feature-planning.mdc
├── thinking-modes.mdc
└── [domain-skill].mdc
```
3. Each `.mdc` file maps from the SKILL.md:
```yaml
---
description: [skill description from YAML frontmatter]
globs: []
alwaysApply: false
---
[skill SKILL.md body content]
```
   - PM-related skills (`pm-agent`, `backlog-cleanup`, `feature-planning`): set `alwaysApply: false` (agent-requested based on description)
   - Domain skills (e.g., `rails-backend`): set glob patterns based on relevant file extensions (e.g., `**/*.rb` for Rails, `**/*.tsx` for React)
   - `thinking-modes`: set `alwaysApply: true` (always relevant)

**Symlink maintenance note:** Add a comment to the Phase 5 summary explaining that if users add new skills later, they should run `/cortex-update` to regenerate symlinks for other tools, or manually create them.

**Important:** Knowledge files (`.dotcortex/knowledge/`) are NOT symlinked to other tool directories. They are referenced via `@import` syntax in AGENTS.md/GEMINI.md where supported, or inlined into Cursor `.mdc` rules where relevant.

### 4.9: dotcortex config file

Generate `.dotcortex/config.json` to enable future updates via `/cortex-update`.

```json
{
  "schema_version": 1,
  "version": "2.0.0",
  "dotcortex_version": "2.0.0",
  "source": "https://github.com/brendenclerget/dotcortex",
  "installed_at": "YYYY-MM-DDTHH:MM:SSZ",
  "updated_at": "YYYY-MM-DDTHH:MM:SSZ",
  "layout": "dotcortex",
  "config": {
    "prefix": "[chosen prefix from Q6]",
    "tasks_dir": ".dotcortex/tasks",
    "structure_mode": "single_project | org_connected",
    "symlinks": true,
    "task_storage": "same_repo | gitignored | separate_repo",
    "team_sync": "solo | manual | auto_mutation | session_bookends",
    "git_autonomy": "manual | commit | commit_push | commit_push_pr",
    "org": null,
    "tools": ["claude", "codex", "gemini", "cursor"],
    "git_tracking": {
      "commands": true,
      "skills": true,
      "knowledge": true,
      "memory": true
    }
  },
  "managed_files": {
    // For each command, skill, and template file copied from dotcortex:
    // "relative/path/to/file": "sha256-of-rendered-content"
    // Only include files that were copied from dotcortex (not generated content)
    // Generated files (CLAUDE.md, MEMORY.md, domain skills, knowledge) are NOT managed
  }
}
```

If Q13 connected an org repo, set:

```json
"org": {
  "repo": "acme-corp/acme-cortex",
  "project_key": "payments-api",
  "push_enabled": true
}
```

If Q13 selected "create new org context repo", scaffold:
- `RULES.md`
- `knowledge/`
- `skills/`
- `commands/`
- `projects/<project_key>/knowledge/`
- `projects/<project_key>/skills/`
- `projects/<project_key>/commands/`
- `projects/<project_key>/tasks/`

**Computing checksums:** After writing each managed file (with PREFIX/TASKS_DIR replaced), compute its SHA-256 hash and store it. This is how `/cortex-update` detects user modifications later.

**What counts as managed:**
- All files from `commands/` (pm.md, ticket-*.md, next.md, backlog.md, standup.md, dotcortex-init.md, dotcortex-update.md)
- PM skill files (pm-agent, backlog-cleanup, feature-planning)
- Template files (simple, parent, child ticket templates)

**What is NOT managed (project-specific, never auto-updated):**
- CLAUDE.md
- .dotcortex/memory/MEMORY.md
- .dotcortex/knowledge/* files
- Domain skills generated from stack detection
- `.dotcortex/tasks/` contents (BACKLOG.md, .ticket_counter, archive/)

## Phase 5: Cleanup & Summary

**Delete the init state file** — init completed successfully:
```bash
rm -f .dotcortex/.init-state.json
```

Print a summary of everything created:

```
## dotcortex initialized!

### Files created:
- CLAUDE.md (project root)
- .dotcortex/memory/MEMORY.md
- .dotcortex/knowledge/architecture-decisions.md
- .dotcortex/knowledge/patterns-and-gotchas.md
- .claude/ (rebuilt view from canonical .dotcortex/)
- [list all other generated files]

### Skills generated:
- [skill-name] — triggers on: [keywords]
- [...]

### Task management: [enabled with PREFIX-XXX / lightweight / disabled]

### Tools configured:
- [list each selected tool and what was generated]
- e.g., "Claude Code — .claude/ view from .dotcortex, CLAUDE.md"
- e.g., "Codex CLI — .agents/skills/ (symlinked), AGENTS.md"
- e.g., "Gemini CLI — .gemini/skills/ (symlinked), GEMINI.md"
- e.g., "Cursor — .cursor/rules/*.mdc, AGENTS.md"

### Git tracking:
- Tasks: [tracked / gitignored / separate repo]
- Skills & knowledge: [tracked / gitignored]
- Memory: [tracked / gitignored]

### Next steps:
1. Read through CLAUDE.md and adjust anything that doesn't look right
2. Review generated skills in .dotcortex/skills/ — refine for your project
3. As you work, knowledge files will fill up naturally
[if PM enabled]: 4. Run `/pm new <description>` to create your first ticket
[if multi-tool]: 5. Skills are symlinked — adding new skills requires `/cortex-update` to sync to other tools
```

## Non-Destructive Mode

If `.dotcortex/` or `.claude/` already exists when this command runs:

1. **Warn the user:** "Existing context directory detected with: [list existing files]"
2. **Ask:** "How should I handle existing files?"
   - "Augment — add new files, skip existing ones"
   - "Replace — overwrite everything with fresh scaffold"
   - "Cancel — don't change anything"
3. If augmenting, skip any file that already exists and report what was skipped
4. If replacing, proceed as normal (overwrite all)

## Important Notes

- This command generates content dynamically — it does NOT copy static templates for domain skills
- Skills should reflect real framework best practices, not generic placeholders
- The quality of generated skills is the primary value proposition — invest time in making them genuinely useful
- Keep CLAUDE.md concise — it's always loaded, so every line costs context
- MEMORY.md has a 200-line soft limit — keep the index tight

Arguments: $ARGUMENTS
