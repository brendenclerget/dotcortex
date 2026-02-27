---
name: backlog-cleanup
description: Backlog structure and categorization rules. Auto-invokes when discussing backlog cleanup, prioritization, or ticket triage.
---

# Backlog Format Spec

Defines how `TASKS_DIR/BACKLOG.md` should be structured. Used by the `/backlog` command and whenever backlog updates happen during ticket mutations.

## Auto-Invoke Triggers

- "clean up backlog", "regenerate backlog", "update backlog"
- "prioritize tickets", "triage tickets"
- "what's in the backlog"

## Output Format

```markdown
# Backlog

**Last Updated:** YYYY-MM-DD

---

## Paused Work (Resume Later)
Feature tracks that are mid-flight but intentionally paused.
Table: Ticket | Title | Status | Notes

## Ready to Work — HIGH Priority
Standalone items ready to pick up now, not blocked.
Table: Ticket | Title | Type | Subtasks | Notes

## Blocked / Prerequisites
Items that unlock other work when completed.
Table: Ticket | Title | Type | Subtasks | Notes

## Medium Priority
Table: Ticket | Title | Type | Notes

## Low Priority / Long-Term
Table: Ticket | Title | Type

## Orphaned Subtasks
Subtasks with archived parents — decide to keep or archive.
Table: Ticket | Parent | Title

## Stats
Summary counts by category.
```

## Categorization Rules

- **Paused:** Status is IN_PROGRESS or PLANNING but the user has explicitly paused the work track
- **Ready to Work:** HIGH priority, Status TODO or BACKLOG, not a subtask of paused work
- **Blocked / Prerequisites:** HIGH priority items that are dependencies for other features
- **Medium:** MEDIUM priority top-level tickets
- **Low:** LOW priority or pure backlog ideas
- **Orphaned:** Subtask folder exists but parent is in `archive/`

## Display Rules

- Only list top-level tickets in the main tables. Mention subtask count + IDs inline.
- Subtasks are tracked within their parent ticket, not individually in the backlog.
- Keep Notes column concise — 1 short sentence max.
