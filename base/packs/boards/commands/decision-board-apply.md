---
name: decision-board-apply
description: Apply the answers saved on the decision board into the decision logs and the tickets
argument-hint: "[D<n> ...]"
---

# Apply decision board answers

Load the `decision-board` skill and follow its **Apply** section. If decision ids are given ($ARGUMENTS), apply
only those.

Pending answers are `decisions/<D-id>` rows with a non-null `choice` and no newer `applied/<D-id>`; rows with
`choice: null` are drafts or cleared answers and are skipped. In order: update the decision's log (status, answer,
dates, follow-up), log the answer on each related ticket and tick the criteria it settles, commit the team layer
and the task roots with `task-tx.sh`, then mark `applied/<D-id>`. Never write `seen/<D-id>`. Finish by
republishing the board and reporting applied, skipped and the follow-up work each answer requires (don't dispatch
builds).
