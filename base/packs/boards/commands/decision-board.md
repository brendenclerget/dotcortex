---
name: decision-board
description: Build and publish the team's decision board from the decision logs in .dotcortex/layers/team/decisions/
argument-hint: ""
---

# Decision board

Load the `decision-board` skill and follow its **Build and publish** section.

Fix `error` lines in the decision logs before publishing (a duplicate D-id: give it the next free id the build
prints). Republish to the URL in `.dotcortex/layers/team/boards.json` (`decision_board`). If there is none yet,
publish a new artifact with `capabilities: {db: {}, user: {scopes: ["profile", "email"]}}` and `icon: "scale"`,
record the URL in `boards.json` with `task-tx.sh`, and tell the team to share it at "can interact" access.
