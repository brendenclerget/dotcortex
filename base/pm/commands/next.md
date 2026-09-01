---
name: next
description: Analyze open tickets and recommend what to work on next
---

# What Should I Work On Next?

Recommend what to tackle next. `{{TASKS_DIR}}/TODO.md` is the canonical ordered queue —
it is the answer when it exists. Backlog reasoning is the fallback, not the default.

## Process

1. **Read `{{TASKS_DIR}}/TODO.md` FIRST.** If it exists and has items, the recommendation
   is its **top eligible item** — the highest item in queue order that is not blocked, not
   claimed by another session, and whose gates/dependencies are satisfied. Queue order wins
   over your own ranking; do not reorder it here (`/todo` owns ordering).
   - Read the recommended item's ticket file for scope and current state
   - Note anything skipped and why (blocked / claimed / gate unmet) — skipping must be
     explained, never silent
   - If the queue's top items are all ineligible, say so and then fall through to step 2

2. **Fallback — only when TODO.md is absent or empty:** reason from the backlog.
   - Read `{{TASKS_DIR}}/BACKLOG.md`
   - Read each HIGH priority ticket to understand scope, dependencies, and current state
   - Check for IN_PROGRESS work — anything already started should be finished first
   - Check orphaned subtasks — quick wins that close out completed features
   - Say explicitly that you fell back because there was no queue

## Analysis Criteria

Used to rank fallback candidates, and to judge eligibility within the queue:

| Factor | Weight | Description |
|--------|--------|-------------|
| **In-progress work** | Highest | Finish what's started before starting new |
| **Unblocks other work** | High | Infrastructure/prereqs that enable future tickets |
| **User-facing impact** | High | Features users will notice immediately |
| **Effort vs payoff** | Medium | Quick wins > large uncertain efforts |
| **Technical debt risk** | Medium | Things that get harder the longer you wait |
| **Dependencies** | Medium | Prefer tickets with no blockers |

## Output Format

Respond with:

### Next Up
The top eligible TODO.md item (or, in fallback mode, your #1 pick — labeled as a fallback
recommendation). One sentence on why it's the pick, plus anything skipped above it and why.

### Resume First (if any)
Tickets already IN_PROGRESS that should be finished before starting new work.

### Top 3 Recommendations
For each, include:
1. **{{TICKET_PREFIX}}-XXX: Title** — 1-sentence why this is the pick
2. Estimated size (small / medium / large)
3. What it unblocks or enables

### Quick Wins
Any orphaned subtasks or small items that could be knocked out in < 1 hour.

### Not Yet
Anything that looks tempting but should wait, and why.

Keep the whole response concise — this is a decision aid, not a report.

Arguments: $ARGUMENTS
