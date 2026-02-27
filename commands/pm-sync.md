---
name: pm-sync
description: Sync task state with remote — pull latest changes, push local updates, resolve conflicts
---

# Sync Task State

Push and pull task files to keep team members in sync.

## Process

### Step 1: Determine task storage mode

Read `.claude/.dotcortex.json` and check `config.task_storage`:
- **same_repo:** Tasks are in TASKS_DIR tracked in the project repo. Sync = git add/commit/pull/push on the project repo, scoped to task files only.
- **separate_repo:** Tasks are in TASKS_DIR with its own `.git`. Sync = git pull/push inside that directory.
- **solo/gitignored:** No sync needed. Tell user and exit.

### Step 2: Pull latest

```bash
# For separate repo:
cd TASKS_DIR && git pull --rebase origin main

# For same repo (pull just to check for remote changes):
git fetch origin
git diff HEAD..origin/main -- TASKS_DIR/
```

**If pull conflicts occur:**

For `.ticket_counter`:
- Always take the HIGHER number. This prevents ticket ID collisions.
```bash
# Read both values, take max
LOCAL=$(cat TASKS_DIR/.ticket_counter)
# After merge conflict, check the incoming value
REMOTE=$(git show origin/main:TASKS_DIR/.ticket_counter)
echo $(( LOCAL > REMOTE ? LOCAL : REMOTE )) > TASKS_DIR/.ticket_counter
```

For `BACKLOG.md`:
- Don't try to merge — regenerate it by running the backlog-cleanup skill logic.
- Scan all current tickets and rebuild from scratch.

For individual ticket files (PREFIX-XXX-*.md):
- Show both versions to the user
- Ask: "Keep local / Take remote / Show diff"
- These conflicts mean two people edited the same ticket — rare but important to handle carefully.

### Step 3: Stage and push local changes

```bash
# For separate repo:
cd TASKS_DIR
git add -A
git commit -m "sync: update task state"
git push origin main

# For same repo:
git add TASKS_DIR/
git commit -m "sync: update task state"
git push
```

### Step 4: Report

```
Task sync complete.

Pulled:
  ↓ PREFIX-045-new-feature.md (created by teammate)
  ↓ PREFIX-032-api-refactor.md (status changed: TODO → IN_PROGRESS)

Pushed:
  ↑ PREFIX-048-auth-flow.md (created this session)
  ↑ PREFIX-032-api-refactor.md (marked DONE)

Conflicts resolved:
  ⚠ PREFIX-041-search.md — kept local version

Counter: synced to 49 (took higher value)
Backlog: regenerated from current ticket state
```

## Auto-Sync Modes

This command runs manually when team sync is set to "Manual."

For other sync modes, the pm-agent skill handles sync automatically:

- **Auto on mutation:** Calls sync logic before reads and after writes
- **Session bookends:** Calls sync at session start and end

This command can always be run manually regardless of sync mode.

Arguments: $ARGUMENTS
