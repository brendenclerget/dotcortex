---
name: ticket-status
description: Update a ticket's status and assignee, sync the backlog, and commit the change
argument-hint: <{{TICKET_PREFIX}}-XXX> <STATUS> [OWNER]
---

# Set Ticket Status

Update the status (and optionally the assignee) of ticket: **$ARGUMENTS**

Use this for explicit status transitions outside the full close workflow — picking up work, moving to review, blocking, etc. For final close-out, prefer `/ticket-close`.

## Usage

`/ticket-status <{{TICKET_PREFIX}}-XXX> <STATUS> [OWNER]`

- **STATUS** — one of: `TODO`, `IN_PROGRESS`, `BLOCKED`, `REVIEW`, `DONE`, `BACKLOG`, `PLANNING` (`BACKLOG` is legacy: write `TODO`)
- **OWNER** — optional. Reassigns the ticket when given. Without it the Assignee stays as it is;
  a ticket with no Assignee gets the current user (their email from `git config user.email`).

## Step 1: Parse arguments

Split `$ARGUMENTS` into ticket ID, target status, and optional owner. If status is missing or not in the canonical set above, report the allowed values and stop.

If owner is omitted and the ticket has no `Assignee:` yet:

```bash
git config user.email
```

The Assignee is the engineer who owns the ticket and answers its questions. An agent picking up
work never reassigns it to itself.

## Step 2: Pull, then locate the ticket

FIRST: `git -C {{TASKS_DIR}} pull --rebase` — always start from remote truth; another session may have moved, archived, or already re-statused this ticket. Resolve the ticket's path AFTER the pull.

```bash
find {{TASKS_DIR}} -name "$TICKET_ID*" -not -path "*/archive/*"
```

Handle both layouts:
- **Simple ticket:** `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX-name.md`
- **Parent directory:** `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/{{TICKET_PREFIX}}-XXX-name.md` (and child files inside)

If not found in active tasks, check `{{TASKS_DIR}}/archive/`. If transitioning back from archive, move it out before editing — closed tickets shouldn't be edited in place.

## Step 3: Update ticket fields

Open the ticket file and update:
- `Status:` → the new status
- `Assignee:` → the owner from Step 1, only when one was given or the field is missing
- `Updated:` → today's date (YYYY-MM-DD)
- If status is `DONE`, also set `Completed: YYYY-MM-DD`

**Keep the ticket core accurate** (the boards render from it):
- **→ IN_PROGRESS / TODO:** `**Review:** none`, unless a question under `## Needs from assignee`
  is still open (then `decision-needed`).
- **→ BLOCKED:** name what it waits on: another ticket in `**Depends on:**`, or a question (an open
  ask with nothing built, or a cited `- Decision: D<n>`). `**Review:** decision-needed` when a
  person must answer.
- **Work landed (any status):** check the criteria it met (`- [x] AC2: …`). Partial or deferred
  work stays unchecked, with the reason on the line. Never check a criterion because a log line
  says "built"; check it from the code or the test.
- **→ REVIEW:** `**Review:** closure-proposed` when every criterion is checked (or its deferral is
  explained on the line), otherwise `decision-needed` with the ask written out.
- **No open asks left:** Needs says `None.`, and `decision-needed` moves to `none`.
- Add a dated line to `## Notes / Log`. Any open decisions it waits on: "waiting on D<n>: <title>".

## Step 4: Handle DONE specially

If the requested status is `DONE`, this command intentionally does **not** run the full close workflow (knowledge extraction, parent updates, archival). Report that to the user and recommend `/ticket-close $TICKET_ID` instead.

If the user still insists on a raw status flip without close, proceed — but skip archiving here. `/ticket-close` is the canonical archive path.

## Step 5: Update the backlog

Read `{{TASKS_DIR}}/BACKLOG.md` and move the ticket entry to the section that matches its new status, per the backlog-validation skill's categorization rules. If the ticket isn't tracked in the backlog (e.g., a child ticket), skip silently.

## Step 6: Commit and push

Stage only the files this status change touched — never the whole tasks dir (parallel sessions leave unrelated dirty files):

```bash
# $TICKET_FILE is the path RELATIVE to {{TASKS_DIR}} (resolved after the Step 2 pull)
git -C {{TASKS_DIR}} add "$TICKET_FILE" BACKLOG.md
git -C {{TASKS_DIR}} commit -m "chore: set $TICKET_ID to $STATUS" -- "$TICKET_FILE" BACKLOG.md
git -C {{TASKS_DIR}} push || { git -C {{TASKS_DIR}} pull --rebase && git -C {{TASKS_DIR}} push; }
```

## Step 6b: Linear (after the commit)

> **Linear:** If the Linear MCP is available in this session, mirror this status change to the ticket's linked issue (status, and the assignee when it changed). Nothing else: the ticket's content never goes to Linear (`pm-agent`, Linear block, **Issue content**). If the project config enables Linear (`config.linear.enabled`) but the MCP is not connected, pause and ask the user to connect it (continue markdown-only only at their explicit word). If Linear is not configured, skip this step silently.

A failed issue update leaves a visible pending-sync note in the ticket; the markdown commit stands.

## Step 7: Report

Summarize:
- Ticket ID, new status, assignee
- Whether the backlog was updated
- If `DONE` was requested without `/ticket-close`, surface the recommendation again

---

**Remember:**
- Do not run tests, lint, or implementation work — this command only mutates ticket metadata.
- Do not invent statuses outside the canonical set.
- For `DONE`, route the user to `/ticket-close` so knowledge extraction and archive both happen.

Arguments: $ARGUMENTS
