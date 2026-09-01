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
- Check common task locations: `.tasks/`, `tasks/`, legacy `claude_tasks/`, `.claude/tasks/`
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
- "Have you backed up `.claude/` and your task directories (legacy `claude_tasks/`, `.tasks/`, or `tasks/`)?"  
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
6. If the old location was a different path (e.g., legacy `claude_tasks/`), rename references in CLAUDE.md and MEMORY.md to canonical `.dotcortex/tasks/` (or `.tasks/` where user-facing compatibility is preferred)
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

**Q11: Task remote** (single select, only if Q8 = same repo or separate repo)
- Question: "Does task state sync with a remote (teammates or a second machine)?"
- Header: "Task remote"
- Options:
  - "Solo, local only — no remote sync"
  - "Remote-synced — a shared task repo other sessions/people also write to"

There is exactly ONE sync contract when a remote exists (no modes): **every task mutation is an immediate scoped commit + push** — pull before reads, `git add <exact touched paths>` (never `-A`), commit, push, retry once on rejection. Session bookends and per-mode behavior do not exist; the pm-agent skill's Team Sync section documents the contract. Solo installs skip sync logic entirely.

**Q12: Guardrails** (free text)
- Question: "Anything else Claude should never do? (e.g., 'never modify the auth module', 'always use TypeScript strict mode')"
- Header: "Guardrails"
- Options:
  - "No special guardrails"
  - Pre-populated common ones based on stack

**Q13: Team context connection** (only if Q5a = org_connected)
- Question: "Connect to a team context repo (shared skills/commands/knowledge/policy)?"
- Header: "Org repo"
- Options:
  - "Select existing repo (discover via gh)"
  - "Create new team context repo"
  - "Enter repo URL manually"
  - "Skip for now (continue as local-only)"

**Q14: Task-repo project mapping** (only if Q13 connects repo and a shared task repo is used)
- Question: "What team/project key does this project's task tree use in the shared task repo (teams/<team>/projects/<project>/)?"
- Header: "Task mapping"
- Options:
  - Auto-detected repo name from `git remote -v` (Recommended)
  - Enter manually

**Q15: Workflow policy** (asked AFTER Q13/Q14 so team-context connection is already resolved — when Q13 connected an existing team context, INHERIT the team's policy and SKIP this question entirely; ask only for fresh/standalone setups)
- Question: "Who runs what? (These render into CLAUDE.md's workflow rules.)"
- Collect single-select values for: `test_authoring` (allowed/ask), `test_execution` (allowed/ask/user_only), `server_lifecycle` (allowed/ask/user_only), `endpoint_probing` (allowed/ask/user_only), `documentation_creation` (allowed/ask), `ticket_creation` (proactive/followups_only/explicit_only), `ticket_close` (auto/ask)
- Defaults (non-interactive): allowed / allowed / ask / allowed / ask / followups_only / ask
- Store under `config.workflow_policy` (validated by `schemas/config.schema.json`); the CLAUDE.md `WORKFLOW_POLICY` marker block renders from these values — never hand-edited.


**Q16: Linear** (only if Q5 = full PM)
- Question: "Attach tickets to Linear issues via the Linear MCP?"
- Options: "Yes — Linear is our tracker" / "No — markdown only"
- If yes: set `config.linear.enabled = true`. Commands use the Linear MCP when it's connected in a session, prompt the user to connect it when enabled-but-absent, and skip silently when disabled. No further Linear setup happens at init.


**Q17: Cross-model review** (single select)
- Question: "Enable the cross-model review profile (/fix, /implement-review)? Requires a second model family's CLI."
- Options: "Yes — configure reviewer now" / "Skip — no review profile"
- If yes: collect `review.reviewer_cli`, `review.reviewer_model`, `review.coordinator_cli`, `review.coordinator_model`. CLI paths/models are per-machine — write them to `.dotcortex/config.local.json` (gitignored; the renderer overlays it for token values) and leave `config.review` unset in the shared config.
- If skipped: EXCLUDE the `review` profile from the Phase 4.5 staging (its files contain review tokens that would fail strict rendering).


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

### 4.5: Base render pipeline (ALL installs) + task system (if Q5 = full PM)

Task paths are fixed in v1.5:
- Canonical: `.dotcortex/tasks/`
- Compatibility view: `.tasks/ -> .dotcortex/tasks/`

**Base assets are NOT copied by the model.** They render through the deterministic pipeline:

1. Write `.dotcortex/config.json` first (Phase 4.9's schema — the renderer reads token values from it).
2. Locate the source checkout: `source_checkout` in `.dotcortex/install-info.json` (recorded by install.sh). If that path no longer exists, clone `config.source` and check out the exact tag recorded as `dotcortex_version` in install-info.
3. Assemble a staging tree from the selected profiles: for each enabled profile in `<source_checkout>/base/profiles.json` — `core` ALWAYS renders, for every install mode including lightweight/no-task setups; `pm` only if Q5 = full PM; `review` only if Q17 configured it; packs per interview, copy that profile's `commands/`, `skills/`, `templates/` subtrees from `base/` into one temp staging dir, and write `<staging>/.sources.json` mapping every staged-relative path to its repository-relative origin (e.g. `"commands/ticket-new.md": "base/pm/commands/ticket-new.md"`) — the renderer uses this for git-retrievable manifest sources. (`scaffolds/` are NOT rendered — they are interview templates consumed directly by Phase 4.1, with their own `{{...}}` slot vocabulary the renderer must never see.)
4. **Migrate bootstrap commands into the layer** so the resolved view can own `.dotcortex/commands`: `mkdir -p .dotcortex/layers/org/commands && mv .dotcortex/commands/cortex-init.md .dotcortex/commands/cortex-update.md .dotcortex/layers/org/commands/` (then remove the now-empty `.dotcortex/commands` dir).
5. Render: `.dotcortex/bin/render.sh --source <staging> --dest .dotcortex/layers/org --strict --config .dotcortex/config.json --base-version <dotcortex_version from install-info>`. Strict mode means an unresolved `{{TOKEN}}` aborts with nothing written — fix the config, re-run. The renderer records every file in `managed_files` (sha256 + base_version + repository-relative source).
6. Resolve views: `.dotcortex/bin/rebuild-views.sh --root <project-root>` (Phase 4.6).

Task-state scaffolding (data, not behavior). Two shapes depending on `task_repo` config:

**Shared namespaced task repo** (`config.task_repo` set — the team default):
1. Clone `task_repo.url` to `.dotcortex/task-repo/` (add `.dotcortex/task-repo/` to `.gitignore`).
2. Ensure the namespace path exists: `teams/<team_key>/projects/<project_key>/` — if absent, create it with the scaffold files below and land it via `.dotcortex/bin/task-tx.sh --dir .dotcortex/task-repo --msg "scaffold <team>/<project>" teams/<team_key>/projects/<project_key>/`.
3. `ln -s task-repo/teams/<team_key>/projects/<project_key> .dotcortex/tasks`
4. Migrating an existing FLAT task repo into the namespace: run `scripts/migrate-task-repo.sh --repo <checkout> --team <t> --project <p>` from the source checkout (history-preserving `git mv` commit; rollback = `git revert`).

**Local/simple** (no `task_repo`): `.dotcortex/tasks/` is a plain directory (own git repo if `task_storage: separate_repo`).

Scaffold files (either shape):
- `.ticket_counter` — Contains "1"
- `BACKLOG.md` — Empty scaffold with section headers (below)
- `TODO.md` — Empty ordered-queue scaffold (`# TODO` + empty table)
- `archive/` — Empty directory (create with `.gitkeep`)
- `.tasks` symlink to `.dotcortex/tasks/` (or copy fallback if symlinks are disabled)

Note: ticket templates are behavior, not task data — they render into the org layer and resolve at `.dotcortex/templates/`; commands reference them there.

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

Layer resolution and tool views have exactly one engine:

```bash
.dotcortex/bin/rebuild-views.sh --root <project-root>
```

It resolves `.dotcortex/layers/org` → `.dotcortex/layers/team` (team wins; overrides reported) into `.dotcortex/{commands,skills,knowledge,templates,memory}` and points `.claude/*` and `.agents/skills` at the resolved dirs. Do not re-implement any of that here. Afterwards:

1. Preserve `.claude/settings.local.json` (real file, never symlink over it)
2. Ensure `.tasks -> .dotcortex/tasks/`
3. If symlink mode is disabled (`Q5b = copy views`), copy instead of symlink and warn that views can drift

### 4.7: .gitignore rules

Based on Q7 and Q8, append to the project's `.gitignore`:

```
# AI coding tool context
.claude/plans/
.dotcortex/config.local.json
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
├── backlog-validation.mdc
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
   - PM-related skills (`pm-agent`, `backlog-validation`, `feature-planning`): set `alwaysApply: false` (agent-requested based on description)
   - Domain skills (e.g., `rails-backend`): set glob patterns based on relevant file extensions (e.g., `**/*.rb` for Rails, `**/*.tsx` for React)
   - `thinking-modes`: set `alwaysApply: true` (always relevant)

**Symlink maintenance note:** Add a comment to the Phase 5 summary explaining that if users add new skills later, they should run `/cortex-update` to regenerate symlinks for other tools, or manually create them.

**Important:** Knowledge files (`.dotcortex/knowledge/`) are NOT symlinked to other tool directories. They are referenced via `@import` syntax in AGENTS.md/GEMINI.md where supported, or inlined into Cursor `.mdc` rules where relevant.

### 4.9: dotcortex config file

Generate `.dotcortex/config.json` to enable future updates via `/cortex-update`.

The file must be **valid JSON** (no comments) and validate against `schemas/config.schema.json`. Every value below is a single resolved token from the interview — never the `a | b` alternatives notation. Note there is NO version field here (canonical version lives in `install-info.json.dotcortex_version`) and NO `team_sync` field (one sync contract, no modes — Q11 only decides whether a remote exists).

```json
{
  "schema_version": 1,
  "source": "https://github.com/brendenclerget/dotcortex",
  "installed_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z",
  "config": {
    "prefix": "APP",
    "tasks_dir": ".dotcortex/tasks",
    "project_name": "ExampleProject",
    "component_repos": ["api", "app"],
    "profiles": ["core", "pm"],
    "symlinks": true,
    "task_storage": "separate_repo",
    "task_remote": true,
    "git_autonomy": "manual",
    "tools": ["claude", "codex"],
    "workflow_policy": {
      "test_authoring": "allowed",
      "test_execution": "user_only",
      "server_lifecycle": "user_only",
      "endpoint_probing": "ask",
      "documentation_creation": "ask",
      "ticket_creation": "followups_only",
      "ticket_close": "ask"
    },
    "linear": { "enabled": false },
    "git_tracking": {
      "commands": true,
      "skills": true,
      "knowledge": true,
      "memory": true
    }
  },
  "managed_files": {}
}
```

Fill from the interview: `prefix` (Q6), `project_name` + `component_repos` (Phase 1 scan), `profiles` (Q5/Q17/pack questions — include `review` only if Q17 configured it), `task_storage`/`task_remote` (Q8/Q11), `workflow_policy` (Q15, or inherited from team context), `linear.enabled` (Q16), `tools` (Q2). `managed_files` starts empty — the Phase 4.5 render fills it. Machine-local review values (Q17) go in gitignored `.dotcortex/config.local.json` with the same `{"config": {"review": {...}}}` shape.

If Q13 connected an existing team context repo, record it as `context_repo: {url, checkout_path: ".dotcortex/layers/team", branch, team_key}` — the legacy `org` block (with `project_key`) no longer exists.

If Q13 selected "create new team context repo", scaffold the TEAM layer (two-layer topology — org-base comes from the dotcortex repo itself; there is NO per-project context tree):
- `commands/`
- `skills/`
- `knowledge/`
- `templates/`
- `policy/` (the team workflow_policy lives here)
- `memory/` (team MEMORY.md index)

Record it in config as `context_repo: {url, checkout_path: ".dotcortex/layers/team", branch, team_key}` — never `org.project_key` or project-scoped context paths. Tasks are NOT part of the context repo (task repo is separate; see task_repo config).

**Checksums are the renderer's job, not yours:** `bin/render.sh` records every rendered file's SHA-256, base_version, and repository-relative source into `managed_files` as part of Phase 4.5. Never compute or write manifest entries by hand — if `managed_files` is empty after init, the render step was skipped and must be re-run.

**What counts as managed:**
- All files from `commands/` (pm.md, ticket-*.md, next.md, backlog.md, standup.md, dotcortex-init.md, dotcortex-update.md)
- PM skill files (pm-agent, backlog-validation, todo-queue, feature-planning, thinking-modes)
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
