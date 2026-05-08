---
name: ticket-audit
description: Generate a structured audit prompt for reviewing a completed ticket's implementation
argument-hint: <PREFIX-XXX>
---

# Audit Ticket Implementation

Produce a self-contained audit prompt for ticket **$ARGUMENTS** that can be pasted into a separate review LLM (e.g., Codex, a fresh Claude session, GPT) for an independent code review.

The output is a **prompt**, not a review. Don't perform the audit yourself — generate the artifact.

## Step 1: Locate the ticket

```bash
find TASKS_DIR -name "$ARGUMENTS*"
```

Search both `TASKS_DIR/` and `TASKS_DIR/archive/` — audits typically run on `REVIEW` or `DONE` tickets.

Handle both layouts:
- **Simple ticket:** `TASKS_DIR/PREFIX-XXX-name.md`
- **Parent directory:** `TASKS_DIR/PREFIX-XXX/PREFIX-XXX-name.md`

## Step 2: Sanity-check status

Read the `Status:` field:
- `IN_PROGRESS`, `REVIEW`, `DONE` → proceed
- `TODO`, `BACKLOG`, `PLANNING`, `BLOCKED` → warn the user that implementation hasn't started or is paused, and confirm before generating the prompt

## Step 3: Identify the target repo

Many projects route different ticket prefixes to different code repos (frontend / backend / service). Determine the target repo by:
- Reading `Repo:` / `Target Repo:` if present in ticket frontmatter
- Otherwise inferring from the prefix and the project's CLAUDE.md (e.g., `HACKFE-` → frontend repo)
- If unclear, ask the user before continuing

Note the branch the work lives on (typically a feature branch or shared hackathon branch — check ticket metadata or recent git log).

## Step 4: Gather implementation context

From the ticket, collect:
- Every file in the **File Targets** / **Files to Modify** section
- Any **new** files implied by the ticket's directory structure or component lists
- Adjacent test files (look for `.test.*` siblings of the modified files)
- **Reference pattern files** the ticket cites (e.g., "follow the pattern from X.ts") — the reviewer needs these to compare

Use the codebase to confirm files actually exist where the ticket said they would. Note any discrepancies — they're worth surfacing in the audit.

## Step 5: Pull the project rules

Read the target repo's `CLAUDE.md` (or `AGENTS.md`) and extract the **non-negotiable rules** relevant to this ticket:
- Forbidden imports
- Required patterns (state management, styling, etc.)
- Required checks (typecheck, lint, test commands)
- Naming conventions
- Anything called out as "non-negotiable"

The audit prompt should embed these so the reviewer has them inline — don't assume the reviewer will fetch them.

## Step 6: Generate the audit prompt

Output a markdown code block (so the user can copy-paste verbatim) with this structure:

````markdown
# Audit: $ARGUMENTS — {Ticket Title}

## Objective

Review the implementation of $ARGUMENTS against the specification below. Evaluate completeness, accuracy, code quality, and adherence to codebase patterns. Produce a structured report.

## Repo & Branch

- **Repo:** {repo path or name}
- **Branch:** {branch name}

## Files to Read

### Changed / new files
1. `path/to/file.ts` — {brief description}
2. ...

### Test files
1. `path/to/file.test.ts`
2. ...

### Reference patterns (read for comparison)
1. `path/to/reference.ts` — pattern this ticket follows
2. ...

---

## Ticket Specification

{paste the full ticket — description, acceptance criteria, implementation notes — verbatim, no summarization}

---

## Non-Negotiable Rules (from project CLAUDE.md)

{paste the relevant rules verbatim}

---

## Audit Sections

{generate one section per logical area of the implementation — e.g., Types, API endpoint, Hook, Component, Tests. Match the ticket's structure. For each:}

### {Section Name}
- Read: {specific files for this section}
- Verify: {what to check against the spec}
- Pattern check: {which reference file to compare against, if any}

### Code Quality Checks
- {one bullet per non-negotiable rule, phrased as a check}
- Naming conventions match the surrounding codebase
- No prohibited imports
- Tests cover the acceptance criteria

---

## Required Output

# $ARGUMENTS Audit Report

## Summary
- **Overall:** PASS / PASS WITH NOTES / FAIL
- **Criteria met:** X/{total}
- **Issues:** X critical, X minor

## Detailed Findings
{one entry per audit section, with PASS/FAIL + notes}

## Acceptance Criteria Checklist
{checkbox list of every criterion}

## Recommended Actions
{ordered list of fixes / follow-ups}
````

## Step 7: Output

Print the prompt as a single fenced code block. Do not editorialize or add commentary outside the block — the user wants something they can paste directly.

## Guidelines

- **Specific over generic.** Real file paths, real reference patterns, real rules. No `{placeholder}` text in the final prompt — fill everything in.
- **Don't summarize the ticket.** Paste it verbatim. The reviewer is the source of truth; you're the courier.
- **Match audit sections to actual implementation.** A 3-area ticket gets 3 sections, not a generic 5-section template.
- **Embed project rules inline.** Don't make the reviewer fetch CLAUDE.md.
- **One ticket per audit.** If the user passes a parent with subtasks, audit the parent's coordination/glue work and recommend running `/ticket-audit` on each subtask separately.

Arguments: $ARGUMENTS
