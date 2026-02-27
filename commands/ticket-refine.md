---
name: ticket-refine
description: Review ticket progress, update status based on actual work, create subtasks for remaining work
argument-hint: PREFIX-XXX
---

# Refine Ticket Based on Actual Progress

Analyze ticket $ARGUMENTS and refine it based on actual code/git state.

**Process:**

## 1. Read Current Ticket State
```bash
# Read the ticket file
cat TASKS_DIR/$ARGUMENTS-*.md

# If it's a parent, also read any existing subtasks
ls -la TASKS_DIR/$ARGUMENTS/
```

## 2. Analyze Git History
```bash
# Find branches related to this ticket
git branch -a | grep -i "$ARGUMENTS"

# Check commits on those branches
git log --oneline --all --grep="$ARGUMENTS"

# Check current branch status
git status

# See what's actually been committed
git log --oneline -20
```

## 3. Review Code Changes

For each branch found:
```bash
git diff main...<branch-name> --stat
git diff main...<branch-name> --name-only
```

## 4. Determine What's Actually Done

**Think hard about:**
- What functionality is implemented in the branches?
- What's committed vs what ticket says?
- Are there partial implementations?
- What's been tested vs not tested?

**Look for evidence:**
- Completed files/components
- Passing tests
- Merged branches
- Working features

## 5. Update Parent Ticket

**Refine the main ticket:**
- Update description to reflect current state
- Mark completed acceptance criteria
- Add "Completed Work" section listing what's done
- Add "Remaining Work" section for what's left
- Update technical design notes
- Add git references for completed work

**Example update:**
```markdown
## Progress Summary
**Status:** IN_PROGRESS (60% complete)

### Completed Work
- JWT authentication backend (PREFIX-013, merged)
- Login UI component (PREFIX-014, on branch feature/login-ui)
- Token storage (commits abc123, def456)

### Remaining Work
- Password reset flow
- Session timeout handling
- Error messaging improvements
```

## 6. Create Subtasks for Remaining Work

**For each piece of remaining work:**

1. **Read ticket counter:**
```bash
   cat TASKS_DIR/.ticket_counter
```

2. **Create subtask in PREFIX-XXX/ folder:**
   - One ticket per logical unit of work
   - Include specific acceptance criteria
   - Reference what's already done as context

3. **Update parent ticket with subtask links:**
```markdown
   ### Subtasks
   - [x] PREFIX-013: JWT setup (DONE)
   - [x] PREFIX-014: Login UI (DONE)
   - [ ] PREFIX-015: Password reset flow (TODO)
   - [ ] PREFIX-016: Session timeout (TODO)
```

4. **Increment counter**

## 7. Provide Summary

```markdown
## Ticket Refinement: PREFIX-XXX

### Current State Analysis
- **Overall Progress:** X% complete
- **Branches Found:** feature/login, feature/auth-backend
- **Commits:** 12 related commits

### Completed (verified in git)
1. Backend JWT authentication - merged to main
2. Login form UI - on feature branch, working

### Created Subtasks for Remaining Work
- [ ] PREFIX-015: Password reset flow
- [ ] PREFIX-016: Session timeout handling

### Next Steps
Recommend starting with PREFIX-015 (password reset) as it's independent.
```

## Key Principles

**Be realistic:**
- If code exists but isn't tested, it's not "done"
- If branch isn't merged, it's "in progress"
- If feature is broken, it needs rework (new subtask)

**Base decisions on evidence:**
- Git commits = proof of work
- Merged branches = truly complete
- No commits = not started

**Preserve history:**
- Don't delete completed subtasks
- Mark them done with git references

---

Arguments: $ARGUMENTS
