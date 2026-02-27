# Roadmap

## v1.0 — Foundation (current)

The core scaffolding and PM system.

- [x] `/cortex-init` — Codebase scan, user interview, context scaffolding
- [x] Ticket system — Simple, parent/child, follow-up tickets with counter management
- [x] Commands — `/pm`, `/ticket-new`, `/ticket-breakdown`, `/ticket-refine`, `/next`, `/backlog`, `/standup`, `/pm-sync`
- [x] Skills — pm-agent, backlog-cleanup, feature-planning, thinking-modes
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
