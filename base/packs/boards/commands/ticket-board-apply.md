---
name: ticket-board-apply
description: Apply the calls and answers saved on the ticket board (close, iterate, split, keep, reopen, answers to asks)
argument-hint: "[{{TICKET_PREFIX}}-XXX or <project>.{{TICKET_PREFIX}}-XXX ...]"
---

# Apply ticket board calls

Load the `ticket-board` skill and follow its **Apply** section. If ticket keys or ids are given ($ARGUMENTS),
apply only those.

Pending calls are `decisions/<key>` rows with a non-null `action` and no newer `applied/<key>`. Pending answers are
`needs/<key>:<N>` rows with a non-null `choice` and no newer `needs-applied/<key>:<N>`. Rows with `action: null` or
`choice: null` are drafts or cleared answers: skip them. A close uses the full `/ticket-close` workflow. Asks that
cite a D-number are answered on the decision board (`/decision-board-apply`). Never write `seen/<key>`. Finish by
rebuilding and republishing the board and reporting applied, skipped and the follow-up work each answer needs.
