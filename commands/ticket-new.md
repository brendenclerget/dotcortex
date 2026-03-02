---
name: ticket-new
description: Create parent ticket with feature spec and subtask breakdown
argument-hint: <feature-name>
---

# Create Feature with Breakdown

Create a parent ticket for: $ARGUMENTS

## Step 0: Estimate Complexity First

**Before creating anything, assess scope:**

- **Tiny (< 1 hour):** Stop! Use `/pm new` instead - single ticket is enough
- **Small (1-4 hours):** Single ticket with checklist - use `/pm new`
- **Medium (4-8 hours / 1 day):** Parent ticket, maybe 2-3 subtasks - proceed
- **Large (multiple days):** Parent + 4-7 subtasks - proceed
- **Huge (week+):** Might need multiple parent tickets - discuss with user first

**If this seems like < 4 hours of work, stop and recommend `/pm new` instead.**

## Step 1: Read counter and create parent ticket

```bash
# Read next number
NEXT=$(cat TASKS_DIR/.ticket_counter)

# Check if PREFIX-$NEXT already exists
if ls TASKS_DIR/PREFIX-$(printf "%03d" $NEXT)-* 2>/dev/null; then
  echo "PREFIX-$NEXT exists! Finding next available..."
  HIGHEST=$(ls TASKS_DIR/PREFIX-*.md | grep -o 'PREFIX-[0-9]\+' | sed 's/PREFIX-//' | sort -n | tail -1)
  NEXT=$((HIGHEST + 1))
fi
```

**Create parent ticket:**
- Get next ticket number (with duplicate check)
- Create `TASKS_DIR/PREFIX-XXX-$ARGUMENTS.md`
- Mark as **Type: PARENT**

## Step 2: Gather feature requirements

Ask user:
- Overview of feature (what and why)
- User stories (who wants what benefit)
- Priority (HIGH/MEDIUM/LOW)
- Any specific requirements or constraints
- **Why this needs breakdown** (confirm it's not just a single ticket)

## Step 3: Scope the design (default concise)

Use a short prompt like:
"Scope implementation for [$ARGUMENTS] with minimal overhead.

Consider:
- **Architecture approach** - How does this fit into existing system?
- **Data models** - What changes to API/database needed?
- **UI components** - What screens/components required?
- **Integration points** - What systems does this touch?
- **Testing strategy** - How to verify each piece?
- **Edge cases** - What can go wrong?
- **Dependencies** - What must be done first?

Aim for 3-5 major subtasks, not 10+ micro-tasks."

**Escalate to extended thinking only when needed:**
- Use `think hard` for medium complexity with unclear tradeoffs.
- Use `ultrathink` only for high-risk architecture or if user explicitly requests it.

## Step 4: Create parent ticket with spec

**Use the parent ticket template:**
```bash
cat TASKS_DIR/templates/parent-ticket-template.md
```

**Include:**
- Feature specification section (overview, user stories, acceptance criteria)
- Technical design (data models, UI/UX, dependencies)
- Testing plan
- Subtasks section (to be filled in step 5)

## Step 5: Break into subtasks

Ask: "Should I break this into subtasks?"

**Only create subtasks if:**
- You identified 3-5 major, separable steps
- Each step is substantial (2+ hours of work)
- Steps have clear boundaries
- User confirms breakdown makes sense

**If yes:**
- Create folder `TASKS_DIR/PREFIX-XXX/`
- Move parent ticket into the folder
- Identify 3-5 implementation steps
- Name subtasks with letter suffixes: PREFIX-XXXa, PREFIX-XXXb, PREFIX-XXXc, etc.
- Create child ticket for each: `TASKS_DIR/PREFIX-XXX/PREFIX-XXXa-description.md`
- **Do NOT increment the ticket counter for subtasks** — letter subtasks don't consume numbers
- Link children in parent ticket

**Each subtask should:**
- Be completable in one focused session
- Have its own testable deliverable
- Be independently mergeable if possible

**Bad subtasks (too small):**
- "Update imports"
- "Fix TypeScript errors"
- "Add tests" (part of every task)

**Good subtasks (substantial, separable):**
- "Build API endpoints for listings"
- "Create listing card component with image/price display"
- "Implement search/filter logic with query params"

## Step 6: Update counter

```bash
# Increment by 1 for the parent ticket only (subtasks use letter suffixes, not new numbers)
echo $(($(cat TASKS_DIR/.ticket_counter) + 1)) > TASKS_DIR/.ticket_counter
```

**Update parent ticket with subtask list:**
```markdown
### Subtasks
- [ ] PREFIX-XXXa: First step description
- [ ] PREFIX-XXXb: Second step description
- [ ] PREFIX-XXXc: Third step description
```

## Summary Report

After creation, provide:
```markdown
Created PREFIX-XXX: [Feature Name]

**Feature:** [Brief description]
**Subtasks:** X created
- PREFIX-XXXa: [Description]
- PREFIX-XXXb: [Description]

**Next step:** Start with PREFIX-XXXa (recommend this one because...)
```

---

**Remember:**
- Default to fewer, larger subtasks rather than many tiny ones.
- **Always update `TASKS_DIR/BACKLOG.md`** after creating tickets — add entries to the appropriate priority section.

Arguments: $ARGUMENTS
