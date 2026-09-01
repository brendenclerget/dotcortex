---
name: implement
description: Pick up a ticket — validate readiness, reconcile its plan against the current tree, set IN_PROGRESS, implement, and report honestly
argument-hint: <{{TICKET_PREFIX}}-XXX>
---

# Implement Ticket

Pick up ticket **$ARGUMENTS** for implementation. Validate it's ready, reconcile its plan against the current tree, mark it IN_PROGRESS, then carry out the work described.

## Step 1: Locate the ticket

```bash
find {{TASKS_DIR}} -name "$ARGUMENTS*" -not -path "*/archive/*"
```

Handle both layouts:
- **Simple ticket:** `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX-name.md`
- **Parent directory:** `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/{{TICKET_PREFIX}}-XXX-name.md`

If the ticket lives only in `{{TASKS_DIR}}/archive/`, report that it's already closed and stop.

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

Also check now, **before claiming**: if this is a parent ticket with open subtasks, stop and recommend implementing the subtasks individually (`/implement <subtask-id>`).

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

## Step 5: Read the project rules

Before touching code:
- Read the project's `CLAUDE.md` (and any `AGENTS.md` if present) for non-negotiable rules, required checks, and code conventions
- Note the checks the project's workflow policy permits you to run (typecheck, lint, tests) — you'll run those in Step 8

## Step 6: Reconcile the plan against the current tree

Ticket plans go stale — especially in workspaces where multiple sessions or agents work in parallel. Before writing any code, verify the spec against the CURRENT tree:

- Do the named files/routes/models/screens still exist as the ticket describes? Has other work (check recent commits — `git log --oneline -15`, per component repo if applicable) already shipped part of the scope, superseded an approach, or changed a contract the plan relies on?
- Snapshot `git status --porcelain` (per component repo if applicable). Files left dirty by other sessions are **untouchable** — if the ticket's scope requires editing one, stop and surface the collision instead of proceeding into it.
- If the plan needs correcting, **update the ticket file now** (amend the plan/checklist, note what changed and why, dated) — the ticket stays the source of truth. Scope *corrections* are yours to make; scope *changes* (dropping an acceptance criterion, adding a feature) are the user's call — surface the question, and continue with the unaffected parts if any.

**Never strand the claim.** You now hold an IN_PROGRESS claim (Step 3). If anything from here on stops the work entirely before code lands — a dirty-file collision, a scope question that gates the whole ticket, or any other blocker — release the claim before stopping: run the `/ticket-status` workflow to set `Status:` → `BLOCKED` with a dated note naming exactly what it's blocked on, commit and push. A ticket must never be left IN_PROGRESS with nobody working it.

## Step 7: Implement

Carry out the work described in the ticket. Follow the file targets and patterns referenced in the spec. Match existing code style. Don't expand scope — if you discover additional needed work, capture it as a follow-up rather than silently growing this ticket.

If you dispatch subagents for independent slices of the work, plan lanes with **zero file overlap** between them (typically by component; keep tightly-coupled changes — e.g., an API contract and its consumer — in one lane, or sequence the dependent lane after its upstream). Every subagent prompt must include its slice of the spec verbatim, the list of untouchable dirty files, and the project rules from Step 5.

## Step 8: Verify

Run the checks `config.workflow_policy` permits (test_execution, etc.) for the files you changed. If any fail, fix before reporting completion.

Do **not** auto-commit code changes. The user reviews and decides when to commit.

## Step 9: Update the ticket and report

Ticket: check off completed checklist items, append a dated `## Work Log` entry (what was built, files touched, deviations), then set `Status:` → `REVIEW` via the `/ticket-status` workflow. The user marks DONE after validating — never close or archive here.

Your report must contain, without being asked:
- What was implemented (file-level)
- **Acceptance criteria table:** each criterion → met / not met / needs user validation. Be honest — explicitly state which checks were run and which were not
- Any plan corrections made in Step 6, and any scope questions awaiting the user
- Which checks were run and their results
- Suggested next step: review diff → commit → `/ticket-close $ARGUMENTS`

---

**Remember:**
- Pull before you push (status updates commit to {{TASKS_DIR}}).
- Don't auto-close. The user decides when work is truly done.
- Don't expand scope without surfacing it.
- Other sessions' dirty files are untouchable; collisions get surfaced, not steamrolled.

Arguments: $ARGUMENTS
