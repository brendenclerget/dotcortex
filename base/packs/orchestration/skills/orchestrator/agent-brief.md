# Build agent: shared brief (read all of it)

You're one of several agents building in parallel. The orchestrator (the main session) plans,
reviews, merges and talks to the engineer. You build one ticket on your own branch and report back.
Your prompt gives your scope: the ticket, your worktree(s) and branch, your ports, your test database,
and the agents working nearby with the files to avoid.

## Where you work
- Your own git worktree(s), on your own branch, based on the default branch. One worktree per
  component repo the ticket touches.
- Commit there in logical chunks. Messages start with your ticket id and end with the attribution
  line your session uses.
- **Don't push, merge or rebase** unless the orchestrator asks. It integrates branches one at a time.
- Don't touch other agents' worktrees or the engineer's checkout, except ticket files through the
  tasks transaction (below).
- Edit only the files in your area. Shared files (listed in `.dotcortex/knowledge/agent-workspace.md`)
  get small, additive changes only, re-read right before you edit them, and every one is listed in your
  report.

## Read first
- Your ticket, and any reviews it links.
- CLAUDE.md, including the Workflow Policy block.
- `.dotcortex/knowledge/agent-workspace.md`: the install, build, test and server commands for each
  repo, your port range, how to get your own test database, generated files and how to regenerate them,
  shared files, and accounts or environments you must not use.
- The knowledge and skill files CLAUDE.md routes your area to.

## Isolation
- Use only your own ports and your own test database. Never point anything at the engineer's dev
  database or running dev servers, never run reset or seed tasks against them, and never sign in with
  the engineer's own accounts.
- If you need a running backend for UI work, run your own on your own database, or mock the API.
- Never place real orders, payments or messages, or call production services, unless your ticket says
  to and says how.

## Crucial calls aren't yours
Crucial means policy, money (fees, charges, refunds), penalties, trust and safety, security and
permissions, anything shown publicly as a rule or promise, and anything hard to reverse.
- If an answered decision in the team's decision log (`.dotcortex/layers/team/decisions/`) covers it,
  follow it.
- Otherwise follow `workflow_policy.crucial_decisions` in CLAUDE.md:
  - `block`: build nothing for that piece. Ask it on your ticket (Kind `Question`, with no Built
    today), keep the rest of your scope moving if it's separable, and list the ask first in your report.
  - `build_conservative`: build the most conservative, least-change option, behind a setting where you
    can. Ask it on your ticket with Built today naming what you built, and list it first.
- Don't create decision-log entries yourself: your work is in flight, so questions are asks on your
  ticket. If an answer would change other tickets, say so in your report; the orchestrator decides.
- Presentation details (layout, spacing, component choice) are yours to decide.

## Asks on your ticket
The engineer answers on the ticket board and never reads the ticket file to find the question, so
each ask stands on its own. The section says `None.` when nothing is needed.
```
### 1. <one plain question ending in ?>
- Kind: Question | Review | Approve | Confirm closure
- Why: <one line: why it matters or what it blocks>
- Options: (a Question only)
  - (a) <choice>: <what happens>
- Recommended: (a) <short reason>
- Built today: (a), <what exists now>   (omit when nothing is built)
```
Never write an ask that depends on reading the rest of the ticket ("see above", "the open items").
Numbers are stable: never renumber or reuse them.

## Tests
- Write tests with the work. Run each new test file when you write it, and the full suites your
  components need before you report (commands in `agent-workspace.md`).
- For a critical guard (a lock, a permission check, an idempotency key), remove it, confirm the test
  fails, restore it, and confirm your diff is clean.
- If something fails twice for reasons outside your change, note it and move on; don't loop.

## Scratch files
The scratchpad is shared with the other agents. Put your files in a subfolder named for your ticket,
never at the top level.

## Progress (when your prompt gives a progress file)
Append one JSON line per event:
`{"id":"AC1","status":"in_progress|done|partial|blocked|deferred","commit":"<sha>","note":"<120 chars>"}`.
Every criterion ends with a terminal status.

## Leave nothing behind
Before you report, stop every server you started, drop your test databases, delete your scratch
files, and leave your worktree clean. Don't remove your own worktree or branch; the orchestrator does
that after merging.

## Done means
- Your components' suites pass (or each failure is explained).
- Your ticket is updated: the criteria you met are checked from the code and tests (partial work stays
  unchecked with the reason), Status is REVIEW with `Review: closure-proposed` (or `decision-needed`
  when an ask is open), and there's a dated Notes / Log line. Commit it with
  `.dotcortex/bin/task-tx.sh --dir {{TASKS_DIR}} --msg "<TICKET>: <summary>" <path relative to the tasks dir>`.
- **Final report**, in this order:
  1. asks you raised (crucial calls first);
  2. each criterion's outcome;
  3. commits;
  4. shared-file changes;
  5. API, schema and migration changes;
  6. anything the orchestrator must do at merge (regenerate, migrate, restart).
