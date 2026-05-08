---
name: ticket-implement
description: Pick up a ticket — validate readiness, set IN_PROGRESS, then implement
argument-hint: <PREFIX-XXX>
---

# Implement Ticket

Pick up ticket **$ARGUMENTS** for implementation. Validate it's ready, mark it IN_PROGRESS, then carry out the work described.

## Step 1: Locate the ticket

```bash
find TASKS_DIR -name "$ARGUMENTS*" -not -path "*/archive/*"
```

Handle both layouts:
- **Simple ticket:** `TASKS_DIR/PREFIX-XXX-name.md`
- **Parent directory:** `TASKS_DIR/PREFIX-XXX/PREFIX-XXX-name.md`

If the ticket lives only in `TASKS_DIR/archive/`, report that it's already closed and stop.

## Step 2: Pre-flight status check

Read the ticket. Branch on `Status:`:

| Status | Action |
|---|---|
| `DONE` or `REVIEW` | Stop — already complete or pending review. Tell the user. |
| `IN_PROGRESS` | Stop — already being worked on. Show the current `Assignee:`. |
| `BLOCKED` | Stop — surface what it's blocked on. |
| `BACKLOG` or `PLANNING` | Stop — needs refinement first. Recommend `/ticket-refine $ARGUMENTS`. |
| `TODO` | Continue. |

Do **not** auto-refine or auto-unblock — that's a separate, deliberate step.

## Step 3: Mark IN_PROGRESS

Run the `/ticket-status` workflow to:
- Set `Status:` → `IN_PROGRESS`
- Set `Assignee:` → current git user (`git config user.name`)
- Update `Updated:` date
- Move the entry in `BACKLOG.md` to the appropriate section
- Commit (`chore: set $ARGUMENTS to IN_PROGRESS`) and push

Push **before** starting implementation so other agents and teammates see the claim.

## Step 4: Read the spec thoroughly

Re-read the ticket end-to-end:
- Description and motivation
- Acceptance criteria
- Implementation Checklist
- File targets / files to modify
- Technical notes and reference patterns
- Any linked subtasks or parent context

If this is a parent ticket with open subtasks, stop and recommend implementing the subtasks individually (`/ticket-implement <subtask-id>`).

## Step 5: Read the project rules

Before touching code:
- Read the project's `CLAUDE.md` (and any `AGENTS.md` if present) for non-negotiable rules, required checks, and code conventions
- Note required commands (typecheck, lint, tests) — you'll run these in Step 7

## Step 6: Implement

Carry out the work described in the ticket. Follow the file targets and patterns referenced in the spec. Match existing code style. Don't expand scope — if you discover additional needed work, capture it as a follow-up rather than silently growing this ticket.

## Step 7: Verify

Run the checks the project requires (typecheck, lint, tests) for the files you changed. If any fail, fix before reporting completion.

Do **not** auto-commit code changes. The user reviews and decides when to commit.

## Step 8: Report

Summarize for the user:
- What was implemented (file-level)
- Which acceptance criteria are now met (and which remain)
- Which checks were run and their results
- Suggested next step: review diff → commit → `/ticket-close $ARGUMENTS`

---

**Remember:**
- Pull before you push (the status update commits to TASKS_DIR).
- Don't auto-close. The user decides when work is truly done.
- Don't expand scope without surfacing it.

Arguments: $ARGUMENTS
