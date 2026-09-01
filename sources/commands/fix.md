---
name: fix
description: Paste review findings from another agent — verify them against the current tree, plan fix lanes, then execute with subagents and report per-finding dispositions
argument-hint: <pasted findings from another agent's review>
---

# Fix Pasted Findings (coordinator-model only)

**COORDINATOR-MODEL-ONLY COMMAND.** If you are not the configured coordinator model (e.g., this is
running under a different model family's CLI), STOP immediately and tell the user `/fix` is
coordinator-model only. Do not attempt the workflow.

**Role split (non-negotiable):** the invoking coordinator model is the
**coordinator** — it ingests, verifies, plans, dispatches, reviews, and reports. All substantive
code edits are executed by **subagents** (Agent tool). The coordinator may
hand-apply only trivial residuals (a typo, a missed import) found while reviewing agent output.

## Input

Findings arrive pasted in `$ARGUMENTS` or in the invoking message — any format (review verdict
blocks, numbered lists, prose, ReportFindings JSON, reviewer transcript excerpts). **Assume they come
from another agent** that reviewed work in this workspace; do not ask where they came from. If no
findings are present anywhere, ask the user to paste them and stop.

## Step 1 — Normalize

Parse the paste into a numbered findings table: `# | file(:line) | claim | severity (blocking /
non-blocking / nit)`. Preserve the reviewer's own severity labels when present. Drop pure praise
and verdict boilerplate; keep every actionable claim, including ones that look wrong.

## Step 2 — Verify against the CURRENT tree (before any fixing)

Another agent's findings are frequently stale in this multi-session workspace — the code may have
moved since they reviewed. Read the actual code for every finding and classify:

- **CONFIRMED** — the defect exists in the current tree → gets fixed
- **STALE** — already fixed or the code has changed out from under the finding → no action
- **REJECTED** — the reviewer misread the code; record the one-line rebuttal with file:line
- **NEEDS-USER** — real, but fixing requires a product/design decision, a schema/prod-data
  change, or anything destructive → do NOT fix; surface it in the report

Also snapshot `git -C <component> status --porcelain` for every component so you know which dirty
files belong to other sessions — those files are **untouchable**; a finding whose fix lands in
another session's dirty file becomes NEEDS-USER (coordination), not a silent edit.

## Step 3 — Mandatory context

Before planning, read the project's knowledge/skill routing table and follow it: the always-read
knowledge files (patterns/gotchas and project standards) plus the skill and knowledge files for
each area the confirmed findings touch. List these paths in each agent's prompt — agents must read
them too.

## Step 4 — Plan the lanes

Group CONFIRMED findings into work lanes with **zero file overlap** between lanes (typically by
component, splitting further only when files don't intersect). One subagent per lane. Present
the plan briefly (lane → findings → files) in your running commentary, then proceed — do not wait
for approval; NEEDS-USER items are already carved out.

## Step 5 — Execute with subagents

Dispatch all lanes in parallel via the Agent tool. Each agent prompt must
include: the verbatim findings for its lane (with file:line), the fix intent per finding, the
mandatory context file paths from Step 3, the list of untouchable dirty files, and these rules —
no servers, no tests, no `curl`, no commits/pushes, match surrounding conventions, return a
per-finding summary of exactly what was edited (file:line) and anything it chose not to do.

## Step 6 — Coordinator review

After each agent returns, read its diff (`git -C <component> diff` scoped to its files) and check
every finding in its lane is actually resolved and nothing out-of-lane was touched. Substantive
gaps go back to a subagent (same lane, one redispatch); trivial residuals you may fix directly.

## Step 7 — Report

Final message must contain, without being asked:

1. Disposition table: `# | finding | verdict (CONFIRMED-FIXED / STALE / REJECTED / NEEDS-USER) |
   files touched` — every pasted finding accounted for, none silently dropped
2. Rebuttals for REJECTED, decisions needed for NEEDS-USER
3. Per-component summary of the diff (files + what changed), noting it is uncommitted
4. Anything an agent declined or a redispatch couldn't close

**Never** commit, push, run tests/servers, create tickets, or touch `{{TASKS_DIR}}` state as
part of this command. If a related open ticket exists, append a one-line work-log entry to it;
otherwise the report is the record. The user validates and decides what to commit.

Arguments: $ARGUMENTS
