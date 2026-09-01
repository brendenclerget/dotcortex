---
name: mvp
description: Summarize current MVP status, blockers, and scope boundaries
---

# MVP Status

Read `{{TASKS_DIR}}/MVP_BACKLOG.md` and produce a concise launch-readiness summary.

## Process

1. **Read MVP_BACKLOG.md** for the curated launch board.

2. **Scan ticket state** for Must Ship and Should Ship items:
   - Check each ticket file for current status (TODO / IN_PROGRESS / DONE)
   - Note any status mismatches between MVP_BACKLOG.md and actual ticket files

3. **Identify blockers:**
   - Any Must Ship item that is blocked or has unresolved dependencies
   - Any critical-path item not yet started

4. **Produce summary — ALL sections must be rendered as markdown tables.** No bullet lists for the core data. Prose is allowed only for short intros/footers.

### Launch Readiness (table)

| Tier | Complete | In Progress | TODO | Total |
|------|----------|-------------|------|-------|
| Must Ship | … | … | … | … |
| Should Ship | … | … | … | … |
| Can Slip | … | … | … | … |

### Blockers (table)

Always include ticket title.

| Ticket | Title | Tier | Reason | Impact |
|--------|-------|------|--------|--------|
| … | … | … | … | … |

If no blockers, render a single-row table with "None" in Ticket and a short note in Reason.

### Must Ship / Should Ship / Can Slip Detail (tables)

Render one table per tier, each row includes ticket, title, status, and short note:

| Ticket | Title | Status | Notes |
|--------|-------|--------|-------|
| … | … | … | … |

### Critical Path Status (table)

Always include the ticket title alongside the ticket ID. Pull titles from the ticket file frontmatter / H1.

Fill one row per critical-path step, grouped by platform/track:

| Path | Step | Ticket | Title | Status |
|------|------|--------|-------|--------|
| _Platform A_ | _1_ | _`{{TICKET_PREFIX}}-NNN`_ | _…_ | _…_ |

### Scope Boundaries (table)

Fill one row per area of the product, stating what is in scope at launch:

| Area | Scope |
|------|-------|
| _Area — e.g. launch breadth_ | _what ships / what does not_ |

### Anti-Scope-Creep Check (table)

| Flag | Ticket / Area | Notes |
|------|---------------|-------|
| … | … | … |

If nothing flagged, render a single row with "None" and a short confirmation note.

## Important

- This command is **read-only**. It does NOT update tickets, change statuses, or mutate the backlog.
- To update ticket state, use `/pm` commands.
- To re-prioritize the MVP backlog, update `MVP_BACKLOG.md` directly or ask for a triage pass.

Arguments: $ARGUMENTS
