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

Solo? `/cortex-init` interviews you and sets everything up standalone.

**Org?** Three commands, one shared org repo (your teams' context + all markdown tasks, pulled into everyone's code folder — dotcortex itself is just the tool):

```
/init-org                     # first time: create (or clone) the org repo
/init-team payments           # scaffold a team: context dirs, policy, prefix (registry-checked)
/init-project payments api    # wire THIS workspace: inherit policy, render, connect tasks
```

A teammate onboards by cloning the org repo and running `/init-project` in their workspace. That's it.

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
| `/init-org` · `/init-team` · `/init-project` | Org/team/project onboarding (see Quick Start) |
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
