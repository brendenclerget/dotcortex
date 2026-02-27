---
name: localmem-init
description: Bootstrap Claude Code context management for any project. Scans codebase, interviews user, generates skills/knowledge/memory.
---

# localmem-init: Context Bootstrap

You are initializing Claude Code's context management system for this project. Follow these phases exactly.

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
- Any existing `.claude/` directory

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
```

Then proceed to Phase 2.

## Phase 2: User Interview

Ask these questions using AskUserQuestion. Adapt based on scan results.

**Q1: Project overview**
- Question: "What does this project do? (A brief description for CLAUDE.md)"
- Header: "Overview"
- If README.md was found, pre-populate a suggested description as the first option
- Always include an "Other" option for free text

**Q2: Confirm detected stack** (multi-select)
- Question: "Which of these detected technologies are correct? Deselect any false positives."
- Header: "Stack"
- Options: one per detected framework/language (pre-selected)
- This lets users correct false positives from package.json scanning

**Q3: Workflow rules** (multi-select)
- Question: "Which workflow rules should Claude follow?"
- Header: "Rules"
- Options:
  - "Don't start servers or run tests — I'll test manually"
  - "Don't create documentation files unless asked"
  - "Use [detected package manager] only" (show actual detected one)

**Q4: Task management** (single select)
- Question: "Do you want ticket-based task tracking?"
- Header: "Tasks"
- Options:
  - "Yes, full PM system (tickets, backlog, templates)"
  - "Lightweight (just a TODO list in CLAUDE.md)"
  - "No task tracking"

**Q5: Ticket prefix** (only if Q4 = full PM)
- Question: "What prefix should tickets use? (e.g., APP, PRJ, or leave blank for repo name)"
- Header: "Prefix"
- Options:
  - First 3 letters of repo name, uppercased (e.g., "MYA" for "my-app")
  - "APP"
  - "PRJ"
- Allow free text via Other

**Q5b: Task directory** (only if Q4 = full PM)
- Question: "Where should task files live?"
- Header: "Task dir"
- Options:
  - ".tasks/ (Recommended)" — top-level, clean default
  - ".claude/tasks/" — grouped with other Claude context
  - "tasks/" — fully visible, no dot-prefix
- Allow free text via Other for custom path

**Q6: Git tracking** (multi-select, one row per category)
- Question: "Which parts of your Claude context should be tracked in git? (Unselect to gitignore)"
- Header: "Git tracking"
- Options (each independently toggleable):
  - "Commands (.claude/commands/)" — default: tracked
  - "Skills (.claude/skills/)" — default: tracked
  - "Knowledge (.claude/knowledge/)" — default: tracked
  - "Memory (.claude/memory/MEMORY.md)" — default: tracked
- Note: If task management is enabled (Q4), tasks are handled separately in Q7.

**Q7: Task git tracking** (single select, only if Q4 = full PM)
- Question: "How should task files be stored?"
- Header: "Task git"
- Options:
  - "Same repo — tracked in git alongside code"
  - "Gitignored — personal workflow only"
  - "Separate repo — independent of feature branches"

**Q8: Key components** (free text)
- Question: "What are the main components/services? (e.g., 'API server, web frontend, worker queue')"
- Header: "Components"
- Options:
  - Auto-generated from directory scan (e.g., "Backend (api/), Frontend (web/), Workers (jobs/)")
  - Leave blank option

**Q9: Git autonomy** (single select)
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

**Q10: Team sync** (single select, only if Q7 = same repo or separate repo)
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

**Q11: Guardrails** (free text)
- Question: "Anything else Claude should never do? (e.g., 'never modify the auth module', 'always use TypeScript strict mode')"
- Header: "Guardrails"
- Options:
  - "No special guardrails"
  - Pre-populated common ones based on stack

## Phase 3: Stack Research & Skill Generation

For each confirmed framework/technology from Q2, generate a domain skill file. **Do not use pre-written templates** — research the framework and write appropriate best practices.

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
[Woven in from Q9 component descriptions and scan results]
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

**Watermark rule:** Every file generated by localmem must include this comment as the first line:
```
<!-- Generated by localmem — https://github.com/brendenclerget/localmem -->
```
This applies to: CLAUDE.md, MEMORY.md, all knowledge files, all generated skills. It does NOT apply to task ticket files (those are user content).

### 4.1: CLAUDE.md (project root)

Generate at the project root. Include:
- Project overview from Q1
- Stack summary from scan + Q2
- Component map from Q9
- Workflow rules from Q3
- Guardrails from Q10
- Quick start commands (infer from detected stack — e.g., `npm run dev`, `rails server`, `cargo run`)
- Skill list with auto-invoke triggers

### 4.2: .claude/memory/MEMORY.md

Generate in `.claude/memory/`. Include:
- Repository layout table (from scan — directories, what they contain)
- Workflow preferences (from Q3)
- Knowledge base index table (pointing to all generated knowledge files with "when to read" guidance)
- Empty "Hot Context" section

### 4.3: .claude/knowledge/ files

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

Write each generated skill to `.claude/skills/[skill-name]/SKILL.md`.

### 4.5: Task system (if Q4 = full PM)

Create all of these, replacing `PREFIX` with the chosen prefix from Q5 and `TASKS_DIR` with the chosen path from Q5b (default `.tasks`):

- `TASKS_DIR/.ticket_counter` — Contains "1"
- `TASKS_DIR/BACKLOG.md` — Empty scaffold with section headers
- `TASKS_DIR/archive/` — Empty directory (create with `.gitkeep`)
- `TASKS_DIR/templates/simple-ticket-template.md` — Copy from localmem templates, replace PREFIX
- `TASKS_DIR/templates/parent-ticket-template.md` — Copy from localmem templates, replace PREFIX
- `TASKS_DIR/templates/child-ticket-template.md` — Copy from localmem templates, replace PREFIX
- `TASKS_DIR/templates/followup-ticket-template.md` — Copy from localmem templates, replace PREFIX
- `.claude/skills/pm-agent/SKILL.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/skills/backlog-cleanup/SKILL.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/skills/feature-planning/SKILL.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/skills/thinking-modes/SKILL.md` — Copy from localmem (no replacements needed)
- `.claude/commands/pm.md` — Copy from localmem, replace PREFIX
- `.claude/commands/ticket-new.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/commands/ticket-breakdown.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/commands/ticket-refine.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/commands/next.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/commands/backlog.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/commands/standup.md` — Copy from localmem, replace PREFIX and TASKS_DIR
- `.claude/commands/pm-sync.md` — Copy from localmem, replace PREFIX and TASKS_DIR (only if Q10 != solo)

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

### 4.6: .gitignore rules

Based on Q6 and Q7, append to the project's `.gitignore`:

```
# Claude Code context
.claude/plans/
```

Add these conditionally based on Q6 selections:
- If commands unselected: `.claude/commands/`
- If skills unselected: `.claude/skills/`
- If knowledge unselected: `.claude/knowledge/`
- If memory unselected: `.claude/memory/`

Based on Q7 (use the actual TASKS_DIR path from Q5b):
- If tasks gitignored: add TASKS_DIR to `.gitignore`
- If tasks in separate repo: add TASKS_DIR to `.gitignore` and init a separate git repo inside it

If the `.gitignore` file doesn't exist, create it. If it does, append (don't overwrite).

### 4.7: localmem config file

Generate `.claude/.localmem.json` to enable future updates via `/localmem-update`.

```json
{
  "version": "1.0.0",
  "source": "https://github.com/brendenclerget/localmem",
  "installed_at": "YYYY-MM-DD",
  "updated_at": "YYYY-MM-DD",
  "config": {
    "prefix": "[chosen prefix from Q5]",
    "tasks_dir": ".tasks",
    "task_storage": "same_repo | gitignored | separate_repo",
    "team_sync": "solo | manual | auto_mutation | session_bookends",
    "git_autonomy": "manual | commit | commit_push | commit_push_pr",
    "git_tracking": {
      "commands": true,
      "skills": true,
      "knowledge": true,
      "memory": true
    }
  },
  "managed_files": {
    // For each command, skill, and template file copied from localmem:
    // "relative/path/to/file": "sha256-of-rendered-content"
    // Only include files that were copied from localmem (not generated content)
    // Generated files (CLAUDE.md, MEMORY.md, domain skills, knowledge) are NOT managed
  }
}
```

**Computing checksums:** After writing each managed file (with PREFIX/TASKS_DIR replaced), compute its SHA-256 hash and store it. This is how `/localmem-update` detects user modifications later.

**What counts as managed:**
- All files from `commands/` (pm.md, ticket-*.md, next.md, backlog.md, standup.md, localmem-init.md, localmem-update.md)
- PM skill files (pm-agent, backlog-cleanup, feature-planning, thinking-modes)
- Template files (simple, parent, child ticket templates)

**What is NOT managed (project-specific, never auto-updated):**
- CLAUDE.md
- .claude/memory/MEMORY.md
- .claude/knowledge/* files
- Domain skills generated from stack detection
- TASKS_DIR contents (BACKLOG.md, .ticket_counter, archive/)

## Phase 5: Summary

Print a summary of everything created:

```
## localmem initialized!

### Files created:
- CLAUDE.md (project root)
- .claude/memory/MEMORY.md
- .claude/knowledge/architecture-decisions.md
- .claude/knowledge/patterns-and-gotchas.md
- [list all other generated files]

### Skills generated:
- [skill-name] — triggers on: [keywords]
- [...]

### Task management: [enabled with PREFIX-XXX / lightweight / disabled]

### Git tracking:
- Tasks: [tracked / gitignored / separate repo]
- Skills & knowledge: [tracked / gitignored]
- Memory: [tracked / gitignored]

### Next steps:
1. Read through CLAUDE.md and adjust anything that doesn't look right
2. Review generated skills in .claude/skills/ — refine for your project
3. As you work, knowledge files will fill up naturally
[if PM enabled]: 4. Run `/pm new <description>` to create your first ticket
```

## Non-Destructive Mode

If `.claude/` already exists when this command runs:

1. **Warn the user:** "Existing .claude/ directory detected with: [list existing files]"
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
