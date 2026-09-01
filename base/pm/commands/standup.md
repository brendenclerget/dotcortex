---
name: standup
description: Summarize recent progress from git history and ticket state
---

# Standup

Generate a progress summary based on actual work — git commits and ticket state changes.

## Process

1. **Recent commits — across every repo, not just the working directory.**
   The workspace root may or may not be a git repo. Detect, then iterate:

```bash
SINCE="7 days ago"   # adjust from $ARGUMENTS, e.g. "3 days", "today"

# Component repos for this project, plus the tasks checkout
REPOS="{{COMPONENT_REPOS}}"
REPOS="${REPOS//,/ }"

# If the workspace root is itself a git repo, include it (some projects are single-repo)
if git rev-parse --git-dir >/dev/null 2>&1; then
  REPOS=". $REPOS"
fi

for repo in $REPOS {{TASKS_DIR}}; do
  [ -d "$repo" ] || continue
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || continue
  echo "=== $repo ==="
  git -C "$repo" log --oneline --since="$SINCE" --all
done
```

   The tasks checkout matters as much as the code repos — ticket transitions land there
   as commits and are the record of what closed.

2. **Ticket state:**
   - Read `{{TASKS_DIR}}/BACKLOG.md` for current active work
   - Scan `{{TASKS_DIR}}/` for any IN_PROGRESS tickets
   - Check `{{TASKS_DIR}}/archive/` for recently archived tickets (this month)

3. **Branch state — same repo iteration:**
```bash
for repo in $REPOS; do
  [ -d "$repo" ] || continue
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || continue
  echo "=== $repo ==="
  git -C "$repo" branch --list "feature/*"
  git -C "$repo" stash list
done
```

## Output Format

### Shipped
Tickets completed and archived since last standup. Include commit count per ticket.

### In Progress
Tickets currently being worked on. Show what's done vs remaining (from ticket acceptance criteria).

### Open Branches
Feature branches that exist but may not have tickets — flag for cleanup or ticket creation.
Name the repo each branch lives in.

### Up Next
Top recommendation from the queue (same logic as `/next` but just the #1 pick, not the full analysis).

## Arguments

- No args: last 7 days
- `today`: just today's work
- `3 days`: last 3 days
- `week`: last 7 days (default)
- `month`: last 30 days

Keep output tight — this is a glance, not a report.

Arguments: $ARGUMENTS
