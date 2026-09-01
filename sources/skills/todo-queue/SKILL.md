---
name: todo-queue
description: Maintain {{PROJECT_NAME}}'s canonical ordered next-work queue in {{TASKS_DIR}}/TODO.md. Use when the user or an agent asks to show the TODO list, decide what is next from the agreed queue, append a ticket or new task, reorder work, mark an item started/blocked/completed, reconcile the queue with ticket state, or coordinate parallel per-component sessions.
---

# TODO Queue

Maintain `{{TASKS_DIR}}/TODO.md` as the short, agreed execution order. Individual {{TICKET_PREFIX}}
tickets remain the source of truth for scope, evidence, status, and acceptance criteria;
`BACKLOG.md` remains the full backlog. Never duplicate a ticket's detailed plan into the queue.

## Before changing the queue

1. Read the repo's agent instruction file, `TODO.md`, and the `pm-agent` skill file.
2. Resolve every referenced ticket with `find {{TASKS_DIR}} -name '{{TICKET_PREFIX}}-XXX*'` before reading it.
3. Inspect `{{TASKS_DIR}}` git status. Preserve other agents' dirty changes and never stage them.
4. Treat the table order as deliberate. Do not reprioritize from the full backlog unless asked.

## Operations

- **Show**: With no operation, display the ordered queue, blockers, and the top unblocked item in
  each non-colliding lane.
- **Add ticket**: `/todo add {{TICKET_PREFIX}}-XXX` resolves the ticket, copies its exact title, and appends it to
  the end unless the user specifies `before {{TICKET_PREFIX}}-YYY`, `after {{TICKET_PREFIX}}-YYY`, or a numeric position.
- **Add description**: `/todo add <description>` uses `pm-agent` to create a real ticket first, then
  appends its assigned ID. Never add an un-ticketed implementation item.
- **Move**: Reorder only the named row. Preserve every other row's relative order.
- **Start**: Confirm dependencies and worktree collision risk, mark the queue row `ACTIVE`, and use
  the PM workflow to update the ticket/backlog when the user intends work to begin.
- **Block/park**: Keep the row in place, record the concrete gate, and set `BLOCKED` or `PARKED`.
- **Done**: Verify the ticket's acceptance criteria and PM closeout rules. Archive through
  `pm-agent`, then remove the row; the ticket/archive is the permanent history.
- **Sync**: Re-read every ticket and repair stale title/status/gate fields without changing order.
  Report missing, archived, duplicated, or newly blocked IDs rather than guessing.
- **Note**: Update only a row's concise `Next action / gate` text.

## Queue rules

- Keep one row per {{TICKET_PREFIX}} ID and monotonically numbered positions.
- Append is the default; never insert based on personal priority judgment.
- `ACTIVE` means a session owns it now. `READY` is unblocked. `WAITING` has an upstream dependency.
  `USER` needs a user-run command/device step. `PARKED` requires explicit release.
- Tickets confined to two different components (e.g. backend-only and client-only) may run together.
  Do not recommend two code-writing sessions in the same repo/worktree. Device/evidence work may run
  alongside code if it does not edit files.
- Keep `Updated` current and add a one-line log entry for structural changes (append, move, remove).
- Do not alter ticket status merely because a row moved. Status changes require the corresponding PM
  operation.
- Do not run tests, servers, curl, migrations, or production commands. The repository's user-run
  validation rules still apply.
- Commit/push task-repo queue changes at session end, staging only files this operation owns.

## Response style

For `/todo` (show), render the whole queue as a **Markdown table**, one row per ticket, with columns:
`# | Ticket | Lane | State | Notes`.

- **Notes must be terse** — one short phrase (the gate/next action gist), NOT the ticket's full
  `Next action / gate` text. Aim for roughly one line; trim the detail that lives in the ticket.
- Keep the ticket cell short: `**{{TICKET_PREFIX}}-XXX** — <short title>`.
- Preserve queue order (do not reorder to group by state). A leading state glyph is fine
  (ACTIVE / READY / WAITING / USER / PARKED).
- After the table, add at most a few lines: the top actionable item per non-colliding lane and any
  worktree-collision callouts. Don't restate the table in prose.

For mutations, skip the table: state the exact movement in one sentence and identify any dependency
or worktree collision discovered.
