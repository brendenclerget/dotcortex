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

## Step 1: Establish the ticket identity

**Linear:** If the Linear MCP is available in this session, create the Linear issue
first and use its identifier to name the ticket — the markdown file and every
reference below take that identifier instead of an allocated counter number, and the
counter is left untouched. If the project config enables Linear (`config.linear.enabled`)
but the MCP is not connected, pause and ask the user to connect it (continue
markdown-only only at their explicit word). If Linear is not configured, skip this step
silently and allocate a number from the counter as described next.

**Pure-markdown mode — ticket creation is ONE retryable transaction.**
Pull, create the file, update the counter, and push together. If the push is rejected,
re-pull and retry with the new counter value (the ticket gets a new number). Never
read the counter early and write it later — a gap between read and push hands two
sessions the same number.

```bash
# --- One transaction: pull -> create -> counter update -> push ---
attempt=0
until [ $attempt -ge 5 ]; do
  attempt=$((attempt + 1))

  # 1. Pull (always start from remote truth)
  git -C {{TASKS_DIR}} pull --rebase

  # 2. Allocate the number from the freshly pulled counter
  NEXT=$(cat {{TASKS_DIR}}/.ticket_counter)
  if ls {{TASKS_DIR}}/{{TICKET_PREFIX}}-$(printf "%03d" $NEXT)-* >/dev/null 2>&1; then
    HIGHEST=$(ls {{TASKS_DIR}}/{{TICKET_PREFIX}}-*.md | grep -o '{{TICKET_PREFIX}}-[0-9]\+' | sed 's/{{TICKET_PREFIX}}-//' | sort -n | tail -1)
    NEXT=$((HIGHEST + 1))
  fi
  TICKET={{TICKET_PREFIX}}-$(printf "%03d" $NEXT)

  # 3. Create the ticket file (steps 2-5 below produce its contents)
  #    ... write {{TASKS_DIR}}/$TICKET-<slug>.md ...

  # 4. Update the counter — parent number only; letter subtasks consume no numbers
  echo $((NEXT + 1)) > {{TASKS_DIR}}/.ticket_counter

  # 5. Commit the exact paths (never `git add -A`) and push
  git -C {{TASKS_DIR}} add .ticket_counter $TICKET-*.md BACKLOG.md
  git -C {{TASKS_DIR}} commit -m "$TICKET: create ticket"
  if git -C {{TASKS_DIR}} push; then
    echo "Created $TICKET"
    break
  fi

  # Push rejected: someone else took this number. Reset and retry from the pull.
  git -C {{TASKS_DIR}} reset --soft HEAD~1
  git -C {{TASKS_DIR}} restore --staged .
done
```

**Create parent ticket:**
- Use the identifier established above (Linear identifier, or the transactionally
  allocated `{{TICKET_PREFIX}}-XXX`)
- Create `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX-$ARGUMENTS.md`
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
cat .dotcortex/templates/parent-ticket-template.md
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
- Create folder `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/`
- Move parent ticket into the folder
- Identify 3-5 implementation steps
- Name subtasks with letter suffixes: {{TICKET_PREFIX}}-XXXa, {{TICKET_PREFIX}}-XXXb, {{TICKET_PREFIX}}-XXXc, etc.
- Create child ticket for each: `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/{{TICKET_PREFIX}}-XXXa-description.md`
- **Do NOT read or increment the ticket counter for subtasks** — letter subtasks don't
  consume numbers, and they get no Linear issue (top-level tickets only)
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

## Step 6: Land the subtasks and the subtask list

The counter was already advanced inside the Step 1 transaction (parent number only —
subtasks use letter suffixes, not new numbers). Commit and push the subtask files and
the updated parent as one scoped transaction of their own:

```bash
git -C {{TASKS_DIR}} pull --rebase
git -C {{TASKS_DIR}} add {{TICKET_PREFIX}}-XXX/ BACKLOG.md
git -C {{TASKS_DIR}} commit -m "{{TICKET_PREFIX}}-XXX: add subtasks"
git -C {{TASKS_DIR}} push   # on rejection: re-pull, re-apply, push again
```

**Update parent ticket with subtask list:**
```markdown
### Subtasks
- [ ] {{TICKET_PREFIX}}-XXXa: First step description
- [ ] {{TICKET_PREFIX}}-XXXb: Second step description
- [ ] {{TICKET_PREFIX}}-XXXc: Third step description
```

## Summary Report

After creation, provide:
```markdown
Created {{TICKET_PREFIX}}-XXX: [Feature Name]

**Feature:** [Brief description]
**Subtasks:** X created
- {{TICKET_PREFIX}}-XXXa: [Description]
- {{TICKET_PREFIX}}-XXXb: [Description]

**Next step:** Start with {{TICKET_PREFIX}}-XXXa (recommend this one because...)
```

---

**Remember:**
- Default to fewer, larger subtasks rather than many tiny ones.
- **Always update `{{TASKS_DIR}}/BACKLOG.md`** after creating tickets — add entries to the appropriate priority section.

Arguments: $ARGUMENTS
