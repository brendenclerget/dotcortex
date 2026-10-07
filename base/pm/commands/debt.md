---
name: debt
description: Track the team's tech debt in long-lived lists - list them, add an entry, work a batch, resolve entries
argument-hint: "[list | add <area> <what's wrong> | show <list> | work <entry ids> | resolve <entry id> <commit or ticket>]"
---

# Tech-debt lists

Tech debt is tracked per team in long-lived lists, not as one-off tickets. A list is never
closed: entries are added as they're found and move to its Resolved section when fixed.

Subcommand: **$ARGUMENTS** (empty = `list`)

## Where they live

`.dotcortex/layers/team/debt/DEBT-<AREA>-<topic>.md`, one file per area and topic (for example
`DEBT-API-error-handling.md`, `DEBT-WEB-test-flakes.md`). `<AREA>` is short and uppercase. The
team layer is shared: in an org install it is the team's folder in the org repo, so every project
on the team sees the same lists.

Every write is one transaction, pulled first:

```bash
.dotcortex/bin/task-tx.sh --dir .dotcortex/layers/team --pull-only      # before reading
.dotcortex/bin/task-tx.sh --dir .dotcortex/layers/team \
  --msg "debt: <what changed> (<list>)" debt/<file>.md                   # after editing
```

No team remote: the layer is a plain directory and the edit alone is the write.

## File format

```markdown
# DEBT-API-error-handling: Inconsistent API error handling

**Area:** API
**Owner:** <email or name, or the team>
**Updated:** YYYY-MM-DD

<One paragraph: what this list tracks and why it matters.>

## Open

### API-1. Retry logic swallows 4xx responses
- Found: YYYY-MM-DD, by {{TICKET_PREFIX}}-NNN (or the session that found it)
- What's wrong: <one or two sentences>
- Impact: <who or what it hurts, and how often>
- Evidence: <file:line, counts, logs, a ticket>
- Fix: <the recommended fix>, size S | M | L
- Needs a call: no | yes: <the question, and who answers it>

## Resolved

- API-1. Retry logic swallows 4xx responses: YYYY-MM-DD, <commit or ticket>
```

Entry ids (`API-1`, `API-2`, …) are stable and never reused. The next id is one more than the
highest in the file, Open and Resolved together.

## Subcommands

**`list`**: every list with its open count, the oldest open entry's date, and entries marked
`Needs a call: yes`.

**`add <area> <what's wrong>`**: find the list for that area and topic, or create one (ask for the
topic if it isn't obvious). Fill every field you can verify; leave `Evidence` empty rather than
guessing. One entry per problem. Agents use this, instead of opening a ticket, for small recurring
issues they notice outside their ticket's scope.

**`show <list>`**: the list's open entries, grouped by size, with the calls needed.

**`work <entry ids>`**: pick up a batch. Small entries ride along on an existing ticket. A batch
that needs its own ticket follows `workflow_policy.ticket_creation` (CLAUDE.md): create it with
`/ticket-new` and cite the entry ids in its description. An entry marked `Needs a call: yes` is not
worked until that person answers; under `crucial_decisions: block` nothing for it is built.

**`resolve <entry id> <commit or ticket>`**: move the entry to Resolved with today's date and the
reference. Never delete an entry.

## Rules

- Never fabricate evidence or counts. Write what you checked.
- A call that changes product behaviour, money, security or public promises is a crucial call: it
  goes on the entry as `Needs a call: yes`, never decided by the agent.
- Keep entries short. Detail that only matters while fixing goes into the ticket that fixes it.
