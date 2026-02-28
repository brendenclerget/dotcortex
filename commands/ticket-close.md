---
name: ticket-close
description: Mark ticket DONE, extract knowledge, archive, update backlog, and report
argument-hint: <PREFIX-XXX>
---

# Close Ticket

Close and archive ticket: **$ARGUMENTS**

Execute the full close workflow for this ticket. Follow every step — do not skip or reorder.

## Step 1: Locate the ticket

```bash
find TASKS_DIR -name "$ARGUMENTS*" -not -path "*/archive/*"
```

If not found, check the archive — it may already be closed. If truly missing, report and stop.

Handle both layouts:
- **Simple ticket:** `TASKS_DIR/PREFIX-XXX-name.md`
- **Parent directory:** `TASKS_DIR/PREFIX-XXX/PREFIX-XXX-name.md`

## Step 2: Mark DONE

Read the ticket file and update these fields in place:
- `Status:` → `DONE`
- `Updated:` → today's date (YYYY-MM-DD)
- Add `Completed: YYYY-MM-DD` if not already present

If this is a parent ticket with subtasks, verify all subtasks are marked done. If any are still open, report which ones and stop — do not close a parent with open subtasks.

Before marking DONE, reconcile the parent's **Implementation Checklist** and **Acceptance Criteria** — check off items that are complete based on subtask work, and note any that remain open (these become follow-up scope or are explicitly deferred).

## Step 3: Update parent (if subtask)

Check if this ticket has a `Parent:` or `**Parent:**` reference in its metadata.

If yes:
- Find the parent ticket file
- Change `- [ ] $ARGUMENTS` to `- [x] $ARGUMENTS` in the subtasks list
- Add a note: `Completed YYYY-MM-DD`
- Scan the parent's **Implementation Checklist** and **Acceptance Criteria**. If any unchecked items are clearly covered by the work in this subtask, check them off too.

## Step 4: Knowledge extraction

Read the ticket's Technical Notes, Lessons Learned, and work done sections. Decide if anything belongs in `.claude/knowledge/` files.

**Store when the ticket reveals:**
- A technical gotcha that would bite someone again
- A non-obvious design decision with rationale
- A new script, command, or operational procedure
- A pattern that should be followed going forward
- Scope intentionally deferred

**Skip silently when:**
- Straightforward implementation (no surprises)
- Knowledge already captured in code or existing docs
- Session-specific context

If extracting, write concise entries (2-5 lines each) to the appropriate knowledge file with the ticket reference. Most tickets won't produce a learning — that's fine.

## Step 5: Write completion summary in ticket

Before archiving, add a brief `## Completion Summary` section at the bottom of the ticket (or the parent ticket if subtasks exist) with:
- 2-3 sentence summary of what was done
- Key commits or PRs (if known)
- Any lessons learned worth noting

## Step 6: Archive

```bash
mkdir -p TASKS_DIR/archive/$(date +%Y-%m)

# Simple ticket (single file):
mv TASKS_DIR/PREFIX-XXX-*.md TASKS_DIR/archive/$(date +%Y-%m)/

# Parent ticket (entire directory):
mv TASKS_DIR/PREFIX-XXX/ TASKS_DIR/archive/$(date +%Y-%m)/
```

**NEVER delete ticket files. Archive = MOVE.**

## Step 7: Update backlog

Read `TASKS_DIR/BACKLOG.md` and remove the entry for $ARGUMENTS. This includes:
- Any `### $ARGUMENTS:` section in the prioritized backlog
- Any row in the Small Enhancements table referencing $ARGUMENTS
- Any mention in the Active Work section

If the ticket isn't in the backlog, that's fine — skip silently.

## Step 8: Report

Summarize what was done:

```
Marked $ARGUMENTS done and archived to archive/YYYY-MM/
```

Include:
- Whether knowledge was extracted (and to which file)
- Whether a parent ticket was updated
- Whether the backlog was updated
- Any warnings (e.g., "parent PREFIX-XXX still has 2 open subtasks")

---

**Remember:**
- Do not ask permission — just execute the workflow
- Do not start servers or run tests
- If anything looks wrong (missing ticket, open subtasks), report and stop rather than guessing

Arguments: $ARGUMENTS
