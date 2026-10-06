<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-light.svg">
    <img alt=".cortex" src="https://github.com/brendenclerget/dotcortex/raw/main/.github/logo-light.svg" width="280">
  </picture>
</p>

<p align="center">
  <strong>Shared context and markdown task management for Claude Code teams.</strong>
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

dotcortex installs a `.dotcortex/` directory into a project: skills, commands, knowledge, memory, and a file-based ticket system. It scans the codebase, walks you through setup, and renders the base install from a tagged release. Given the same release and the same config (including the machine-local overlay), managed files are byte-identical on every machine; a manifest records the hash and source version of each so updates can merge against what was actually installed.

For teams, one shared org repo holds every team's context and every project's tickets. Engineers clone it and connect their projects to it.

## Quick Start

```bash
# 1. Clone dotcortex
git clone https://github.com/brendenclerget/dotcortex.git ~/dotcortex

# 2. Install into your project (bootstrap commands, render engine, config schema)
~/dotcortex/install.sh /path/to/your/project
#    non-interactive: ~/dotcortex/install.sh --yes /path/to/your/project

# 3. Open Claude Code in the project and run one of:
/cortex-init                  # standalone project, no org
/init-org                     # first org setup: creates the shared org repo, first team, first project
/init-project <team> <name>   # joining an existing org and team (see Teams)
```

Running `install.sh` again on an existing project refreshes the engine, schema, and bootstrap commands. Rendered content is updated with `/cortex-update`.

## How It Works

Standalone setup (`/cortex-init`); the org commands follow the same order.

```
┌──────────────────────────────────────────────────────────┐
│  /cortex-init                                            │
│                                                          │
│  1. Scan       Languages, frameworks, ORM, structure,    │
│                existing docs and tasks                   │
│                                                          │
│  2. Interview  Workflow policy, task storage, team       │
│                context, Linear, cross-model review       │
│                                                          │
│  3. Research   Stack-specific skills written from your   │
│                actual frameworks                         │
│                                                          │
│  4. Generate   CLAUDE.md, project skills/knowledge/      │
│                memory into your layer                    │
│                                                          │
│  5. Render     Selected profiles → token render          │
│                (--strict) → manifest → view rebuild      │
└──────────────────────────────────────────────────────────┘
```

Two kinds of content:

- **Rendered base** — PM commands, review workflow, templates. Comes from the dotcortex base (`base/` in this repo) by profile. Same release tag, profiles, and config produce the same files. Each file is tracked in `managed_files` with its hash and source version.
- **Generated context** — stack skills, knowledge, memory, and `CLAUDE.md`. Written from the scan and interview. Skills/knowledge/memory go into your layer (`.dotcortex/layers/team/`); `CLAUDE.md` sits at the project root with its rules blocks rendered from config inside managed markers. Updates do not touch generated content.

Per-machine values (reviewer CLI paths and models) live in gitignored `.dotcortex/config.local.json`.

## What Gets Installed

### Install profiles

| Profile | Contents | Default |
|:--------|:---------|:--------|
| `core` | CLAUDE.md template with marker blocks, `/commit` | always |
| `pm` | Ticket system: pm-agent skill, ticket commands, TODO queue, templates, backlog validation | on |
| `review` | `/fix`, `/implement-review` | opt-in; needs a second model family's CLI |
| `testing` | Maestro mobile UI automation skill | opt-in |
| `design` | `/design-implement` — design parity from in-repo design artifacts | opt-in |
| `boards` | Per-team ticket and decision boards on claude.ai Artifacts: engineers answer agents' questions, close tickets, and decide what gets built | opt-in; needs `pm` |
| `orchestration` | `/session`: the main session orchestrates while background agents build tickets in per-repo worktrees, from one shared brief | opt-in; needs `pm` |
| `launch-planning` | MVP scoping and execution lanes | shipped disabled |

### Stack-detected skills

Generated from the scan, not copied from templates.

| Detected | Skill |
|:---------|:------|
| Rails | `rails-backend` |
| Next.js | `nextjs` |
| React Native / Expo | `react-native` |
| Django / FastAPI | `python-backend` |
| Go (gin, chi, echo) | `go-backend` |

Skills load on context keywords. When a closed ticket produced durable learnings, `/ticket-close` adds them to the team layer.

### Workflow policy

`config.workflow_policy` records who runs tests, who starts servers, whether the agent may create or close tickets, and similar rules as fixed values (for example `test_execution: user_only`, `ticket_creation: followups_only`). The rules block in `CLAUDE.md` is rendered from it; edit the config, not the block. Projects in an org inherit their team's policy.

`crucial_decisions` sets what an agent does when it hits a crucial call: policy, money, security and permissions, public promises, anything hard to reverse. `block` (the default) means nothing gets built for that piece until a person answers; the agent records the question, marks the work blocked, and carries on with anything separable. `build_conservative` builds the least-change option behind a setting and asks.

## Task Management

> Optional. Chosen during init.

Tickets are markdown files in git. With Linear mode on, commands create and update linked Linear issues through the Linear MCP when it is connected; if it is not connected they stop and ask you to connect it. With Linear off, everything stays in markdown.

The ticket and its Linear issue are different documents. The ticket is the agent's working context: criteria, questions, technical notes, log. The Linear issue is light tracking for people: a title, a one- or two-sentence summary, status, assignee, priority, the team's labels and a pointer back to the ticket. Content never syncs either way; only status, assignee and priority do.

### Ticket core

Every template carries the fields the boards and agents rely on. The rest of a ticket is free-form.

| Field | Meaning |
|:------|:--------|
| `**Assignee:**` | The engineer who owns the ticket and answers its questions (claude.ai email or name). Agents never reassign it. |
| `**Review:**` | `none`, `decision-needed` (someone must answer) or `closure-proposed` (the agent believes it's done) |
| `- [ ] AC1: …` | Acceptance criteria with stable ids, checked from code and tests, never from log lines |
| `## Needs from assignee` | `None.`, or numbered questions that each stand on their own, with options, a recommendation and what's built |

Questions an agent needs answered before work can START go into the team's decision log (`decisions/<log>.yml` in the team layer: `team.yml`, or a log per feature when an engineer asks for one). Questions on work in flight are asks on the ticket. One question lives in one place.

### Tech debt

`/debt` keeps long-lived, per-team tech-debt lists (`debt/DEBT-<AREA>-<topic>.md` in the team layer). Entries have stable ids, evidence and a recommended fix; they move to Resolved instead of being deleted. Agents add small recurring problems there instead of opening one-off tickets.

```
.dotcortex/tasks/
├── .ticket_counter
├── BACKLOG.md
├── TODO.md                            # ordered next-work queue (/todo)
├── APP-041-auth-flow/
│   ├── APP-041-auth-flow.md           # parent ticket
│   ├── APP-041a-login-endpoint.md     # letter child, no counter number
│   └── APP-041b-session-management.md
├── APP-042-fix-cors.md                # standalone ticket
└── archive/2026-09/                   # closed tickets are moved here

.tasks -> .dotcortex/tasks/            # compatibility symlink
```

Subtasks are letter children (`APP-041a/b/c`). They do not consume counter numbers. Top-level IDs are allocated inside a locked git transaction that retries on push rejection, or taken from the Linear issue when Linear is on.

### Commands

| Command | What it does |
|:--------|:-------------|
| `/pm new <desc>` | Create a simple ticket (work under about four hours) |
| `/ticket-new` | Parent ticket with breakdown, for larger work |
| `/implement <id>` | Claim a ticket, reconcile its plan against the current tree, build, report acceptance criteria |
| `/ticket-breakdown <id>` | Split a ticket into letter children |
| `/ticket-refine <id>` | Refine scope; remaining work becomes letter children |
| `/ticket-status <id> <status>` | Change status and assignee, sync boards, commit, mirror to Linear |
| `/ticket-close <id>` | Verify, archive, update boards, add durable learnings to the team layer when present, update Linear |
| `/ticket-audit <id>` | Per-ticket audit prompt for an external reviewer |
| `/todo` | Ordered next-work queue with lanes and parallel-session rules |
| `/debt` | The team's tech-debt lists: list, add, work a batch, resolve |
| `/ticket-board` · `/ticket-board-apply` | Publish the team's ticket board; apply engineers' answers and close calls (`boards`) |
| `/decision-board` · `/decision-board-apply` | Publish the team's decision board; apply the answers (`boards`) |
| `/session [focus]` | Start an orchestrated working session (`orchestration`) |
| `/next` · `/backlog` · `/standup` · `/pm` | Recommendations, boards, progress, command index |
| `/pm-sync` | Pull and push the task repo |
| `/fix` | Take another agent's review findings, verify each against the tree, fix the confirmed ones |
| `/implement-review <id>` | Implement, then one review pass by the other model family; reports SKIPPED if none is configured |
| `/commit` | Commit workflow aware of nested repos |
| `/init-org` · `/init-team` · `/init-project` | Org, team, and project onboarding |
| `/context add\|sync\|remove` | Connect this project to a team context repo directly |
| `/cortex-sync` | Pull team context and rebuild views |
| `/cortex push skill\|command\|knowledge <name>` | Open a PR moving a team asset into the dotcortex base |
| `/cortex-update` | Update the rendered base from the latest release tag |

## Boards and orchestrated sessions

**Boards** (`boards` pack). Each team gets one ticket board and one decision board, published as claude.ai Artifacts. The URLs are recorded in the team layer's `boards.json`. Each engineer sees their own lane ("Yours": asks for them, tickets of theirs ready to close), matched from their claude.ai identity to the ticket's Assignee or the decision's owner, with a "Viewing as" switch. Answering on the board is the review: apply commands write the answers back into the tickets and decision logs. Share boards with at least "can interact" access, or teammates' answers are refused.

**Orchestrated sessions** (`orchestration` pack). `/session` starts a session where the main agent only plans, reviews, tickets, merges and reports, and background agents each build one ticket:
- Each agent gets its own worktree per component repo, its own ports and its own test database. The commands come from the team's `knowledge/agent-workspace.md`.
- Every agent follows one shared brief: isolation, crucial calls, ask format, tests, cleanup, and the shape of its final report.
- Merges go one branch at a time through an integration worktree. Suites run before every push, and the push is never chained onto the test command.
- Review findings get at most two fix rounds. What's left becomes a hardening ticket.
- `git_autonomy` decides whether the orchestrator may merge or push at all.

## Teams

An org uses one **shared org repo**. It holds each team's context and each project's tickets:

```
<org-repo>/
├── REGISTRY.md                       # team_key | prefix | created
└── teams/<team_key>/
    ├── skills/  commands/  knowledge/  templates/  memory/
    ├── policy/                       # workflow_policy.json, linear.json, orchestration.json
    ├── decisions/                    # team.yml + per-feature decision logs (boards read them)
    ├── debt/                         # long-lived tech-debt lists (/debt)
    ├── boards.json                   # the team's ticket and decision board URLs
    └── projects/<project_key>/       # that project's task tree
```

```
/init-org                     # first lead, once: create or clone the org repo,
                              # then runs /init-team and /init-project for the first team
/init-team checkout           # later teams: context dirs, policy, prefix (checked against REGISTRY.md)
/init-project checkout web    # each project workspace: inherit policy, render, connect tasks
```

To join: clone the org repo into your code folder, run `install.sh` on your project, then `/init-project <team> <project>` in the workspace.

Context resolves in two layers. The **dotcortex base** (this repo, installed from a release tag) supplies the rendered files and is the same for every team. The **team layer** (`teams/<team>/` in the shared org repo) sits on top; on a filename collision the team file wins and the rebuild reports it. Knowledge added by `/ticket-close` lands in the team layer, so it is available to the next engineer on that team. `/cortex push` opens a PR to move a team asset into the dotcortex base.

Every task and knowledge write is one scoped git transaction: pull, stage only the touched files, commit, push, retry once on rejection. There are no sync modes. An existing flat task repo can be moved into the namespaced layout with `scripts/migrate-task-repo.sh`, which keeps history.

## Multi-Tool

The same `.dotcortex/` content is exposed to OpenAI Codex CLI (`AGENTS.md`, `.agents/skills/`), Gemini CLI (`GEMINI.md`, `.gemini/skills/`), and Cursor (`.cursor/rules/*.mdc`). Tools are chosen during init.

## Knowledge

`/ticket-close` can add gotchas, decisions, and patterns from a closed ticket to the team layer, each with a date and a code reference; most tickets produce none. Manual entries can be added at any time. Facts are committed directly. Rules of the form "always do X" are not stored as knowledge; they are raised as skill or policy change proposals.

`MEMORY.md` is the index. It lists each knowledge file with a one-line "when to read" note, plus a short hot-context list of rules that apply to nearly every session. Agents read the index, then open only the knowledge files relevant to the task; the full knowledge set is never loaded wholesale. In an org, `MEMORY.md` lives in the team layer, so every project on the team shares the same index.

```markdown
# Team Memory

## Knowledge Index

| File | When to read |
|:-----|:-------------|
| `knowledge/api-patterns.md`      | Adding or changing an endpoint |
| `knowledge/data-model.md`        | Migrations, schema changes, query performance |
| `knowledge/patterns-and-gotchas.md` | Debugging, unfamiliar code |
| `knowledge/deferred-scope.md`    | Before proposing new features |

## Hot Context

- Money is integer cents in the API, never floats
- Public API errors are `{ error: "sentence" }` only
- Never mark a ticket done without code evidence
```


## Updating

```bash
/cortex-update
```

Checks out the latest release tag, renders it with your config, and three-way merges each managed file against the version recorded in the manifest. Unmodified files update in place. Modified files merge, or produce a conflict prompt. Generated project content is not touched.

## Safety

- `/cortex-init` on an existing install augments by default. It overwrites only if you choose Replace.
- The view rebuilder does not delete files it did not generate. A user file inside a generated directory stops the rebuild with a message.
- A strict render that cannot resolve every token writes nothing.
- Ticket files are moved to `archive/`, not deleted.

## Project Structure

```
dotcortex/
├── install.sh                # Installs bootstrap commands, engine, and schema into a project
├── bin/
│   ├── render.sh             # Token renderer; writes the managed-files manifest
│   ├── rebuild-views.sh      # Resolves org→team layers; builds .claude and .agents views
│   └── task-tx.sh            # Scoped git transaction (pull, add, commit, push)
├── base/                     # Shipped base, by install profile
│   ├── profiles.json
│   ├── core/  pm/  review/
│   └── packs/                # testing, design, boards, orchestration (opt-in); launch-planning (disabled)
├── commands/                 # Bootstrap and lifecycle commands
├── schemas/config.schema.json
├── scripts/                  # migrate-task-repo.sh, check-debrand.sh, migrate-tasks.sh
└── tests/                    # run-tests.sh (whole suite), boards-test.sh (boards pack, fixtures/boards)
```

## License

MIT + Commons Clause. Free to use, fork, and modify. Cannot be sold or repackaged as a paid product. See [LICENSE](LICENSE).
