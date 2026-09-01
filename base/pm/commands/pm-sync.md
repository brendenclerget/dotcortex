---
name: pm-sync
description: Sync task state with remote — pull latest changes, push local updates, resolve conflicts
---

# Sync Task State

Push and pull task files to keep team members in sync.

## The sync contract (one contract, no modes)

Task state is markdown coordinated through git, and git is the transaction engine. Every
task mutation — from any command, this one included — lands as **one scoped transaction**:

1. **Pull before you read.** Never reason about task state you haven't refreshed.
2. **Stage exactly what you touched:** `git add <exact paths>`. Never `git add -A`, never
   `git add <tasks-dir>/` wholesale — parallel sessions leave unrelated dirty files in this
   checkout and a broad stage sweeps their work into your commit.
3. **Commit and push immediately.** Batched per command invocation (a `/ticket-close` is one
   commit), never per-keystroke, never deferred to the end of a session. A deferred push
   leaves dirty files that block every other session's pull-before-read.
4. **On push rejection:** `git pull --rebase`, resolve per the rules below, and retry **once**.
   If the retry is also rejected, stop and report — don't loop.

There is no bookend mode and no separate auto-mutation mode. Teams running pure markdown
(no issue tracker) use this same contract — git is the sole coordination mechanism.

This command is the manual entry point to that contract: refresh from the remote, land any
task changes sitting locally, and report what moved.

## Process

### Step 1: Determine task storage mode

Read `.dotcortex/config.json` and check `config.task_storage`:
- **same_repo:** Tasks are in `{{TASKS_DIR}}/` tracked in the project repo. Sync = the
  transaction above, run on the project repo, scoped to task files only.
- **separate_repo:** Tasks are in `{{TASKS_DIR}}/` with its own `.git`. Sync = the
  transaction above, run inside that directory.
- **solo/gitignored:** No sync needed. Tell user and exit.

### Step 2: Pull latest

```bash
# Separate repo:
cd {{TASKS_DIR}} && git pull --rebase origin main

# Same repo:
git pull --rebase origin main
```

**If pull conflicts occur:**

For `.ticket_counter`:
- Always take the HIGHER number. This prevents ticket ID collisions.
```bash
# Read both values, take max
LOCAL=$(cat {{TASKS_DIR}}/.ticket_counter)
# After merge conflict, check the incoming value
REMOTE=$(git show origin/main:{{TASKS_DIR}}/.ticket_counter)
echo $(( LOCAL > REMOTE ? LOCAL : REMOTE )) > {{TASKS_DIR}}/.ticket_counter
```

For `BACKLOG.md`:
- Don't try to merge — regenerate it from current ticket state per the backlog-validation
  skill's format and categorization rules.

For individual ticket files ({{TICKET_PREFIX}}-XXX-*.md):
- Show both versions to the user
- Ask: "Keep local / Take remote / Show diff"
- These conflicts mean two people edited the same ticket — rare but important to handle carefully.

### Step 3: Stage and push local changes

Identify exactly which task files changed in this session (`git status --porcelain`), and
stage **only those paths**. Files dirtied by other sessions stay untouched — they are not
yours to commit.

```bash
# Separate repo:
cd {{TASKS_DIR}}
git add <exact paths you changed>
git commit -m "sync: update task state"
git push origin main

# Same repo:
git add {{TASKS_DIR}}/<exact paths you changed>
git commit -m "sync: update task state"
git push
```

If the push is rejected, `git pull --rebase` and retry the push once. If it fails again,
report the rejection and the conflicting paths rather than retrying further.

### Step 4: Report

```
Task sync complete.

Pulled:
  ↓ {{TICKET_PREFIX}}-045-new-feature.md (created by teammate)
  ↓ {{TICKET_PREFIX}}-032-api-refactor.md (status changed: TODO → IN_PROGRESS)

Pushed:
  ↑ {{TICKET_PREFIX}}-048-auth-flow.md (created this session)
  ↑ {{TICKET_PREFIX}}-032-api-refactor.md (marked DONE)

Conflicts resolved:
  ⚠ {{TICKET_PREFIX}}-041-search.md — kept local version

Left dirty (other sessions, not staged):
  · {{TICKET_PREFIX}}-050-import.md

Counter: synced to 49 (took higher value)
Backlog: regenerated from current ticket state
```

Arguments: $ARGUMENTS
