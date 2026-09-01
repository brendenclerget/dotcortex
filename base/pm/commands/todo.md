---
name: todo
description: Show and maintain the canonical ordered {{PROJECT_NAME}} next-work queue
---

# TODO Queue

Use the `todo-queue` skill and treat `{{TASKS_DIR}}/TODO.md` as the canonical agreed execution
order. Individual tickets and `BACKLOG.md` remain authoritative for detail and global backlog state.

## Commands

- `/todo` or `/todo show` — show the queue and top unblocked work by compatible lane.
- `/todo add {{TICKET_PREFIX}}-XXX` — append an existing ticket.
- `/todo add {{TICKET_PREFIX}}-XXX before|after {{TICKET_PREFIX}}-YYY` — insert relative to another row.
- `/todo add <description>` — create a ticket through `pm-agent`, then append it.
- `/todo move {{TICKET_PREFIX}}-XXX before|after {{TICKET_PREFIX}}-YYY` — reorder one item.
- `/todo start {{TICKET_PREFIX}}-XXX` — verify gates/collisions, then mark it active and update PM state.
- `/todo block {{TICKET_PREFIX}}-XXX <reason>` — record a concrete blocker without losing queue position.
- `/todo park {{TICKET_PREFIX}}-XXX <reason>` — require explicit user release before starting.
- `/todo note {{TICKET_PREFIX}}-XXX <next action>` — change only the concise gate/action text.
- `/todo done {{TICKET_PREFIX}}-XXX` — verify and close via PM workflow, then remove it from the queue.
- `/todo sync` — reconcile titles/status/gates with ticket files without changing order.

Never stage or overwrite another agent's dirty files. Never run user-owned tests, servers, or
production commands as part of queue maintenance.

Arguments: $ARGUMENTS
