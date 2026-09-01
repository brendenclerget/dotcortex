---
name: backlog-cleanup
description: Backlog structure, categorization rules, and the full open-ticket audit/re-rank process. Auto-invokes when discussing backlog cleanup, prioritization, ticket triage, or a full backlog audit.
---

# Backlog Cleanup

Two modes:
1. **Format/sync mode** — keep `{{TASKS_DIR}}/BACKLOG.md` structured and in sync during normal ticket mutations (the original spec, below).
2. **Full audit mode** — a complete audit + re-ranking of every open ticket against git reality. Run when asked for a "complete audit", "re-rank the backlog", or when boards have visibly drifted. Process defined in "Full Audit Process".

## Auto-Invoke Triggers

- "clean up backlog", "regenerate backlog", "update backlog"
- "prioritize tickets", "triage tickets", "audit tickets", "re-rank tickets"
- "what's in the backlog"

---

# Full Audit Process

Goal: nothing sits open that is actually done; every open ticket has an honest status and rank; all boards agree.

## Phase 0 — Load the rules first

Read `skills/pm-agent/SKILL.md` (closure process, follow-up rules, guardrails) before any transition. Honor the standing memories: no unprompted new tickets, subtasks-not-new-tickets, parents never close/archive with open children.

## Phase 1 — Inventory

- List open tickets: `find {{TASKS_DIR}} -name "{{TICKET_PREFIX}}-*" -not -path "*/archive/*" -not -path "*/templates/*"`. Exclude `docs/`, `summaries/`, `knowledge/`, `DECISIONS/`, and companion docs (`*-prompt.md`, memos) — they are not tickets.
- Read `.ticket_counter` and every board file: `BACKLOG.md`, `TODO.md`, `MVP_BACKLOG.md`.

## Phase 2 — Git evidence sweep

- `git -C <repo> log --oneline --since="<~4 weeks ago>" --date=short --pretty="%ad %h %s"` for every code repo ({{COMPONENT_REPOS}}) plus the tasks repo itself (`{{TASKS_DIR}}`).
- The tasks-repo log is the closure ledger — it reveals out-of-band closes, reopens, and renumbers that the boards may have missed.

## Phase 3 — Per-ticket verification (fan out in slices)

Split the open set into ~25-ticket slices by ID range and audit each slice in parallel subagents (read-only). **Spawn all subagents in this process — audit slices here and the closure executor in Phase 4 — with your most capable model.** For every ticket file:
1. Read the actual Status field, priority, last work-log entries, acceptance criteria.
2. Search git for the ID: `git -C <repo> log --oneline --all --grep "{{TICKET_PREFIX}}-XXX"` across repos. Beware false-positive grep hits from other IDs in a commit body.
3. Check `archive/` for same-ID collisions and superseding closed tickets.
4. Assign a verdict:
   - **DONE-CLOSE** — acceptance criteria met by named commits; close.
   - **SUPERSEDED-CLOSE** — premise dead or scope delivered by other shipped work; close naming the superseder. Any *residual live scope* must be re-homed into an open ticket (with a cross-note in that ticket) before closing.
   - **VERIFY-WITH-USER** — engineering done but gated on a user action (device pass, prod go-ahead, semantics check). Do NOT close; list in "In Review — Awaiting user".
   - **RESCOPE** — partially delivered or stale premise; annotate the ticket (`**Audit YYYY-MM-DD:** ...`) with what shipped and what remains.
   - **KEEP** — genuinely open; assign HIGH/MEDIUM/LOW/DEFERRED.

**Verification principles:** git is truth — never close on a board note or commit message alone; walk acceptance criteria against code/schema where feasible (e.g. confirm a skipped test still exists before keeping a bug ticket, confirm a table exists before closing a schema ticket). Supersession requires naming the shipped work that replaced it. When in doubt, VERIFY-WITH-USER, not close.

## Phase 4 — Execute closures (pm-agent rules exactly)

Delegate the mechanical closure work to a subagent with explicit per-ticket instructions; the coordinator keeps the boards. For each close: edit status + dated closure note with evidence → `mv` to `archive/YYYY-MM/` (whole folder for full families; single files for children of still-open parents). Never delete; never close a parent with open children; write a summation on closed parents. Add re-homing cross-notes to the receiving open tickets. Do not commit the tasks repo unless asked.

## Phase 5 — Re-rank and rewrite every board

- **BACKLOG.md** — full regeneration per the format spec below; refresh Stats (including the real `.ticket_counter` value) and append a dated Housekeeping entry summarizing the pass.
- **TODO.md** — the ordered execution queue: remove closed rows, flip gates that cleared (WAITING→READY), keep the user's explicitly-set ordering unless evidence invalidates it, append a Log entry.
- **MVP_BACKLOG.md** — true up per-row statuses (closed/superseded/reopened), Last Updated, and Stats. Watch for rows that went stale in *both* directions (listed TODO but closed; listed DONE but reopened).

## Phase 6 — Report

Closed list (with evidence), verify-with-user list, re-scopes, ranking changes, before/after open-ticket counts, and any inconsistencies found (ID collisions, log-vs-filesystem drift, counter mismatches).

**Root cause of drift, for the record:** tickets closed out-of-band by parallel sessions without `/ticket-close` (whose final step updates every board). Consistent `/ticket-close` use prevents most of what this audit finds.

---

# Backlog Format Spec

Defines how `{{TASKS_DIR}}/BACKLOG.md` should be structured. Used by the `/backlog` command and whenever backlog updates happen during ticket mutations.

## Output Format

```markdown
# {{PROJECT_NAME}} Backlog

**Last Updated:** YYYY-MM-DD

---

## In Review — Awaiting user (verify / approve, no build left)
Engineering done; closes on a user device pass or prod go-ahead.
Table: Ticket | Title | Status | Waiting On

## Active Work
Table: Ticket | Title | Status | Notes

## Paused Work (Resume Later)
Feature tracks that are mid-flight but intentionally paused.
Table: Ticket | Title | Status | Notes

## Ready to Work — HIGH Priority
Standalone items ready to pick up now, not blocked by paused work.
Table: Ticket | Title | Type | Subtasks | Notes

## Blocked / Prerequisites
Items that unlock paused work when completed.
Table: Ticket | Title | Type | Subtasks | Notes

## Medium Priority
Table: Ticket | Title | Type | Notes

## Low Priority / Long-Term
Table: Ticket | Title | Type

## Orphaned Subtasks
Subtasks with archived parents — decide to keep or archive.
Table: Ticket | Parent | Title

## Housekeeping log
Dated entries for each cleanup/audit pass (what closed, what moved, counts).

## Stats
Summary counts by category + current ticket counter.
```

## Categorization Rules

- **In Review:** engineering complete and merged; blocked only on user verification/go-ahead
- **Active:** genuinely being worked this window
- **Paused:** Status is IN_PROGRESS or PLANNING but the user has explicitly paused the work track
- **Ready to Work:** HIGH priority, Status TODO or BACKLOG, not a subtask of paused work
- **Blocked / Prerequisites:** HIGH priority items that are dependencies for paused feature tracks
- **Medium:** MEDIUM priority top-level tickets
- **Low:** LOW priority, DEFERRED tracks, or pure backlog ideas
- **Orphaned:** Subtask folder exists but parent is in `archive/`

## Display Rules

- Only list top-level tickets in the main tables. Mention subtask count + IDs inline.
- Subtasks are tracked within their parent ticket, not individually in the backlog.
- Keep Notes column concise — 1 short sentence max.

## Board consistency rule

`BACKLOG.md` (full prioritized view), `TODO.md` (ordered next-work queue), and `MVP_BACKLOG.md` (launch board) must never disagree about a ticket's open/closed state. Any ticket mutation updates every board file that lists it, in the same session.
