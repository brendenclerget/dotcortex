# Roadmap

## v1.0 — Foundation (current)

The core scaffolding and PM system.

- [x] `/cortex-init` — Codebase scan, user interview, context scaffolding
- [x] Ticket system — Simple, parent/child, follow-up tickets with counter management
- [x] Commands — `/pm`, `/ticket-new`, `/ticket-breakdown`, `/ticket-refine`, `/next`, `/backlog`, `/standup`, `/pm-sync`
- [x] Skills — pm-agent, backlog-cleanup, feature-planning
- [x] Dynamic skill generation — Framework-appropriate skills based on detected stack
- [x] Configurable task directory — `.tasks/` default, user-named
- [x] Configurable git tracking — Per-category (commands, skills, knowledge, memory, tasks)
- [x] Git autonomy levels — Write-only through full commit+push+PR
- [x] Team sync — Solo, manual, auto-on-mutation, session bookends
- [x] Install script — `install.sh` for one-command setup
- [x] `/cortex-update` — Pull upstream changes while preserving user customizations
- [x] Follow-up tasks — `PREFIX-XXXa/b/c` for tasks discovered during work

## v1.1 — Polish & DX

Improvements from real-world usage.

- [ ] **Dry-run mode for init** — Preview what would be created without writing files
- [ ] **`/pm dashboard`** — Rich summary: active work, velocity, stale tickets, upcoming
- [ ] **Ticket templates from natural language** — "I need to build auth" → auto-select parent vs simple, pre-fill spec
- [ ] **Knowledge auto-extraction** — Detect when a conversation reveals a gotcha/pattern and offer to capture it
- [ ] **Session context loading** — On session start, auto-summarize what was worked on last session
- [ ] **Configurable commit message format** — Conventional commits, ticket-prefixed, custom templates

## v1.5 — Canonical Structure & Org Repo Support

Restructure dotcortex so `.dotcortex/` is the canonical directory, with tool dirs as symlink views. Add org repo support for shared context across projects, plus explicit project-to-org promotion workflows.

**Design doc:** `docs/design/org-context-and-linear-integration.md`
**Scope:** Directory restructure, org repo support, RULES injection, init updates, and bidirectional knowledge/skill promotion.
**Out of scope:** Linear MCP, `/cortex pull`, `/cortex promote`, and any Linear API calls (tracked in v1.2).

**Canonical task rule (v1.5):**
- `.dotcortex/tasks/` is the canonical task location in the project repo.
- `.tasks/` is a compatibility symlink view to `.dotcortex/tasks/`.
- If org is connected, org task state is mirrored at `.dotcortex/org/projects/<project_key>/tasks/` via explicit sync flows.

**Execution order:**
- Core chain: Phase 1 -> Phase 2 -> Phase 3.
- Parallelizable after Phase 3: Phase 4 and Phase 6.
- Integration pass: Phase 5 (with subparts that can start earlier, see below).

### Phase 1: `.dotcortex/` Directory Structure & Migration

*Depends on: none*

Done when:
- [ ] Canonical layout exists: `.dotcortex/{commands,skills,knowledge,memory,tasks}`, `.dotcortex/org/`.
- [ ] `.dotcortex/config.json` is the canonical config (version, source, prefix, tools, org state).
- [ ] Existing installs are detected in `cortex-update` (`.claude`-canonical install vs already migrated layout).
- [ ] Migration moves managed files (`skills/`, `knowledge/`, `commands/`, `memory/`) into `.dotcortex/`.
- [ ] Existing task files are migrated to `.dotcortex/tasks/` (or explicitly preserved with clear config mapping, if migration is not possible).
- [ ] `.claude/settings.local.json` is preserved as-is and never migrated into `.dotcortex/`.
- [ ] Unmanaged `.claude/` files (for example `.claude/hooks/`, `plans/`) are preserved untouched.
- [ ] Migration is idempotent and has a documented rollback path.
- [ ] Migration prompts for user confirmation before structural changes.
- [ ] Symlink-incompatible environments have a documented fallback mode (`symlinks: false` / copy mode).

### Phase 2: Symlink View Rebuild System

*Depends on: Phase 1*

Done when:
- [ ] `.claude/{skills,knowledge,commands,memory}` are rebuilt as views from `.dotcortex` + `.dotcortex/org`.
- [ ] `.tasks` points to `.dotcortex/tasks/` for orchestrated compatibility.
- [ ] Collision policy is deterministic: org-global first, org-project second, local third (local wins).
- [ ] Rebuild is idempotent: stale managed links are removed and recreated cleanly.
- [ ] Rebuild preserves non-managed real files in tool dirs (including `.claude/settings.local.json`).
- [ ] Rebuild triggers are implemented for `cortex-init`, `cortex-update`, `/org add`, `/org remove`, and explicit sync command.
- [ ] Multi-tool views for `.agents/` and `.gemini/` are supported from the same rebuild engine.
- [ ] Cursor `.mdc` generation is either implemented with tests or explicitly deferred to a follow-up roadmap item (not ambiguous).

### Phase 3: Org Repo Connection & Sync

*Depends on: Phases 1, 2*

Done when:
- [ ] `/org add <repo>` clones org repo into `.dotcortex/org/`, updates config, and triggers rebuild.
- [ ] `/org sync` pulls latest org repo state and triggers rebuild.
- [ ] `/org remove` disconnects org safely (config updated, views rebuilt, clear handling for dirty org working tree).
- [ ] Org repo contract is validated: `RULES.md`, `knowledge/`, `skills/`, `commands/`, `projects/<project_key>/{knowledge,skills,commands,tasks}`.
- [ ] Project-to-org task mapping is explicit and documented (`.dotcortex/tasks` canonical local path vs `.dotcortex/org/projects/<project_key>/tasks` org namespace).
- [ ] Parent repo hygiene is defined (`.gitignore` / nested git behavior for `.dotcortex/org` and expected `git status` output).
- [ ] Repo discovery via `gh repo list` is optional UX enhancement, not a required completion gate.

Deferred from this phase:
- Task pickup/completion auto-push triggers and optimistic locking behavior (collaboration automation; track separately to keep v1.5 bounded).

### Phase 4: RULES.md & Task Sync Injection

*Depends on: Phase 3*

Done when:
- [ ] Org `RULES.md` is injected between `DOTCORTEX:ORG` markers in `CLAUDE.md`.
- [ ] Task sync instructions are injected between `DOTCORTEX:TASK_SYNC` markers.
- [ ] Injection is idempotent (repeated runs produce byte-equivalent marker blocks).
- [ ] User-authored content outside managed markers is preserved exactly.
- [ ] Missing `CLAUDE.md` is handled (create or fail with clear instructions; behavior documented).
- [ ] Missing/malformed markers are handled deterministically (repair or append strategy documented).
- [ ] `/org remove` cleans managed marker blocks without damaging unrelated content.

### Phase 5: cortex-init Org Onboarding

Depends on:
- 5a (core init layout): Phases 1-2
- 5b (org onboarding + injection wiring): Phases 3-4

Done when:
- [ ] `cortex-init` scaffolds `.dotcortex/*` as canonical output (not direct `.claude` canonical writes).
- [ ] Existing `.claude` without `.dotcortex` triggers a migration prompt with explicit Yes/No behavior.
- [ ] Existing `.claude/settings.local.json` is preserved and never overwritten.
- [ ] Org onboarding offers: connect existing repo, create new org repo scaffold, manual URL, or skip.
- [ ] If org is enabled, project key is auto-detected from git remote and override is supported.
- [ ] If org is enabled, init invokes rebuild + injection paths from Phases 2 and 4.

### Phase 6: Bidirectional Knowledge & Skill Push

*Depends on: Phase 3*

Done when:
- [ ] `/cortex push knowledge <file>` copies project knowledge into org repo, creates branch, commits, pushes, and opens PR.
- [ ] `/cortex push skill <name>` copies project skill directory into org repo, creates branch, commits, pushes, and opens PR.
- [ ] PR title/body are auto-generated and include promotion context.
- [ ] Destination conflict behavior is defined (overwrite / fail / prompt) and consistent.
- [ ] `push_enabled` config gate is enforced with clear user-facing errors.
- [ ] If `gh` auth is unavailable, command falls back gracefully (branch+commit output + manual PR instructions).

Deferred from this phase:
- Auto-promote on ticket completion (separate follow-up; avoid coupling to PM completion internals in v1.5).

## v1.2 — MCP Integrations

Connect dotcortex's local ticket system to cloud project management tools via MCP servers.

### Linear Integration
- [ ] **MCP server: `dotcortex-linear`**
  - Sync local tickets → Linear issues (bidirectional)
  - Map ticket status (TODO/IN_PROGRESS/DONE) to Linear workflow states
  - Map priority levels
  - Map parent/child → Linear sub-issues
  - Map follow-up tickets → linked issues
  - Sync labels/tags from ticket type field
- [ ] **Skill: `linear-sync`**
  - Auto-invoke on "sync to Linear", "push to Linear"
  - Configurable: which tickets sync (all, tagged, manual)
  - Conflict resolution when both sides change
- [ ] **Init question** — "Do you use Linear? Connect for cloud sync."

### Jira Integration
- [ ] **MCP server: `dotcortex-jira`**
  - Sync local tickets → Jira issues
  - Map ticket types to Jira issue types (Story, Task, Sub-task, Bug)
  - Map parent/child → Jira epic/story hierarchy
  - Sprint assignment from backlog priority tiers
  - Custom field mapping via config
- [ ] **Skill: `jira-sync`**
  - Auto-invoke on "sync to Jira", "push to Jira"
  - Handles Jira's more complex workflow states
  - Board/sprint awareness
- [ ] **Init question** — "Do you use Jira? Connect for cloud sync."

### GitHub Issues/Projects Integration
- [ ] **MCP server: `dotcortex-github`**
  - Sync local tickets → GitHub Issues
  - Map parent tickets → GitHub Project cards
  - Map subtasks → task lists in issue body
  - Auto-link commits and PRs via ticket prefix in commit messages
  - Milestone mapping from backlog tiers
- [ ] **Skill: `github-sync`**
  - Auto-invoke on "sync to GitHub", "create issue"
  - Leverage existing git remote for zero-config connection
- [ ] **Init question** — "Sync tickets to GitHub Issues?"

### Shared MCP Infrastructure
- [ ] **Template-based ticket rendering** — Render local markdown tickets into API-compatible formats per platform
- [ ] **Webhook receiver** — Optional local server for receiving updates from cloud tools
- [ ] **Conflict resolution skill** — Shared logic for bidirectional sync conflicts
- [ ] **Offline-first guarantee** — Cloud tools are enhancement, never required. Full functionality without network.

## v2.0 — Multi-Agent Collaboration

Support for teams where multiple Claude Code instances work on the same codebase.

- [ ] **Ticket locking** — Claim tickets so two agents don't pick up the same work
- [ ] **Agent identity** — Track which agent/session created or modified tickets
- [ ] **Work handoff** — Structured context transfer between sessions (what was done, what's left, blockers)
- [ ] **Shared knowledge accumulation** — Multiple agents contribute to the same knowledge files without conflicts
- [ ] **Task assignment** — Assign tickets to specific agents or humans
- [ ] **Progress broadcasting** — Agents announce when they start/finish tickets

## v2.1 — Analytics & Insights

- [ ] **Velocity tracking** — Tickets completed per week/month, trend lines
- [ ] **Cycle time** — Average time from TODO to DONE
- [ ] **Scope creep detection** — Alert when follow-up count exceeds original subtask count
- [ ] **Knowledge growth metrics** — Track knowledge base size and coverage over time
- [ ] **Cost tracking** — Estimate Claude Code costs per ticket based on thinking mode usage

## Future Ideas (Unprioritized)

- **`npx dotcortex init`** — npm package for zero-clone install
- **`brew install dotcortex`** — Homebrew formula
- **VS Code extension** — Sidebar for ticket management, backlog visualization
- **Cursor integration** — Cursor-specific rules generation alongside CLAUDE.md
- **Multi-repo monorepo support** — Shared task system across related repositories
- **Retrospective command** — `/retro` to review completed work, extract patterns, plan improvements
- **Time estimation learning** — Track estimate vs actual, improve future estimates
- **Dependency graph visualization** — Mermaid diagrams of ticket dependencies
- **Custom skill marketplace** — Share and discover community-built skills
