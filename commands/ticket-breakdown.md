---
name: ticket-breakdown
description: Break existing ticket into subtasks
argument-hint: PREFIX-XXX
---

# Break Ticket into Subtasks

Break down ticket $ARGUMENTS into implementation steps.

**Process:**

1. **Read the parent ticket:** `TASKS_DIR/$ARGUMENTS-*.md`

2. **Analyze complexity:**
   - Is this too large for one session?
   - Can it be broken into logical steps?
   - What are the dependencies?

3. **Create subtasks:**
   - Create folder: `TASKS_DIR/$ARGUMENTS/`
   - Identify 3-7 steps
   - Create child ticket for each
   - Update parent with subtask list

4. **Update parent ticket:**
   Add subtasks section:
```markdown
   ### Subtasks
   - [ ] PREFIX-XXX: Step 1
   - [ ] PREFIX-YYY: Step 2
```

5. **Update counter:**
   Increment by number of subtasks created

Arguments: $ARGUMENTS
