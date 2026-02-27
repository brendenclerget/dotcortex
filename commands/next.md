---
name: next
description: Analyze open tickets and recommend what to work on next
---

# What Should I Work On Next?

Review the full backlog and open tickets, then give a focused recommendation on what to tackle next.

## Process

1. **Read the backlog:** `TASKS_DIR/BACKLOG.md`
2. **Read each HIGH priority ticket** to understand scope, dependencies, and current state
3. **Check for IN_PROGRESS work** — anything already started should be finished first
4. **Check orphaned subtasks** — quick wins that close out completed features

## Analysis Criteria

Rank candidates by weighing these factors:

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

### Resume First (if any)
Tickets already IN_PROGRESS that should be finished before starting new work.

### Top 3 Recommendations
For each, include:
1. **PREFIX-XXX: Title** — 1-sentence why this is the pick
2. Estimated size (small / medium / large)
3. What it unblocks or enables

### Quick Wins
Any orphaned subtasks or small items that could be knocked out in < 1 hour.

### Not Yet
Anything that looks tempting but should wait, and why.

Keep the whole response concise — this is a decision aid, not a report.

Arguments: $ARGUMENTS
