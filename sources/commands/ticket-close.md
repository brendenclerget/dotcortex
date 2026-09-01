---
name: ticket-close
description: Mark ticket DONE, extract knowledge, archive, update backlog, and report
argument-hint: <{{TICKET_PREFIX}}-XXX>
---

# Close Ticket

Close and archive ticket: **$ARGUMENTS**

Execute the full close workflow for this ticket. Follow every step — do not skip or reorder.

## Step 1: Locate the ticket

```bash
find {{TASKS_DIR}} -name "$ARGUMENTS*" -not -path "*/archive/*"
```

If not found, check the archive — it may already be closed. If truly missing, report and stop.

Handle both layouts:
- **Simple ticket:** `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX-name.md`
- **Parent directory:** `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/{{TICKET_PREFIX}}-XXX-name.md`

## Step 2: Mark DONE

Read the ticket file and update these fields in place:
- `Status:` → `DONE`
- `Updated:` → today's date (YYYY-MM-DD)
- Add `Completed: YYYY-MM-DD` if not already present

If this is a parent ticket with subtasks, verify all subtasks are marked done. If any are still open, report which ones and stop — do not close a parent with open subtasks. **Exception:** if the user explicitly directs closing anyway, proceed but (a) note the exception + the open children in the ticket's Status/Log lines, and (b) keep each open child as a live standalone file in the active tasks dir and surface it in BACKLOG.md's "Orphaned Subtasks" section so it stays tracked.

Before marking DONE, reconcile the parent's **Implementation Checklist** and **Acceptance Criteria** — check off items that are complete based on subtask work, and note any that remain open (these become follow-up scope or are explicitly deferred).

## Step 3: Update parent (if subtask)

Check if this ticket has a `Parent:` or `**Parent:**` reference in its metadata.

If yes:
- Find the parent ticket file
- Change `- [ ] $ARGUMENTS` to `- [x] $ARGUMENTS` in the subtasks list
- Add a note: `Completed YYYY-MM-DD`
- Scan the parent's **Implementation Checklist** and **Acceptance Criteria**. If any unchecked items are clearly covered by the work in this subtask, check them off too.

## Step 4: Knowledge extraction

Read the ticket's Technical Notes, Lessons Learned, and work done sections. Decide what's worth retaining, and where it belongs. There are two destinations with different purposes:

### 4a. Code-level knowledge → `.dotcortex/knowledge/`

Project-repo documentation, checked into the codebase, accessible by anyone cloning the project.

**Store when the ticket reveals:**
- A technical gotcha that would bite someone again
- A non-obvious design decision with rationale
- A new script, command, or operational procedure
- A pattern that should be followed going forward
- A scope intentionally deferred at the code level

Write concise entries (2–5 lines each) to the appropriate knowledge file with `**Ref:** {{TICKET_PREFIX}}-XXX` backlinks.

### 4b. Cross-session project context → Claude auto-memory

Claude's auto-memory is the `memory/` directory whose index `MEMORY.md` is autoloaded into every session's context. Sibling files in that directory are referenced from the index but are not autoloaded — they're pulled in when a topic is relevant.

**Store when the ticket reveals** (write here IN ADDITION to `.dotcortex/knowledge/` if both apply):
- A cross-cutting scope decision that took real effort to reach (e.g., v1 direction for a whole feature)
- Context a future session would need to carry forward, not rediscover from code
- A deferred item whose deferral rationale matters (not just "we decided not to")
- A load-bearing invariant or contract that spans multiple tickets

For each such item:
1. Create or update a memory file in the auto-memory directory with frontmatter (`name`, `description`, `type: project | feedback | user | reference`) and the body structured per memory guidelines.
2. Add (or update) a one-line pointer in `MEMORY.md` so it's discoverable from the autoloaded index.
3. Include cross-references to any `.dotcortex/knowledge/` files that hold the deeper technical detail.

**Skip silently when:**
- Straightforward implementation (no surprises)
- Knowledge already captured in code, existing docs, or an existing memory file
- Session-specific context that won't matter after the ticket ships

**Verify before asserting.** Memory is point-in-time. If you're extracting from ticket prose, the claims were true when written but may not be now. Check current code before writing a memory entry that makes strong claims about behavior or file paths.

Most tickets won't produce either kind of entry. That's fine.

## Step 5: Write completion summary in ticket

Before archiving, add a brief `## Completion Summary` section at the bottom of the ticket (or the parent ticket if subtasks exist) with:
- 2-3 sentence summary of what was done
- Key commits or PRs (if known)
- Any lessons learned worth noting

## Step 6: Archive

```bash
mkdir -p {{TASKS_DIR}}/archive/$(date +%Y-%m)

# Simple ticket (single file):
mv {{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX-*.md {{TASKS_DIR}}/archive/$(date +%Y-%m)/

# Parent ticket (entire directory):
mv {{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/ {{TASKS_DIR}}/archive/$(date +%Y-%m)/
```

**NEVER delete ticket files. Archive = MOVE.**

## Step 7: Update ALL tracking files (every board that references the ticket)

First discover every tracking file that references the ticket — don't assume:

```bash
grep -ln "$ARGUMENTS" {{TASKS_DIR}}/*.md
```

Then update each hit (skip silently if a file has no reference). Each board has its
own update semantics — apply the right one:

**`BACKLOG.md`** — remove the ticket's row/section from the open sections
(HIGH/Medium/Low tables, Active Work, `### $ARGUMENTS:` sections). Update the
`**Last Updated:**` header line with a one-clause closure note (date, ticket,
commit). If an open child was left behind (Step 2 exception), add/refresh its
row in **Orphaned Subtasks**.

**`TODO.md`** — remove the ticket's row from the queue table, renumber the
remaining rows so `#` stays contiguous, and add a dated entry at the TOP of
the `## Log` section (what shipped, commit, where the long tail went).
TODO.md is actively edited by parallel sessions — re-read it immediately
before editing.

**Any additional board files the project defines** (milestone/release/launch
boards, etc.) — these usually keep history rather than dropping rows. Follow the
board's own existing convention: read a couple of already-closed rows in that
file and match them. Typically that means flipping the status cell to
`DONE (YYYY-MM-DD)` and rewriting the notes cell to a short shipped summary —
commit hash, one-line scope, "Archived.", and any follow-up ticket pointer.

Boards drift, so always grep the ticket ID across the whole tasks directory
rather than relying on a fixed list of files.

## Step 8: Sync the PM repo

If `{{TASKS_DIR}}/` is its own git repo (see the task storage mode in config),
commit the close (ticket move + tracking-file updates) and push:

```bash
cd {{TASKS_DIR}} && git add <only-the-files-this-close-touched> && git commit && git push
```

Stage ONLY the files this close touched — parallel sessions leave unrelated
dirty files in this repo; never `git add -A` blindly, and never commit files
you didn't change.

## Step 9: Report

Summarize what was done:

```
Marked $ARGUMENTS done and archived to archive/YYYY-MM/
```

Include:
- Whether knowledge was extracted to `.dotcortex/knowledge/` (and to which file)
- Whether an auto-memory entry was written or updated (and whether `MEMORY.md` was re-indexed)
- Whether a parent ticket was updated
- Which tracking files were updated (BACKLOG.md / TODO.md / any other board) and which had no reference
- Whether the PM repo was pushed
- Any warnings (e.g., "parent {{TICKET_PREFIX}}-XXX still has 2 open subtasks")

---

**Remember:**
- Do not ask permission — just execute the workflow
- Do not start servers or run tests
- If anything looks wrong (missing ticket, open subtasks), report and stop rather than guessing

Arguments: $ARGUMENTS
