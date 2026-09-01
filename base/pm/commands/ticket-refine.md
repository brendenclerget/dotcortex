---
name: ticket-refine
description: Review ticket progress, update status based on actual work, create subtasks for remaining work
argument-hint: {{TICKET_PREFIX}}-XXX
---

# Refine Ticket Based on Actual Progress

Analyze ticket $ARGUMENTS and refine it based on actual code/git state.

**Process:**

## 1. Read Current Ticket State
```bash
# Read the ticket file
cat {{TASKS_DIR}}/$ARGUMENTS-*.md

# If it's a parent, also read any existing subtasks
ls -la {{TASKS_DIR}}/$ARGUMENTS/
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
- JWT authentication backend ({{TICKET_PREFIX}}-013a, merged)
- Login UI component ({{TICKET_PREFIX}}-013b, on branch feature/login-ui)
- Token storage (commits abc123, def456)

### Remaining Work
- Password reset flow
- Session timeout handling
- Error messaging improvements
```

## 6. Create Subtasks for Remaining Work

**Subtasks created here are LETTER CHILDREN of $ARGUMENTS — never new ticket numbers.**
Do not read `.ticket_counter`, do not increment it, and do not create a Linear issue
(top-level tickets only). Refinement never allocates an ID.

**For each piece of remaining work:**

1. **Pick the next free letter suffix** by looking at what already exists:
```bash
   ls {{TASKS_DIR}}/$ARGUMENTS/ 2>/dev/null
   # e.g. if $ARGUMENTS{a,b} exist, the next remaining item is $ARGUMENTS-c
```

2. **Create the child in the {{TICKET_PREFIX}}-XXX/ folder:**
   - `{{TASKS_DIR}}/$ARGUMENTS/$ARGUMENTS<letter>-description.md`
   - If the ticket is still a flat file, create the folder and move the parent into it first
   - One child per logical unit of work
   - Include specific acceptance criteria
   - Reference what's already done as context

3. **Update parent ticket with child links:**
```markdown
   ### Subtasks
   - [x] {{TICKET_PREFIX}}-013a: JWT setup (DONE)
   - [x] {{TICKET_PREFIX}}-013b: Login UI (DONE)
   - [ ] {{TICKET_PREFIX}}-013c: Password reset flow (TODO)
   - [ ] {{TICKET_PREFIX}}-013d: Session timeout (TODO)
```

4. **Commit and push the refinement as one scoped transaction** — pull, `git add` the
   exact parent + child paths (never `-A`), commit, push; on rejection re-pull, re-apply,
   push again. The counter is not part of this commit because refinement never touches it.

## 7. Provide Summary

```markdown
## Ticket Refinement: {{TICKET_PREFIX}}-XXX

### Current State Analysis
- **Overall Progress:** X% complete
- **Branches Found:** feature/login, feature/auth-backend
- **Commits:** 12 related commits

### Completed (verified in git)
1. Backend JWT authentication - merged to main
2. Login form UI - on feature branch, working

### Created Subtasks for Remaining Work
- [ ] {{TICKET_PREFIX}}-013c: Password reset flow
- [ ] {{TICKET_PREFIX}}-013d: Session timeout handling

### Next Steps
Recommend starting with {{TICKET_PREFIX}}-013c (password reset) as it's independent.
```

## Key Principles

**Be realistic:**
- If code exists but isn't tested, it's not "done"
- If branch isn't merged, it's "in progress"
- If feature is broken, it needs rework (new letter child)

**Base decisions on evidence:**
- Git commits = proof of work
- Merged branches = truly complete
- No commits = not started

**Preserve history:**
- Don't delete completed subtasks
- Mark them done with git references

---

Arguments: $ARGUMENTS
