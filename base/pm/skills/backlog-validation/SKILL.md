---
name: backlog-validation
description: Backlog format spec, board-consistency rules, and stats/counter upkeep. Auto-invokes when discussing backlog structure, regenerating the backlog, or keeping board files in sync during ticket mutations.
---

# Backlog Validation

Keeps `{{TASKS_DIR}}/BACKLOG.md` structured and in sync during normal ticket mutations.

> **Deep auditing lives in `/ticket-audit`.** This skill is deliberately lightweight: format,
> board consistency, stats. The full open-ticket audit and re-ranking process — git evidence
> sweeps, per-ticket verdicts, mass closures — is owned by `/ticket-audit`, not here.

## Auto-Invoke Triggers

- "clean up backlog", "regenerate backlog", "update backlog"
- "what's in the backlog"

---

# Backlog Format Spec

Defines how `{{TASKS_DIR}}/BACKLOG.md` should be structured. Used by the `/backlog` command and
whenever backlog updates happen during ticket mutations.

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

`BACKLOG.md` (full prioritized view), `TODO.md` (ordered next-work queue), and any additional board
file must never disagree about a ticket's open/closed state. **Any ticket mutation updates every
board file that lists the ticket, in the same session** — discover them by grep rather than
assuming a fixed set.

## Stats and counter

The **Stats** section carries summary counts by category plus the current ticket counter. Read the
real value from `{{TASKS_DIR}}/.ticket_counter` — never carry forward a stale number from the
previous version of the file.

## Housekeeping log

Each cleanup or audit pass appends one dated entry to the **Housekeeping log** summarizing what
closed, what moved, and the before/after open-ticket counts. Regenerating `BACKLOG.md` rewrites the
tables; it never drops existing housekeeping entries.
