# TASK: dotcortex Team Readiness — deterministic core, team distribution, upstream contributions

**Status:** REVIEWED (Codex rounds 1–2, 2026-09-01) — round-2 execution-contract fixes incorporated
**Owner:** Brenden
**Context:** dotcortex (github.com/brendenclerget/dotcortex) is being prepped for adoption by CTO + AI transformation team. Audit of the long-running TCGTrack install (pinned at `72ab6e0`, upstream HEAD `3f3e7bc`) identified upstreamable improvements and structural gaps. Round-1 verdict: generalize the proven separate-task-repo model into a namespaced multi-team system. Round-2 verdict: architecture sound; execution contracts below are now frozen.

---

## Goals

1. Every team member who installs dotcortex gets the **same** skills/commands (deterministic base install).
2. A team shares one **master context repo** (skills/commands/knowledge) that members pull from; changes sync down.
3. Tasks are markdown synced to a **namespaced shared task repo** and attach to Linear tickets via Linear MCP.
4. The best process improvements from six months of real use land upstream, de-branded once at source.

## Guiding constraint — it's markdown in git

This system is markdown files coordinated through git. Git is the transaction engine: pull → edit → scoped commit → push, retry on rejection. That pattern is the **only** concurrency mechanism — no locks beyond it, no sagas, no operation IDs, no outbox machinery except the single pending-sync marker for Linear. Conflicts are rare, git surfaces them, and a human or agent resolves them like any merge. A team's context "setup" is: the repo exists; joining is `git clone` + a config pointer + view rebuild. Reviewers proposing infrastructure beyond this must justify it against this constraint.

## Step 0 — Preparation (before any workstream)

- [x] **This document is the authoritative design.** The historical `docs/design/*` sketches are gitignored local drafts that were never in the remote; they are superseded by the frozen contracts here and will NOT be committed. Any plan reference to them means "consult if locally present; this document wins."
- [x] Extract the donor-install contribution sources into **sanitized source patches / behavior fixtures** committed to the repo (`sources/`), so all later work runs from a clean clone with no machine-specific sibling-path dependency. *(Done — commit `ec3e7b5`, 27 files.)*
- [x] De-brand **once, at source**: org-base assets carry explicit tokens (`{{TICKET_PREFIX}}`, `{{TASKS_DIR}}`, `{{PROJECT_NAME}}`, …). The renderer substitutes tokens; it never "strips" identifiers. **Scope of the rule: donor-project identifiers only** (product/company names, ticket IDs, personal names, machine paths, pinned model versions). Tool-vendor names (Claude, Anthropic, Codex, OpenAI) are allowed — this is tooling built around those products. CI forbidden-token scans run against the **shipped asset manifest only**. *(Done — `scripts/check-debrand.sh` passes on `sources/`; W1's manifest CI gets a stronger case-insensitive denylist + token validation.)*
- [ ] **Review-config schema (recorded so W3's builder doesn't invent it):** the cross-model review flow renders from four config values — `review.reviewer_cli`, `review.reviewer_model` (the opposite-family reviewer invocation), `review.coordinator_cli`, `review.coordinator_model` (the coordinating family, used when review runs in the reverse direction). Map to tokens `{{REVIEWER_CLI}}`/`{{REVIEWER_MODEL}}`/`{{COORDINATOR_CLI}}`/`{{COORDINATOR_MODEL}}` in `sources/commands/implement.md`. Lives in gitignored user config per the team-policy/local-executable split.

## Frozen contracts

### Task-repo topology (default, not optional)

```
task-repo/
└── teams/<team_key>/projects/<project_key>/
    ├── .ticket_counter        # pure-markdown mode allocation (transactional; see ID strategy)
    ├── BACKLOG.md
    ├── TODO.md
    ├── archive/YYYY-MM/
    └── <ticket files and families>

# templates/ moved OUT of the task repo — templates are behavior, so they live in the
# org/team context layers and resolve at .dotcortex/templates/.

project checkout:
.dotcortex/task-repo/          # clone of remote
.dotcortex/tasks -> task-repo/teams/<team_key>/projects/<project_key>
.tasks -> .dotcortex/tasks     # compatibility view
```

Existing command paths (`.dotcortex/tasks/...`) keep working unchanged.

### task_repo vs context_repo — separate config concepts

Independent config blocks: task_repo has `url`, `checkout_path`, `branch`, `team_key`, `project_key`; context_repo has `url`, `checkout_path`, `branch`, `team_key` (no project key — projects own no context). May share a remote via distinct top-level trees, but code never assumes it; if co-located, separate worktrees so dirty task files never block context pulls.

### Ticket ID strategy (frozen — no alternatives)

- **Linear mode, online:** create the Linear issue first; its identifier names the top-level markdown ticket.
- **Pure-markdown mode:** ticket creation is one retryable transaction — pull → create file → counter update → push; on push rejection, re-pull and retry with the new counter value.
- **Offline (either mode):** new tasks get provisional `LOCAL-<ULID>` IDs. Reconnection promotes/renames atomically, retaining a `Promoted from:` header line. Existing Linear-backed tasks stay editable offline with status operations queued in the outbox.
- Letter-suffix children (`XXXa/b/c`) are local implementation details; **top-level tickets only** get Linear issues.

### Task-repo mutation = immediate scoped transaction (frozen — bookends are unsafe)

With a shared local checkout, deferred pushes leave dirty files that block other sessions' pull-before-read. Therefore: **every task mutation lands as one scoped commit/push transaction**, batched per command invocation (a `/ticket-close` = one commit), never per-keystroke, never deferred to session end. The transaction script provides pull-before-read, scoped `git add <exact paths>` (never `-A` — upstream `pm-sync.md` line 56 currently uses `git add -A` and would sweep other sessions' work), commit/push, conflict retry, and a local mutation lock (which serializes concurrent mutations but cannot substitute for immediate commits). Per-session task-repo worktrees are a possible later optimization, not part of v1.

### Canonical config, regenerated instruction blocks

One authoritative `config.json`; managed CLAUDE.md/AGENTS.md blocks are rendered from it inside org-base markers. **Marker semantics:** every generated block has a stable marker ID; malformed/missing markers have defined repair behavior (regenerate the block, never touch outside it); content outside markers is preserved byte-for-byte. Evidence this matters: TCGTrack's CLAUDE.md forbids unprompted ticket creation while its AGENTS.md grants it ("create tickets when work is described, no permission needed") — hand-maintained root files drift. Legacy `.claude/.localmem.json` (conflicts with canonical config, confirmed) is deleted on migration and cortex-update stops treating it as a signal.

### Linear field-ownership, failure, and runtime-boundary contract

- Linear owns: status, assignment, priority, top-level issue identity. Git markdown owns: spec, acceptance criteria, work log, letter-children, archive, ordered TODO queue (lanes/gates/collision info — Linear augments, never replaces; queue order wins ordering conflicts).
- Markdown header stores: Linear UUID (immutable), visible identifier, URL, last successful sync.
- **Runtime boundary:** local scripts cannot invoke MCP. The split is: command/skill invokes Linear MCP **through the active agent** → passes the result to a deterministic local script that updates markdown + outbox state → failed writes leave a visible pending-sync marker in the outbox → retry processing is idempotent. Client-specific onboarding detects/configures MCP per tool (Claude Code, Codex).
- Pull never overwrites the markdown body wholesale; Linear-unreachable degrades per the offline ID contract above.

### Context layering (physical filesystem contract — two layers, knowledge rolls up)

Org context: "projects" are small efforts within a domain (checkout, board, rails backend). They must not accumulate private context — learnings roll **up** so future agents inherit them without excavating old projects.

```
.dotcortex/layers/org/{commands,skills,knowledge,templates,policy}/    # the org's dotcortex repo (org-base; installed from a release tag; org forks/curates upstream)
.dotcortex/layers/team/{commands,skills,knowledge,templates,policy,memory}/  # team/domain context repo checkout
.dotcortex/{commands,skills,knowledge,templates,memory}/               # RESOLVED views, generated by rebuild-views.sh
```

- **Two layers only: org → team.** No project layer. Projects hold tasks plus only their own connection config (`config.json`) and generated instruction-marker blocks — no durable behavior or knowledge. **Team assets are additive by preference**: modifying an org-base file goes through an org PR, not a same-name team copy (a shadowing copy would freeze out future org updates). Where a team must temporarily override, the override carries `based_on_org_version` metadata and `/cortex-sync` reports it stale when the org base moves. Net claim: uniform org baseline with *deliberate, visible* team divergence.
- **Knowledge rollup flow:** `ticket-close`'s knowledge-extraction step writes learnings to the **team layer** as a direct low-friction commit using the same git transaction pattern as tasks (pull → scoped commit → push, retry on reject — that's the whole concurrency story). Branch protection permits direct writes to `knowledge/` and `memory/` paths; `skills/`, `commands/`, `templates/`, `policy/` require PR. Team → org promotion via `/cortex-push` PR.
- **Knowledge quality convention** (writing rules, not machinery): each extracted entry carries source ticket, date, and code evidence; MEMORY.md gets only a routing pointer or a genuinely cross-cutting hot-context line — substance goes in the knowledge file. Descriptive facts and verified decisions commit directly; normative rules ("always do X") become a reviewed skill/command/policy proposal instead. On conflict with current code, code wins and the knowledge gets corrected.
- **Close ordering:** the task-repo close commit is authoritative and lands first; knowledge capture and the Linear update follow. If either follow-up fails, it leaves a visible pending marker and is retried — a failed knowledge push never undoes or duplicates an already-valid close.
- **Cross-team contributors:** context binds to the workspace, not the person — anyone cloning a team's workspace gets that team's full context and workflow policy, and their extracted learnings land in the host team's layer. If the contributor lacks write access to the host context repo, extraction falls back to a PR (or a visible pending-extraction marker) instead of failing the close.
- MEMORY.md (index, hot context) is team-scoped and lives in the team layer.
- Existing direct references (`.dotcortex/commands/...`) keep working — they point at resolved views. Org/team same-name collisions are **reported by rebuild-views.sh** (what won, what was shadowed), never silent.

---

## Workstream 1 — Deterministic core

- [ ] `bin/render.sh` — copies org-base assets, substitutes `{{TOKENS}}`, and records per managed file: SHA-256, **base_version (release tag), and source path** — a hash alone detects change but can't reconstruct the merge base; the stored tag lets update retrieve the exact installed base for a true three-way merge. (`managed_files` is `{}` today — the update path is inert.)
- [ ] Installer and updater **check out the exact release tag**, never render arbitrary branch HEAD. Tag releases (`v1.5.0`); unify the three incompatible version fields.
- [ ] `bin/rebuild-views.sh` — single view/layer-resolution engine (see layering contract); init/update/sync/org all call it.
- [ ] Fix `install.sh` re-run bug (deletes canonical `cortex-init.md` through the directory symlink — reproduced).
- [ ] Renderer byte-preservation regression test (trailing newlines currently stripped).
- [ ] **W3.0 base content refresh lands here** — the render pipeline's first payload is the reconciled base set + workflow policy, so determinism ships with the good content.

## Workstream 2A — Namespaced remote task repo (no Linear yet)

- [ ] Implement frozen topology + transaction script.
- [ ] **Migration from the TCGTrack layout** (repo root = project task dir) to `teams/<team>/projects/<project>/`: history-preserving, compat symlink update, rollback path, second-user clone validation. **TCGTrack is the rollout canary** — its heavily dirty task checkout is exactly the condition the transaction contract must survive.
- [ ] `team_sync` for the git-markdown layer reduces to: task mutations = immediate scoped transactions (frozen above); `auto_mutation`-style pull-before-read everywhere. Pure-markdown teams get the same contract — git is the sole coordination source. Restore pm-agent's Team Sync section, rewritten against this contract.
- [ ] Knowledge/memory model: `memory/MEMORY.md`-as-index (repo layout, knowledge routing table, hot context, feedback links) lives in the **team layer** (see layering contract — knowledge rolls up from projects via ticket-close extraction; projects hold no context of their own); Claude native auto-memory = personal per-machine layer; document the split (pm-agent "Cross-Session Memory" section genericized, gated on assistant memory support). CLAUDE.md keeps a mandatory pointer + minimal universal guardrails; Hot Context stays in MEMORY.md. **Do not seed new installs with corrective feedback files** — lessons like archive=move belong in the org-base command + rule block + tests, not in a pre-populated "previous agent's mistakes" memory.
- [ ] Resolve `docs/design/migration-existing-installs.md` (abandoned `.dotcortex/project/` wrapper layout).

## Workstream 2C — Team context lifecycle (deliberately thin)

A team's context is a git repo. Setup happens once; joining is clone + pointer + rebuild. Scope:

- [ ] Team context repo scaffold (directory skeleton + policy file) — created once per team.
- [ ] `/context add|sync|remove` (or revised `/org`): add = `git clone` + write config block + rebuild views; sync = `git pull` + rebuild + stale-override report; remove = drop config + rebuild. Nothing more.
- [ ] Knowledge capture = the same scoped-commit git transaction tasks use, pointed at the context checkout (shared helper, not new machinery).
- [ ] `/cortex-push` rewritten as team → org PR promotion.
- [ ] **TCGTrack context migration canary:** classify the existing corpus — generic behavior → org base; domain behavior (rails/RN/pricing skills, knowledge files) → team layer; verified facts → team knowledge; machine/personal content (dev-aliases, model pins) → discarded. Validates the boundary with the corpus that motivated it.

Sequencing: W2C lands after W1 and before the W3.1 task-path items — ticket-close's knowledge-extraction step targets its capture helper.

## Workstream 2B — Linear MCP layer

- [ ] Implement the frozen Linear contract, including the agent-invokes-MCP / script-updates-state boundary and the idempotent outbox.
- [ ] `cortex-init` detects Linear MCP per client; absent → pure-markdown mode.
- [ ] Sync semantics (revised — no bookends): pull before task reads/start; Linear updated immediately for claim/status/assignment; git committed immediately (scoped, per command) for **all** task mutations including spec/work-log edits. PM commands check the Linear flag and skip redundant git status-sync steps.
- [ ] Reconcile with `docs/design/linear-mcp-integration.md`.

## Workstream 3 — Ship the proven working set

### W3.0 — Reconciled base (extraction, not wholesale replacement)

TCGTrack's evolved files are the primary source, but several contain behavior that contradicts the frozen contracts — confirmed: `ticket-new` reads/increments the counter directly; `ticket-refine` increments the counter for subtasks (contradicting ticket-new's own "letter subtasks don't consume numbers" rule); `/next` recommends from BACKLOG and ignores the canonical TODO queue; `/standup` assumes the workspace root is a git repo (TCGTrack's isn't). Wholesale replacement would ship these bugs.

- [ ] **Per-file reconciliation matrix** (the W3.0 deliverable): for each base file — behaviors to retain, frozen-contract adaptations (ID transaction, scoped commits, TODO-queue awareness, multi-repo git), project content to remove, target layer + profile, acceptance test. Include: ticket templates must document the full canonical status vocabulary (TODO | IN_PROGRESS | BLOCKED | PLANNING | REVIEW | DONE — templates currently list only three).
- [ ] **Install profiles (shipped-base manifest):**
  - **Core:** cortex-init/update/sync, commit, rebuild-views, instruction templates, marker machinery.
  - **PM:** pm-agent, all ticket commands (new/refine/breakdown/close/implement/status/audit), `/next`, `/standup`, `/pm`, `/pm-sync` (rewritten on the transaction script), `/todo` + todo-queue, templates, **lightweight backlog validation** (format + consistency checks — the system depends on backlog regeneration even though the full backlog-cleanup audit is excluded).
  - **Review:** `/fix`, optional cross-model implementation review.
  - **Opt-in packs:** testing-automation (Maestro), `/design-implement`.
- [ ] **CLAUDE.md base rule blocks** as rendered marker sections: Git Safety (as-is), ticket conventions (archive=move, relatedness rule, status-line endings, completion steps), context layout, read-context-first mandate + fillable routing table, quick-start slot.
- [ ] **Workflow policy (replaces hardcoded rules; keeps existing `git_autonomy` for commit/push):**
  ```json
  "workflow_policy": {
    "test_authoring":          "allowed | ask",
    "test_execution":          "allowed | ask | user_only",
    "server_lifecycle":        "allowed | ask | user_only",
    "endpoint_probing":        "allowed | ask | user_only",
    "documentation_creation":  "allowed | ask",
    "ticket_creation":         "proactive | followups_only | explicit_only",
    "ticket_close":            "auto | ask"
  }
  ```
  **Policy is team-scoped behavior**: it lives in the team context repo (`layers/team/policy/`) and a project connecting to a team **inherits** it — init renders it locally, no per-project interview. The interview runs only when creating a team context (or when someone with authority edits it). Values are single resolved tokens validated by a JSON Schema (the `a | b` notation above lists alternatives, not values). Authoring vs execution are distinct on purpose (TCGTrack: agent may write specs but never run them). TCGTrack's values (`test_execution/server_lifecycle/endpoint_probing: user_only`, `ticket_creation: followups_only`, `ticket_close: auto`) become one preset. This also resolves the confirmed CLAUDE.md/AGENTS.md ticket-creation contradiction — both render from one field.

### W3.1 — Individual contributions

All flow through Step-0 sanitized patches and render tokens. Task-path items (1, 3, 4, 5) target the W2A transaction API and land after it; 6–8 are independent.

| # | Contribution | Notes |
|---|---|---|
| 1 | `/fix` — verify-before-fix loop | External findings → verify vs tree (CONFIRMED/STALE/REJECTED/NEEDS-USER) → non-overlapping lanes → disposition table. |
| 2 | Adversarial cross-model review stage | Packet format + fixed verdict contract + dispatch-once. Team context defines policy/contract; gitignored user config defines CLIs/models. No second model family → **report skipped, never silently same-model**. |
| 3 | `/todo` + todo-queue | Ordered queue w/ lanes/gates/collision rules; Linear-backed IDs in Linear mode; `agents/openai.yaml` sidecar convention. |
| 4 | `ticket-close` extensions | Parent-with-open-children exception protocol; discover-then-update board semantics; scoped staging (feeds transaction script). |
| 5 | pm-agent rule upgrades | Relatedness-over-size follow-up rule + both guardrails (no early parent archive; prefer un-archive over new number). |
| 6 | Maestro testing-automation skill | Selector ladder, runner boundary, test-layer split, iOS device lessons as generic appendix. |
| 7 | `/design-implement` (new) | figma-rn-parity workflow retargeted to Claude design source, RN target. Design inputs materialize as a stable in-repo artifact the ticket references; artifact format (HTML/screenshots/metadata/bundle) specified later. |
| 8 | Small fixes | zsh paren-glob quoting gotcha in commit.md; newline preservation covered by W1 test. |

**Excluded from base:** framework/tech skills; knowledge-taxonomy scaffolds; full backlog-cleanup audit (lightweight validation ships instead; upstream `/ticket-audit` overlaps); Figma-specific skills as-is; TCGTrack regressions (pm.md backlog deletion, Team Sync deletion, model pins, repo lists). **Tracked as a later optional pack, not discarded:** launch-planning kit (`/mvp`, `/mvp-execute`, mvp-agent, execution-lane logic) — reusable launch-readiness kernel, currently too product-specific. When the pack lands, consolidate `/mvp` (status/scope report) and `/mvp-execute` (parallel-lane sequencing board) into one command with modes — they share the backlog read and a critical-path table.

## Workstream 4 — Deliberate merges (upstream moved too)

- [x] `ticket-implement.md` collision: merged — upstream's status-gate flow (Steps 1–5) kept intact; grafted Step 6 plan-reconciliation (scope corrections vs user-owned scope changes), dirty-file untouchability, zero-overlap lane guidance for subagent dispatch, honest AC table in the report, terminal status REVIEW never DONE. Verify step now defers to workflow policy (rendered in W3.0).
- [x] Upstream's post-install fixes: satisfied by construction — the branch builds on HEAD `3f3e7bc`, which already contains the config-path migration, `/ticket-status`, and `/ticket-audit`. (`/ticket-audit` vs backlog-cleanup overlap is checked in W3.0 as planned.)
- [x] `.localmem.json` removed from cortex-update's legacy-marker list; canonical `config.json` declared sole authority when present; migration deletes stale marker files after writing config.

## Acceptance test (release gate)

**Cross-machine:** two clean machines install the same tagged version, byte-identical vendor trees → same task repo, same team/project namespace → concurrent task creation with no ID collision → each sees the other's queue/status changes → scoped-commit closes → push-conflict recovery → full offline operation when Linear is unavailable (provisional IDs, outbox drain on reconnect).
**Same-machine:** two parallel local sessions edit different tickets — lock contention resolves, dirty-file isolation holds, an interrupted transaction recovers cleanly.
**Layering:** org/team same-name collision is reported and resolves in precedence order (team wins).
**Rollup:** closing a ticket with extracted learnings lands them in the team layer; a second machine sees them after context pull without reading the source project. Two machines closing different tickets that touch the same knowledge file → both entries survive (git merge). A context push that fails after a task close leaves a pending marker; retry yields exactly one knowledge entry and one MEMORY pointer.
**Canary:** TCGTrack's migration to the namespaced layout.

## Execution order

0. **Step 0** — commit ADRs/designs; sanitized source patches/fixtures; de-brand at source.
1. Freeze contracts (done — this document).
2. **W4** — reconcile upstream baseline with TCGTrack improvements.
3. **W1** — render + views + versioning + installer fixes + tests, carrying the **W3.0 reconciled base** as first payload.
4. **W2A** — namespaced task repo, transaction script, migration canary.
5. **W2C** — team context lifecycle (thin) + context migration canary.
6. **W3.1** task-path items (1, 3, 4, 5) on the transaction + capture APIs.
7. **W2B** — Linear layer.
7. **W3.1** independent items (6, 7, 8); later: launch-planning pack.

## Review log

- **2026-09-01, Codex round 1:** CONDITIONAL GO. 10/10 blocking accepted (topology default, config split, migration canary, ID strategy, transaction scripts, canonical config, Linear contract, precedence inversion, reordering, acceptance test). Citation correction: config conflict was two-way (config.json vs .localmem.json), not three-way — CLAUDE.md has no session-end push rule.
- **2026-09-01, Codex round 2:** CONDITIONAL GO. 9/9 blocking accepted: layers filesystem contract; extraction-not-replacement with reconciliation matrix (all four stale-behavior citations verified, incl. ticket-refine contradicting ticket-new on subtask numbering); install-profile manifests + lightweight backlog validation; finer workflow_policy (authoring vs execution split, ticket_creation field resolving the verified CLAUDE.md/AGENTS.md contradiction) keeping git_autonomy; immediate-scoped-transaction contract replacing session bookends; frozen ID/offline behavior (LOCAL-ULID promotion); true three-way merge via stored base_version + tag checkout; agent-invokes-MCP runtime boundary; Step-0 source sanitization with token-based de-branding. Non-blocking 1–6 accepted (same-machine acceptance tests, launch-planning pack tracked, no seeded feedback memories, scoped de-brand CI, marker semantics, deferred design-artifact format). One citation note: ticket-implement.md:69 doesn't show the test-authoring distinction claimed, but the policy split is correct and adopted.
- **2026-09-01, Codex round 3:** CONDITIONAL GO. Accepted, mostly simplified per the new "it's markdown in git" guiding constraint: counter restored to topology + templates moved to context layers (B1); thin W2C context lifecycle + `/cortex-push` team→org + context migration canary (B2, NB2); knowledge writes reuse the task git-transaction pattern with path-level branch protection — no locks/dedupe engine (B3, simplified); close ordering task→knowledge→Linear with retry-on-pending — **saga/outbox/operation-ID machinery rejected** as over-engineering (B4, principle kept, apparatus dropped); knowledge quality convention as writing rules not machinery (B5); additive-preferred team assets with `based_on_org_version` escape hatch, claim restated as "uniform baseline, deliberate divergence" (B6); workflow policy team-scoped + inherited at project connect + JSON Schema (B7); layer-path leftovers fixed — templates/memory/policy paths, context project_key dropped, stale phasing sentences removed, vendor→org-base rename (B8, NB4); concurrent/failed-rollup acceptance lines (B9); projects-hold-tasks clarified to include config + markers (NB1); MEMORY-as-pointer convention (NB3).
- **2026-09-01, owner revision (post round 2):** layering simplified from vendor→team→project to **org→team**; vendor layer = the org's curated dotcortex repo; project-level context eliminated — projects are small in-domain efforts holding tasks only; knowledge rolls up to the team layer via ticket-close extraction (direct commit), team→org via `/cortex-push` PR; skills/commands changes reviewed at both levels; MEMORY.md is team-scoped.
