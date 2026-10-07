---
name: ticket-new
description: Create parent ticket with feature spec and subtask breakdown
argument-hint: <feature-name>
---

# Create Feature with Breakdown

Create a parent ticket for: $ARGUMENTS

## Step 0: Estimate Complexity First

**Before creating anything, assess scope:**

- **Tiny (< 1 hour):** Stop! Use `/pm new` instead - single ticket is enough
- **Small (1-4 hours):** Single ticket with checklist - use `/pm new`
- **Medium (4-8 hours / 1 day):** Parent ticket, maybe 2-3 subtasks - proceed
- **Large (multiple days):** Parent + 4-7 subtasks - proceed
- **Huge (week+):** Might need multiple parent tickets - discuss with user first

**If this seems like < 4 hours of work, stop and recommend `/pm new` instead.**

## Step 1: Establish the ticket identity

**Linear:** If the Linear MCP is available in this session, the ticket is named after a
Linear issue instead of an allocated counter number (the counter is left untouched). The
issue is created in Step 5b, once the ticket is drafted, so its summary is written from
the finished ticket (see **Linear issue content** below). If the project config enables
Linear (`config.linear.enabled`) but the MCP is not connected, pause and ask the user to
connect it (continue markdown-only only at their explicit word). If Linear is not
configured, skip it silently and allocate a number from the counter in Step 5b.

**Pure-markdown mode: allocation is DEFERRED.** Do not touch the counter now. Draft
the complete ticket content first (Steps 2–5), using `XXX` as an ID placeholder; the
allocation transaction in Step 5b turns the draft into a numbered file. Never read
the counter early and write it later — a gap between read and push hands two
sessions the same number.

**This step decides the identity source only** (a Linear issue or the counter, both resolved
in Step 5b). No file is created here — the ticket file lands inside the Step 5b transaction.

**Linear issue content** follows the `pm-agent` skill's Linear block (**Issue content**): the
title, a one- or two-sentence plain summary, status, assignee, priority, team labels and a pointer
back to the ticket. Never the criteria, asks, decisions, technical notes or logs.

## Step 2: Gather feature requirements

Ask user:
- Overview of feature (what and why)
- User stories (who wants what benefit)
- Priority (HIGH/MEDIUM/LOW)
- Assignee: the engineer who owns it and answers its questions (their email, or their name as it
  appears on claude.ai). Default: the user running this session. Agents never change it later.
- Any specific requirements or constraints
- **Why this needs breakdown** (confirm it's not just a single ticket)

## Step 3: Scope the design (default concise)

Use a short prompt like:
"Scope implementation for [$ARGUMENTS] with minimal overhead.

Consider:
- **Architecture approach** - How does this fit into existing system?
- **Data models** - What changes to API/database needed?
- **UI components** - What screens/components required?
- **Integration points** - What systems does this touch?
- **Testing strategy** - How to verify each piece?
- **Edge cases** - What can go wrong?
- **Dependencies** - What must be done first?

Aim for 3-5 major subtasks, not 10+ micro-tasks."

**Escalate to extended thinking only when needed:**
- Use `think hard` for medium complexity with unclear tradeoffs.
- Use `ultrathink` only for high-risk architecture or if user explicitly requests it.

## Step 4: Create parent ticket with spec

**Use the parent ticket template:**
```bash
cat .dotcortex/templates/parent-ticket-template.md
```

**Include:**
- The ticket core every board reads: `**Assignee:**`, `**Review:** none`, acceptance criteria as
  `- [ ] AC1: …` with stable ids (never renumbered; a new criterion takes the next number) that
  are observable outcomes, and `## Needs from assignee` saying `None.` (or explicit asks, in the
  template's format). A parent's criteria are outcomes of the whole feature, not "all subtasks done".
- Questions the work can't START without go into the team's decision log
  (`.dotcortex/layers/team/decisions/<log>.yml`, `team.yml` unless the engineer asked for a
  feature log) as open entries, and the ticket cites each one as `- Decision: D<n>` under Needs.
  Crucial calls (policy, money, security, public promises, anything hard to reverse) are never
  settled by the agent; follow `workflow_policy.crucial_decisions` (CLAUDE.md).
- Feature specification section (overview, user stories)
- Technical design (data models, UI/UX, dependencies)
- Testing plan
- Subtasks section (to be filled in step 5)

Draft the full content in memory/scratch — the file lands inside the Step 5b transaction with its real ID.

## Step 5: Break into subtasks

Ask: "Should I break this into subtasks?"

**Only create subtasks if:**
- You identified 3-5 major, separable steps
- Each step is substantial (2+ hours of work)
- Steps have clear boundaries
- User confirms breakdown makes sense

**If yes:**
- Create folder `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/`
- Move parent ticket into the folder
- Identify 3-5 implementation steps
- Name subtasks with letter suffixes: {{TICKET_PREFIX}}-XXXa, {{TICKET_PREFIX}}-XXXb, {{TICKET_PREFIX}}-XXXc, etc.
- Create child ticket for each from `.dotcortex/templates/child-ticket-template.md`:
  `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/{{TICKET_PREFIX}}-XXXa-description.md`, with `**Type:** SUBTASK`,
  `**Parent:** {{TICKET_PREFIX}}-XXX` (authoritative: boards derive the family from it), the parent's
  Assignee unless the user names another, `**Review:** none`, and its own `ACn` criteria
- **Do NOT read or increment the ticket counter for subtasks** — letter subtasks don't
  consume numbers, and they get no Linear issue (top-level tickets only)
- Link children in parent ticket

**Each subtask should:**
- Be completable in one focused session
- Have its own testable deliverable
- Be independently mergeable if possible

**Bad subtasks (too small):**
- "Update imports"
- "Fix TypeScript errors"
- "Add tests" (part of every task)

**Good subtasks (substantial, separable):**
- "Build API endpoints for listings"
- "Create listing card component with image/price display"
- "Implement search/filter logic with query params"

## Step 5b: The allocation transaction (pure-markdown mode)

With the full draft ready (parent + any letter-child drafts + the BACKLOG row), run
ONE transaction that allocates the ID and lands everything.

**Pre-flight:** `.ticket_counter` and `BACKLOG.md` must be CLEAN before you start
(`git -C {{TASKS_DIR}} status --porcelain -- .ticket_counter BACKLOG.md` empty). If
another session left them dirty, stop and surface it — the rollback below is only
safe because every change to those files is provably this transaction's own.

**Take the shared transaction lock** — the same lock `task-tx.sh` uses — so parallel
sessions on this checkout serialize and cannot read the same counter value (bounded
wait; a lock held past the timeout means a crashed session — surface it, don't delete
it yourself):

```bash
LOCKDIR="$(git -C {{TASKS_DIR}} rev-parse --absolute-git-dir)/dotcortex-tx.lock"
tries=0
until mkdir "$LOCKDIR" 2>/dev/null; do
  tries=$((tries+1)); [ $tries -ge 60 ] && { echo "lock held too long: $LOCKDIR"; exit 1; }
  sleep 1
done
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

attempt=0
until [ $attempt -ge 5 ]; do
  attempt=$((attempt + 1))

  # 1. Pull (always start from remote truth)
  git -C {{TASKS_DIR}} pull --rebase

  # 2. Allocate from the freshly pulled counter (sanity-check against existing files)
  NEXT=$(cat {{TASKS_DIR}}/.ticket_counter)
  HIGHEST=$(ls {{TASKS_DIR}}/{{TICKET_PREFIX}}-*.md {{TASKS_DIR}}/{{TICKET_PREFIX}}-*/ 2>/dev/null | grep -o '{{TICKET_PREFIX}}-[0-9]*' | sed 's/{{TICKET_PREFIX}}-//' | sort -n | tail -1)
  [ -n "$HIGHEST" ] && [ "$HIGHEST" -ge "$NEXT" ] && NEXT=$((HIGHEST + 1))
  TICKET="{{TICKET_PREFIX}}-$(printf '%03d' "$NEXT")"
  TICKET_FILE="$TICKET-<slug>.md"          # exact filename — no globs anywhere below

  # 3. Write the drafted content under the real ID (file or family folder),
  #    update the counter, add the BACKLOG row
  #    ... write {{TASKS_DIR}}/$TICKET_FILE (and $TICKET/ children if any) ...
  echo $((NEXT + 1)) > {{TASKS_DIR}}/.ticket_counter

  # 4. Stage EXACT paths (tasks-dir-relative — never a glob, never -A), commit, push
  git -C {{TASKS_DIR}} add .ticket_counter "$TICKET_FILE" BACKLOG.md   # or "$TICKET/" for a family folder
  git -C {{TASKS_DIR}} commit -m "$TICKET: create ticket" -- .ticket_counter "$TICKET_FILE" BACKLOG.md   # pathspec: pre-staged unrelated entries stay out (use "$TICKET/" for a family)
  git -C {{TASKS_DIR}} push && { echo "Created $TICKET"; break; }

  # 5. Push rejected: roll back ONLY this transaction's own artifacts, then retry.
  #    Sanctioned exception to the ask-before-destructive-git rule: the lock is
  #    held, so no other session can have task-tx work in flight; every path
  #    below was written by THIS transaction in step 3 and is regenerated on
  #    the next attempt. Nothing that predates the lock acquisition is touched.
  git -C {{TASKS_DIR}} reset --soft HEAD~1
  git -C {{TASKS_DIR}} restore --staged .ticket_counter BACKLOG.md
  git -C {{TASKS_DIR}} restore --staged "$TICKET_FILE" 2>/dev/null || true   # whichever of the two
  git -C {{TASKS_DIR}} restore --staged "$TICKET/"    2>/dev/null || true   # exists (file vs family)
  git -C {{TASKS_DIR}} checkout -- .ticket_counter BACKLOG.md   # undo OUR step-3 edits only
  rm -rf "{{TASKS_DIR}}/$TICKET_FILE" "{{TASKS_DIR}}/$TICKET"/  # the files WE just created (file OR family folder)
done
```

The `trap` releases the lock when the command finishes (success or failure).

**If all 5 attempts exhaust** (pathological contention): release the lock, keep the
drafted content in scratch, and report the failure with the draft location — never
leave partial files in the tasks dir. **No remote configured** (solo/local mode):
skip the pull and push lines; the commit alone completes the transaction.

Letter subtasks created here ride inside the same transaction (same family folder,
same commit) — they consume no counter numbers and never get their own transaction.
**Linear mode:** create the Linear issue first, inside the lock, with only the content
allowed above, then run the same transaction with `TICKET` = the issue identifier and without
the counter lines. If the transaction exhausts its attempts, say that the Linear issue exists
without a ticket file and give its identifier.

**Update parent ticket with subtask list** (checked against the children's `Parent:` fields):
```markdown
### Subtasks
- [ ] {{TICKET_PREFIX}}-XXXa: First step description
- [ ] {{TICKET_PREFIX}}-XXXb: Second step description
- [ ] {{TICKET_PREFIX}}-XXXc: Third step description
```

## Summary Report

After creation, provide:
```markdown
Created {{TICKET_PREFIX}}-XXX: [Feature Name]

**Feature:** [Brief description]
**Subtasks:** X created
- {{TICKET_PREFIX}}-XXXa: [Description]
- {{TICKET_PREFIX}}-XXXb: [Description]

**Next step:** Start with {{TICKET_PREFIX}}-XXXa (recommend this one because...)
```

---

**Remember:**
- Default to fewer, larger subtasks rather than many tiny ones.
- **Always update `{{TASKS_DIR}}/BACKLOG.md`** after creating tickets — add entries to the appropriate priority section.

Arguments: $ARGUMENTS
