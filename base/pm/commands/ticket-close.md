---
name: ticket-close
description: Mark ticket DONE, extract knowledge, archive, update backlog, and report
argument-hint: <{{TICKET_PREFIX}}-XXX>
---

# Close Ticket

Close and archive ticket: **$ARGUMENTS**

Execute the full close workflow for this ticket. Follow every step — do not skip or reorder.

## Step 0: Pull first

`git -C {{TASKS_DIR}} pull --rebase` before reading anything — the frozen contract is pull-before-read; another session may have already closed or moved this ticket.

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

**Ordering:** this step edits the ticket file only. The task-repo commit (Step 8) is the
authoritative close and lands FIRST; knowledge capture applies after it (Step 4 drafts,
Step 8 applies), and the Linear update runs LAST (Step 8b). Nothing external happens
before the close commit.

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

### 4a. Durable knowledge → the knowledge layer

Documentation that outlives the ticket and is readable by anyone working in this context.

**Draft the entries now; APPLY them only after Step 8's task-repo push succeeds** — the
close commit is authoritative and a failed knowledge write must never block or reorder it.

**Destination mechanics:** `.dotcortex/knowledge/` is a GENERATED resolved view
(per-file symlinks) — never create files directly in it. Writes go to the layer:
- **Existing file:** check WHICH layer the resolved symlink points to first
  (`readlink .dotcortex/knowledge/<file>`). If it resolves to `layers/team/`, edit
  through it. If it resolves to `layers/org/` (no team override yet), do NOT write
  through it — copy the file to `.dotcortex/layers/team/knowledge/<file>`, append the
  entry there, and rebuild views (the team copy now overrides org and carries the rollup).
- **New file:** create it in `.dotcortex/layers/team/knowledge/` (the team/local layer —
  create the directory if this is the first entry), then run
  `.dotcortex/bin/rebuild-views.sh --root .` so the view republishes it.
- **Team remote connected:** the layer is a checkout — the capture commit uses the same
  pull → scoped add → commit → push transaction as tasks, retried on rejection. Learnings
  roll up so future agents inherit them without excavating closed projects.
- **No team remote:** the layer write is a plain local file edit; nothing to push.

**Store when the ticket reveals:**
- A technical gotcha that would bite someone again
- A non-obvious design decision with rationale
- A new script, command, or operational procedure
- A pattern that should be followed going forward
- A scope intentionally deferred at the code level

Write concise entries (2–5 lines each) to the appropriate knowledge file with `**Ref:** {{TICKET_PREFIX}}-XXX` backlinks, plus the date and the code evidence behind the claim.

Descriptive facts and verified decisions commit directly. Normative rules ("always do X")
are not knowledge entries — propose them as a skill/command/policy change instead.

### 4b. Cross-session project context → assistant auto-memory

If the assistant supports auto-memory, it is a `memory/` directory whose index `MEMORY.md` is autoloaded into every session's context. Sibling files in that directory are referenced from the index but are not autoloaded — they're pulled in when a topic is relevant. Skip this section entirely if the assistant has no memory support.

**Store when the ticket reveals** (write here IN ADDITION to the knowledge layer if both apply):
- A cross-cutting scope decision that took real effort to reach (e.g., v1 direction for a whole feature)
- Context a future session would need to carry forward, not rediscover from code
- A deferred item whose deferral rationale matters (not just "we decided not to")
- A load-bearing invariant or contract that spans multiple tickets

For each such item:
1. Create or update a memory file in the auto-memory directory with frontmatter (`name`, `description`, `type: project | feedback | user | reference`) and the body structured per memory guidelines.
2. Add (or update) a one-line pointer in `MEMORY.md` so it's discoverable from the autoloaded index. `MEMORY.md` gets a routing pointer or a genuinely cross-cutting hot-context line — the substance lives in the knowledge file.
3. Include cross-references to any knowledge-layer files that hold the deeper technical detail.

**Skip silently when:**
- Straightforward implementation (no surprises)
- Knowledge already captured in code, existing docs, or an existing memory file
- Session-specific context that won't matter after the ticket ships

**Verify before asserting.** Memory is point-in-time. If you're extracting from ticket prose, the claims were true when written but may not be now. Check current code before writing an entry that makes strong claims about behavior or file paths. If knowledge and current code conflict, code wins and the knowledge gets corrected.

If the extraction write fails (no push access to the context repo, network down), leave a
visible pending-extraction marker and continue — or open a PR instead. A failed extraction
never fails the close.

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
commit the close (ticket move + tracking-file updates) and push — one scoped
transaction for the whole close:

```bash
git -C {{TASKS_DIR}} add <only-the-files-this-close-touched>
git -C {{TASKS_DIR}} commit -m "$ARGUMENTS: close"
git -C {{TASKS_DIR}} push || { git -C {{TASKS_DIR}} pull --rebase && git -C {{TASKS_DIR}} push; }
```

Stage ONLY the files this close touched — parallel sessions leave unrelated
dirty files in this repo; never `git add -A` blindly, and never commit files
you didn't change. On push rejection, `git pull --rebase` and retry once.

This commit is the authoritative close. Once it has pushed, apply the drafted
knowledge entries (Step 4a — team-layer capture transaction or plain project
file edit), then proceed to Step 8b. If a follow-up is still pending, say so in
the report rather than reopening the close.

## Step 8b: Linear (last, after the authoritative commit)

> **Linear:** If the Linear MCP is available in this session, set the ticket's linked issue to Done. If the project config enables Linear (`config.linear.enabled`) but the MCP is not connected, pause and ask the user to connect it (continue markdown-only only at their explicit word). If Linear is not configured, skip this step silently.

If the issue update fails, record a pending-sync note as its own scoped follow-up
transaction (the archived ticket file is the exact path: `git -C {{TASKS_DIR}} add <archived-ticket> && git -C {{TASKS_DIR}} commit -m "$ARGUMENTS: pending Linear sync" && git -C {{TASKS_DIR}} push`).
A failed follow-up never undoes or duplicates an already-valid close; the next status
touch retries the Linear update and clears the marker.

## Step 9: Report

Summarize what was done:

```
Marked $ARGUMENTS done and archived to archive/YYYY-MM/
```

Include:
- Whether knowledge was extracted (to which file, and whether it landed in the team layer or the project's own knowledge dir)
- Whether an auto-memory entry was written or updated (and whether `MEMORY.md` was re-indexed)
- Whether a parent ticket was updated
- Which tracking files were updated (BACKLOG.md / TODO.md / any other board) and which had no reference
- Whether the PM repo was pushed
- Whether the linked Linear issue was set Done, or why it wasn't
- Any warnings (e.g., "parent {{TICKET_PREFIX}}-XXX still has 2 open subtasks", or a pending extraction/sync marker)

---

**Remember:**
- Honor `config.workflow_policy.ticket_close`: `auto` → execute the workflow without asking; `ask` → confirm with the user before Step 2, then execute without further pauses
- Do not start servers or run tests
- If anything looks wrong (missing ticket, open subtasks), report and stop rather than guessing

Arguments: $ARGUMENTS
