---
name: ticket-board
description: Build and publish the team's ticket board (whose move it is, asks, close or keep)
argument-hint: ""
---

# Ticket board

Load the `ticket-board` skill and follow its **Build and publish** section.

Read every `warn`/`error` line the build prints before publishing. Republish to the URL in
`.dotcortex/layers/team/boards.json` (`ticket_board`). If there is none yet, publish a new artifact with
`capabilities: {db: {}, user: {scopes: ["profile", "email"]}}` and `icon: "checklist"`, record the URL in
`boards.json` with `task-tx.sh`, and tell the team to share it at "can interact" access.
