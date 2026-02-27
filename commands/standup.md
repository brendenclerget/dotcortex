---
name: standup
description: Summarize recent progress from git history and ticket state
---

# Standup

Generate a progress summary based on actual work — git commits and ticket state changes.

## Process

1. **Recent commits:**
```bash
# Last 7 days of commits (adjust with $ARGUMENTS, e.g., "3 days", "today")
git log --oneline --since="7 days ago" --all
```

2. **Ticket state:**
   - Read `TASKS_DIR/BACKLOG.md` for current active work
   - Scan `TASKS_DIR/` for any IN_PROGRESS tickets
   - Check `TASKS_DIR/archive/` for recently archived tickets (this month)

3. **Branch state:**
```bash
git branch --list "feature/*"
git stash list
```

## Output Format

### Shipped
Tickets completed and archived since last standup. Include commit count per ticket.

### In Progress
Tickets currently being worked on. Show what's done vs remaining (from ticket acceptance criteria).

### Open Branches
Feature branches that exist but may not have tickets — flag for cleanup or ticket creation.

### Up Next
Top recommendation from backlog (same logic as `/next` but just the #1 pick, not the full analysis).

## Arguments

- No args: last 7 days
- `today`: just today's work
- `3 days`: last 3 days
- `week`: last 7 days (default)
- `month`: last 30 days

Keep output tight — this is a glance, not a report.

Arguments: $ARGUMENTS
