---
name: implement-review
description: Implement a dotcortex ticket end-to-end, then dispatch a single one-shot cross-model review (coordinator-model work → cross-model reviewer, and vice versa) and present implementation + review together
argument-hint: <{{TICKET_PREFIX}}-XXX>
---

# Implement Ticket + Cross-Model Review

Implement ticket: **$ARGUMENTS**

Run the full workflow below in order. The end state is: ticket implemented, one independent review from the *other* model family completed, and everything presented to the user in a single report. Do NOT commit, do NOT start servers or run the apps, and do NOT apply review fixes — the user decides what to act on.

## Step 0: Identify yourself (determines the reviewer)

Determine which model family is running this skill:

- **You are the coordinator model family** → your reviewer is the cross-model reviewer, dispatched via `{{REVIEWER_CLI}}` (`{{REVIEWER_MODEL}}`, high reasoning).
- **You are the reviewer model family** → your reviewer is the coordinator model, dispatched via `{{COORDINATOR_CLI}}` (`{{COORDINATOR_MODEL}}`).

The review is always cross-model. Never review your own work with your own model family.

## Step 1: Locate and read the ticket

```bash
find {{TASKS_DIR}} -name "$ARGUMENTS*" -not -path "*/archive/*"
```

Handle both layouts:
- Simple ticket: `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX-name.md`
- Parent directory: `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/{{TICKET_PREFIX}}-XXX-name.md`

If not found, check the archive (it may already be closed) and stop with a report. If it's a parent with open subtasks, ask which subtask to implement rather than doing the whole parent blind — unless the ticket is small enough to do in one pass.

Read the full ticket: requirements, acceptance criteria, implementation checklist, technical notes.

## Step 2: Read mandatory context

Before writing any code, read the project's knowledge/skill routing table and follow it:
- The always-read knowledge files (patterns/gotchas, project standards)
- The skill file for the area the ticket touches, per the routing table
- Any other knowledge file the ticket's domain touches

## Step 3: Implement

Implement the ticket completely. Rules (these mirror the repo's agent instruction files and are not optional):
- No servers, no `curl`, no running tests — user validates
- No commits, no pushes
- Match existing code conventions in each component
- Update the ticket file as you go: set `Status: IN PROGRESS`, check off implementation-checklist items you complete

## Step 4: Build the review packet

The repo root is NOT a git repo — each component ({{COMPONENT_REPOS}}) is its own git repo. For each component you touched, collect:

```bash
git -C <component> status --porcelain
git -C <component> diff
```

Write a single review packet file to `${TMPDIR:-/tmp}/implement-review-$ARGUMENTS.md` containing, in order:
1. The full ticket text (requirements + acceptance criteria)
2. A one-paragraph summary of your implementation approach and any deliberate deviations from the ticket
3. Per-component: the full `git diff` output
4. Full contents of any NEW (untracked) files, since `git diff` won't show them
5. Absolute paths of every touched file, so the reviewer can open surrounding code

Note: the working tree may contain unrelated uncommitted changes from other sessions. Only include hunks/files from YOUR work in the packet; list anything you excluded.

## Step 5: Dispatch exactly ONE review pass

**No second model family → SKIPPED, never a same-model substitute.** Before dispatching, confirm the
opposite family's CLI is configured (`{{REVIEWER_CLI}}` / `{{COORDINATOR_CLI}}`, whichever is the
reviewer for this run) and actually installed and runnable on this machine. If it is not configured,
not installed, or cannot be launched, **report the review as SKIPPED** — state which CLI was missing
and that the implementation is unreviewed. Do NOT fall back to reviewing the work with your own model
family, a subagent of your own family, or a self-review pass; a same-model review is never a valid
substitute for the cross-model review.

Both commands below are a single non-interactive run — no follow-ups, no back-and-forth. Use a generous timeout (10 minutes); a high-reasoning review of a real diff is slow. If the sandboxed shell blocks the CLI's network access, rerun the dispatch with sandbox disabled (it only needs network + read access).

Review prompt (same for both reviewers — substitute the packet path):

> You are a one-shot senior code reviewer. Read the review packet at `<PACKET_PATH>` — it contains a ticket, an implementation summary, and the full diff. You have read-only access to the repos under the project workspace root to inspect surrounding code. Judge: (1) does the diff satisfy the ticket's acceptance criteria, (2) correctness bugs, (3) violations of conventions visible in surrounding code, (4) anything risky or missing. Do NOT edit anything. Output exactly this structure: `VERDICT: APPROVE | APPROVE WITH NITS | REQUEST CHANGES`, then `BLOCKING:` (numbered, with file:line), then `NON-BLOCKING:` (numbered), then `ACCEPTANCE CRITERIA:` (each criterion → met/not met/can't verify). Be specific and terse.

**If you are the coordinator model → cross-model reviewer:**

```bash
{{REVIEWER_CLI}} <read-only, non-interactive flags> \
  -m {{REVIEWER_MODEL}} <high-reasoning flag> \
  -o "${TMPDIR:-/tmp}/implement-review-$ARGUMENTS-verdict.md" \
  "<REVIEW PROMPT>"
```

The verdict lands in the `-o` file; read it from there (stdout also streams the run).

**If you are the reviewer model → coordinator-model reviewer:**

```bash
{{COORDINATOR_CLI}} -p --model {{COORDINATOR_MODEL}} \
  --allowedTools "Read,Grep,Glob" \
  "<REVIEW PROMPT>" \
  > "${TMPDIR:-/tmp}/implement-review-$ARGUMENTS-verdict.md"
```

Dispatch the reviewer ONCE. If the command itself fails to launch (bad flag, network), fix the invocation and retry — but never send the reviewer a second review round, and never argue with its verdict.

## Step 6: Record in the ticket

Append to the ticket file:
- `## Work Log` entry: date, what was implemented, files touched
- `## Review` section: which model reviewed, verbatim `VERDICT` line, and the blocking items (if any).
  If the cross-model review was skipped per Step 5, record `VERDICT: SKIPPED (no second model family
  configured)` and name the missing CLI
- Set `Status: IN REVIEW` (the user marks DONE after validating — do not close or archive the ticket)

## Step 7: Present everything

Your final report to the user must contain ALL of the following — do not make them ask:

1. **What was implemented** — summary + per-component file list
2. **The full diff** (or, if very large, the diff of the core changes plus the packet path for the rest)
3. **The reviewer's verdict, verbatim** — the whole structured output, clearly attributed (name the reviewing model and its reasoning setting). If the review was SKIPPED, say so plainly at the top of the report along with the missing CLI — never present unreviewed work as reviewed
4. **Your take on each blocking/non-blocking finding** — agree / disagree and why. Do NOT apply any fixes; the user decides.
5. Ticket status + packet/verdict file paths

Arguments: $ARGUMENTS
