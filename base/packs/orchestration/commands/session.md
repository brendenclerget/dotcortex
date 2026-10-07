---
name: session
description: Start a working session - clear the boards, give a status rundown, then run implementing mode (orchestrator plus background agents in worktrees)
argument-hint: "[focus for the session]"
---

# Working session

Load the `orchestrator` skill and follow it. The engineer's focus for this session: $ARGUMENTS (if
empty, start from the boards and the TODO queue; don't ask for a focus).

1. **Setup:**
   - Read the settings in the skill's section 0. Draft `agent-workspace.md` if it's missing.
   - Copy the skill's `agent-brief.md` to `<scratchpad>/BRIEF.md`, and create `<scratchpad>/progress/`.
   - Pull the component repos, the team layer and the tasks dir. List leftover worktrees and agent
     branches.
2. **Clear the boards** (when the `boards` pack is installed): apply the decision board, then the
   ticket board, then republish both. Flag anything contradictory or unclear.
3. **Rundown:** running, ready to merge, queued, and waiting on people, as a table; then the
   engineer's open asks and decisions as numbered lists.
4. **Ask once** about merging, per `git_autonomy` (skill section 1, step 5).
5. **Implementing mode:** plan, review, ticket, dispatch, review gates, merge and report, as the skill
   describes.
