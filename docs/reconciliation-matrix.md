# W3.0 Reconciliation Matrix

The spec for the shipped base (`base/`). Each row: source(s) → target, behaviors retained, frozen-contract adaptations, what's removed. Sources in `sources/` are faithful extractions (stale behaviors included); this matrix is where those get fixed. Token contract: `{{TICKET_PREFIX}}`, `{{TASKS_DIR}}`, `{{PROJECT_NAME}}`, `{{COMPONENT_REPOS}}`, `{{REVIEWER_CLI}}`, `{{REVIEWER_MODEL}}`, `{{COORDINATOR_CLI}}`, `{{COORDINATOR_MODEL}}`.

## Base layout + profiles

```
base/
  profiles.json                  # profile -> path prefixes
  core/    commands/commit.md ; scaffolds/CLAUDE.md.template, MEMORY.md.template
  pm/      commands/* ; skills/{pm-agent,todo-queue,backlog-validation,feature-planning,thinking-modes}/ ; templates/*
  review/  commands/{fix,implement-review}.md
  packs/
    testing/skills/testing-automation/
    design/{commands/design-implement.md, skills/design-implement/}
    launch-planning/             # future optional pack, shipped disabled
```

Install flow: `cortex-init` assembles a staging tree from the selected profiles' subtrees (the pipeline runs for EVERY install; the profile set varies — `core` is always included, `pm` only for full PM), then `bin/render.sh --source staging --dest .dotcortex/layers/org --strict`, then `bin/rebuild-views.sh`. Bootstrap commands (`commands/cortex-init.md`, `commands/cortex-update.md`) stay top-level **in this repo** — `install.sh` copies them before any render exists. **In an installed project**, they live in `.dotcortex/commands/` pre-init and are migrated into `.dotcortex/layers/org/commands/` by init so the resolved view can own the directory; post-init installer re-runs target the layer directly.

## The Linear block (canonical wording, used by every command that touches status)

> **Linear:** If the Linear MCP is available in this session, <action — e.g. create the issue first and use its identifier / update the issue status>. If the project config enables Linear (`config.linear.enabled`) but the MCP is not connected, pause and ask the user to connect it (continue markdown-only only at their explicit word). If Linear is not configured, skip this step silently.

Defined once in `pm-agent/SKILL.md`; commands reference it as "the Linear block".

## PM commands

| Target (base/pm/commands/) | Source | Changes |
|---|---|---|
| ticket-new.md | sources/commands/ticket-new.md | **Fix counter transaction:** creation = pull → create file → counter update → push as one retryable transaction (re-pull + retry with new number on push rejection). **Linear block:** when available, create the Linear issue first; its identifier names the ticket. Keep: letter-subtasks-consume-no-numbers rule, both layouts, templates. |
| ticket-refine.md | sources/commands/ticket-refine.md | **Fix the contradiction:** subtasks created during refinement are LETTER children (`XXXa/b/c`), never new numbers, never counter increments. Keep everything else. |
| next.md | sources/commands/next.md | **Fix queue blindness:** read `TODO.md` (canonical ordered queue) FIRST; recommend its top eligible item; fall back to BACKLOG-based reasoning only when TODO.md is absent/empty. |
| standup.md | sources/commands/standup.md | **Fix root-git assumption:** iterate `git -C <repo> log` over `{{COMPONENT_REPOS}}` (or the workspace root when it IS a git repo — detect) plus the tasks checkout. |
| ticket-close.md | sources/commands/ticket-close.md | Keep: parent-exception protocol, discover-then-update boards (grep), scoped staging (never `git add -A`), knowledge extraction split. **Add:** Linear block (set issue Done). Extraction targets team layer when a team context is connected (W2C wires the helper; reference it conditionally). |
| ticket-breakdown.md | sources/commands/ticket-breakdown.md | Token port; verify letter-children consistency with ticket-refine's fixed rule. |
| pm.md | sources/commands/pm.md | Token port; command index lists the full shipped set (incl. ticket-status/audit/implement, /todo, /fix). |
| pm-sync.md | sources/commands/pm-sync.md | **Rewrite sync core:** immediate scoped transactions (pull → `git add <exact paths>` → commit → push, retry on reject). Delete the `git add -A` path entirely. Bookend/auto-mutation prose reduced to the frozen contract. |
| todo.md | sources/commands/todo.md | Token port, unchanged behavior. |
| backlog.md | commands/backlog.md (upstream) | `PREFIX`/`TASKS_DIR` → `{{...}}` tokens; no behavior change. |
| ticket-status.md | commands/ticket-status.md (upstream) | Token conversion only; it's the claim/release primitive other commands call. |
| ticket-audit.md | commands/ticket-audit.md (upstream) | Token conversion; note overlap: full-audit process — backlog-validation skill stays lightweight (format/consistency), audit depth lives here. |
| implement.md (renamed from ticket-implement post-review — implementing is work, not ticket bookkeeping) | commands/ticket-implement.md (W4-merged) | Token conversion; verify step reads `workflow_policy` (which checks the policy allows). |

## PM skills + templates

| Target | Source | Changes |
|---|---|---|
| skills/pm-agent/SKILL.md | sources/skills/pm-agent/SKILL.md | **Restore Team Sync section**, rewritten for the frozen contract: every task mutation = immediate scoped commit/push; pull before reads; no bookends. Define the canonical Linear block. Keep: relatedness-over-size rule, both guardrails, memory section (assistant-gated), empty knowledge routing table. |
| skills/todo-queue/ | sources/skills/todo-queue/ | Token port incl. `agents/openai.yaml`. Add: queue rows may carry Linear IDs; `/todo sync` refreshes status/assignment from Linear (Linear block), never reorders. |
| skills/backlog-validation/SKILL.md | extracted from sources/skills/backlog-cleanup/SKILL.md | **Lightweight only:** the format spec + board-consistency rule + stats sections. The six-phase audit process is NOT included (upstream `/ticket-audit` owns audit depth). |
| skills/feature-planning/SKILL.md | skills/feature-planning/SKILL.md (upstream) | Token conversion only. |
| skills/thinking-modes/SKILL.md | skills/thinking-modes/SKILL.md (upstream) | Copy as-is (no tokens present). |
| templates/*.md (4) | sources/templates/ | **Full status vocabulary** documented in each: `TODO | IN_PROGRESS | BLOCKED | PLANNING | REVIEW | DONE`. Trailing-newline state normalized to \n-terminated (renderer preserves bytes; sources' missing newlines were an old installer artifact). |

## Review profile

| Target | Source | Changes |
|---|---|---|
| commands/fix.md | sources/commands/fix.md | Port as-is (already tokenized/generic). |
| commands/implement-review.md | sources/commands/implement.md | Renamed to avoid colliding with `/ticket-implement`. Uses the four review tokens; adds the "no second model family → report skipped, never same-model" rule explicitly. |

## Packs

| Target | Source | Changes |
|---|---|---|
| packs/testing/skills/testing-automation/ | sources/skills/testing-automation/SKILL.md | Port as-is. |
| packs/design/ | sources/skills/figma-rn-parity/ + sources/commands/figma-rn.md | **Conversion:** design source = Claude design artifacts materialized in-repo (stable snapshot the ticket references) instead of Figma; BUILD/REFINE modes, ordered parity checklist, findings-then-fixes output all retained; RN target. Command renamed `/design-implement`. |
| packs/launch-planning/ | sources/launch-planning/ | Copied as-is; profiles.json marks it `"enabled": false` (future pack; /mvp + /mvp-execute consolidation noted, deferred). |

## Core

| Target | Source | Changes |
|---|---|---|
| core/commands/commit.md | sources/commands/commit.md | Port; repo map from `{{COMPONENT_REPOS}}`/CLAUDE.md; keep zsh paren-quoting + nested-repo rules; unversioned co-author trailer. |
| core/scaffolds/CLAUDE.md.template | scaffolds/CLAUDE.md.template (upstream) | **Marker blocks:** each generated section wrapped in `<!-- BEGIN DOTCORTEX:<ID> -->` / `<!-- END DOTCORTEX:<ID> -->` with stable IDs (`RULES`, `WORKFLOW_POLICY`, `TICKETS`, `CONTEXT_LAYOUT`, `ROUTING`). The `WORKFLOW_POLICY` block renders from `config.workflow_policy`. Content outside markers is user-owned, byte-preserved. |
| core/scaffolds/MEMORY.md.template | scaffolds/MEMORY.md.template (upstream) | Unchanged structure. |

## Config schema (workflow_policy + review + linear)

`schemas/config.schema.json` validates: `prefix`, `tasks_dir`, `project_name`, `component_repos`, `workflow_policy` (test_authoring: allowed|ask; test_execution/server_lifecycle/endpoint_probing: allowed|ask|user_only; documentation_creation: allowed|ask; ticket_creation: proactive|followups_only|explicit_only; ticket_close: auto|ask), `review` (reviewer_cli/reviewer_model/coordinator_cli/coordinator_model), `linear` (enabled: bool). Policy is team-scoped: inherited from team context when connected; interviewed only at team creation.

## Superseded (removed from repo top level once base/ lands)

`commands/{backlog,next,pm,pm-sync,standup,ticket-*}.md`, `skills/`, `templates/` — replaced by `base/`. Bootstrap `commands/cortex-init.md` + `commands/cortex-update.md` remain. `commands/{cortex-push,cortex-sync,cortex,org}.md` remain top-level for the W2C rewrite.
