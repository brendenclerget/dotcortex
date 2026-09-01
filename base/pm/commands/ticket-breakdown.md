---
name: ticket-breakdown
description: Break existing ticket into subtasks
argument-hint: {{TICKET_PREFIX}}-XXX
---

# Break Ticket into Subtasks

Break down ticket $ARGUMENTS into implementation steps.

**Process:**

1. **Read the parent ticket:** `{{TASKS_DIR}}/$ARGUMENTS-*.md`

2. **Analyze complexity:**
   - Is this too large for one session?
   - Can it be broken into logical steps?
   - What are the dependencies?

3. **Create subtasks using letter subnumbering:**
   - Create folder: `{{TASKS_DIR}}/$ARGUMENTS/` (if not already inside a parent directory)
   - Move the parent ticket into the folder if needed
   - Identify 3-7 steps
   - Name subtasks as `$ARGUMENTS`a, `$ARGUMENTS`b, `$ARGUMENTS`c, etc. (e.g., {{TICKET_PREFIX}}-112a, {{TICKET_PREFIX}}-112b, {{TICKET_PREFIX}}-112c)
   - Create child ticket for each: `{{TASKS_DIR}}/$ARGUMENTS/$ARGUMENTSa-description.md`
   - **Never read, increment, or write `.ticket_counter`** — letter children consume no ticket numbers, and no new top-level number is ever allocated by a breakdown. Subtasks are always letter children of `$ARGUMENTS`.

4. **Update parent ticket:**
   - Change Type to PARENT
   - Add subtasks section:
```markdown
   ### Subtasks
   - [ ] $ARGUMENTSa: Step 1
   - [ ] $ARGUMENTSb: Step 2
   - [ ] $ARGUMENTSc: Step 3
```

5. **Land the breakdown — one scoped transaction.** The pull already happened in
step 0 (below) BEFORE any file was read or moved. Use `git mv` for the parent's
move into the family folder so the deletion of the old flat path is staged with it:
```bash
# step 0 (runs FIRST, before reading the parent): git -C {{TASKS_DIR}} pull --rebase
git -C {{TASKS_DIR}} mv "$PARENT_FLAT_FILE" "$ARGUMENTS/"   # if the parent was a flat file
git -C {{TASKS_DIR}} add "$ARGUMENTS/" BACKLOG.md            # family folder + board row; exact paths, never -A
git -C {{TASKS_DIR}} commit -m "$ARGUMENTS: break down into subtasks" -- "$ARGUMENTS/" "$PARENT_FLAT_FILE" BACKLOG.md   # old flat path included so the git mv deletion lands in THIS commit
git -C {{TASKS_DIR}} push || { git -C {{TASKS_DIR}} pull --rebase && git -C {{TASKS_DIR}} push; }
```

6. **Report:** List subtasks created with dependency order

**Naming rules:**
- Letters are lowercase: a, b, c, ... z
- If you somehow need >26 subtasks, the ticket is too big — split into multiple parents instead
- Subtask files: `$ARGUMENTSa-short-description.md` (letter attached directly, no dash before letter)
- Letter children are local implementation detail — they never get their own top-level ID.

Arguments: $ARGUMENTS
