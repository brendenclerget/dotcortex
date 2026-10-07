---
name: orchestrator
description: Run a live working session as an orchestrator - the main session plans, reviews, tickets, merges and reports while background agents build tickets in their own git worktrees. Use at the start of a working session, when the engineer says "let's work", "/session", "dispatch agents", "run these in parallel", or asks to plan, ticket and build several pieces of work at once.
---

# Orchestrator: how a working session runs

The main session is the **orchestrator**. It keeps its own context light and doesn't build
features itself (one-line fixes excepted). It plans, gets reviews, writes tickets, dispatches
agents, merges and reports. Background agents do the building, each on one ticket in its own git
worktree, following the shared brief (`agent-brief.md`, beside this file).

## 0. Settings it reads

| Setting | Where | Default |
|---|---|---|
| Component repos | `config.component_repos` in `.dotcortex/config.json` (paths from the workspace root) | the workspace itself |
| Worktree root, branch prefix, max agents | `.dotcortex/layers/team/policy/orchestration.json`: `worktree_root`, `branch_prefix`, `max_agents` | `../<workspace>-wt`, `agent/`, `4` |
| Git autonomy | `config.git_autonomy` | `manual` |
| Crucial decisions | `workflow_policy.crucial_decisions` (CLAUDE.md, Workflow Policy) | `block` |
| Per-repo commands, ports, test DBs, generated and shared files | `.dotcortex/knowledge/agent-workspace.md` | none |

If `agent-workspace.md` is missing, draft it from `.dotcortex/templates/agent-workspace-template.md`
and a quick scan of each component (package scripts, Makefile, CI config). Ask the engineer to confirm
it, then commit it to the team layer:
`.dotcortex/bin/task-tx.sh --dir .dotcortex/layers/team --msg "knowledge: agent workspace" knowledge/agent-workspace.md`.
Agents depend on it for every build, test and server command.

## 1. Start of session: clear what's waiting
1. **Pull** every component repo (`git -C <component> pull --ff-only` when its tree is clean), the team
   layer (`.dotcortex/bin/task-tx.sh --dir .dotcortex/layers/team --pull-only`) and the tasks dir.
2. **Leftovers:** in each component, run `git worktree list` and `git branch --list '<branch_prefix>*'`.
   - Remove worktrees and branches that are already merged.
   - Report unmerged ones with no running agent as merge-or-discard questions. Never delete unmerged
     work without the engineer's answer.
3. **Boards** (when the `boards` pack is installed): apply the decision board first
   (`/decision-board-apply`), then the ticket board (`/ticket-board-apply`), then republish both.
   Answers that change running work go to those agents.
4. **Rundown,** as a table: running, ready to merge, queued (TODO.md order), and waiting on people.
   List what's waiting on the engineer in two numbered lists: their ticket asks, and open decisions.
   Include the team's tech-debt lists with `Needs a call: yes` entries (`/debt list`).
5. **Merging permission,** per `git_autonomy`:
   - `manual` or `commit`: never merge or push the default branch. Integrated work is left on a branch
     for the engineer; say which one.
   - `commit_push`: ask once: "Can I merge tested work to <default branch> this session?"
   - `commit_push_pr`: ask once, and open a PR per ticket instead of pushing the default branch.

Then enter implementing mode. The ticket board's **Agent queue** (unchecked criteria nobody is on,
in TODO.md order) is the session's to drain.

## 2. Implementing mode: the loop for any request

**Small** (copy, spacing, one component, a clear bug): make sure a ticket covers it (a follow-up
letter child is fine), then dispatch one agent. Skip reviews unless it touches a gated area (below).

**Anything non-trivial:**
1. **Draft a short plan** in the scratchpad from what exists: quick greps, not deep reads.
2. **Get it reviewed before building:**
   - With the `review` profile, run the cross-model reviewer read-only on the plan, in the
     background (see `/implement-review`, "Running a reviewer CLI reliably"). Ask for ranked, concrete
     changes, a word cap, the conservative option for each open question, and a numbered build plan.
   - Use the advisor tool, if the session has one, when architecture, money, security, auth or data
     models are involved. It settles sequencing and the boundaries agents must respect.
   - Save the reviews in the repo or ticket folder (never only in the scratchpad) and cite them on the
     ticket.
3. **Ticket it** with the ticket core (Assignee, Review, `ACn:` criteria, Needs from assignee). Split it
   into letter children when agents will work in parallel, one child per agent.
4. **Route questions:**
   - A question the work can't START without becomes a decision: an open entry in the team's decision
     log with options and a recommendation; the ticket cites `- Decision: D<n>`.
   - A question on work in flight is an ask on its ticket.
   - Escalate an in-flight question to a decision only when the answer changes other tickets.
   - One question, one place.
5. **Crucial calls are never the agent's** (policy, money, penalties, trust and safety, security and
   permissions, public rules or promises, anything hard to reverse). Follow
   `workflow_policy.crucial_decisions`:
   - `block`: build nothing for that piece. Record the question, mark the ticket BLOCKED on it (or split
     the blocked piece out and keep the rest moving), and list it first in the report.
   - `build_conservative`: build the most conservative, least-change option behind a setting, mark it
     Built today on the ask, and list it first.

   Presentation details (layout, spacing, component choice) aren't asks.
6. **Dispatch** one background agent per child (section 3), up to `max_agents` at once. Split work by
   disjoint files. For a large wave, one agent builds the shared pieces first (shared components,
   tokens, route stubs, renames) and that lands before the parallel agents start.
7. **Report** in plain language: what's running, what the engineer will see, and the calls they
   need to make.

**Review gates before merge:**
- Anything touching **money, auth, security, permissions or data migrations** gets a cross-model
  review of the branch diff (`git -C <component> diff <base>..<branch>`). Findings go back to the same
  agent with SendMessage.
- **Two fix rounds at most** (`/fix`, "Review depth"). After that, fix only what a normal user path or
  a likely failure triggers. Rare timing, race and crash-only findings become a hardening follow-up
  ticket, and the work merges. If an agent has been on review fixes for about an hour, stop and ticket
  what's left.

## 3. Dispatching agents

**Worktrees are per component repo.** For ticket `<id>` (lowercased), for each component it touches:
```bash
git -C <component> fetch -q
git -C <component> worktree add -q -b <branch_prefix><id> <worktree_root>/<id>/<component> origin/<default branch>
```
When the workspace is itself the repo, `<component>` is `.` and the path is `<worktree_root>/<id>/`.
Run each component's install step from `agent-workspace.md` in the new worktree. Don't symlink
dependency folders between worktrees: build caches collide.

At session start, copy `agent-brief.md` (beside this file) into the scratchpad as `BRIEF.md`.
**Every agent prompt** points at that brief and states:
- **Scope:** the ticket path; the worktree path(s) and branch; its own port(s) and its own test
  database name (recipes in `agent-workspace.md`); the reviews to read; the other agents working
  nearby and the files to stay out of.
- **Git:** commit on its branch only; never push, merge or rebase; commit messages start with the
  ticket id and end with the attribution line the session uses.
- **Tickets:** check the criteria it met, set Status REVIEW with the right Review value, and commit the
  ticket through the tasks transaction before reporting.
- **Crucial calls:** per the policy above, asked on its ticket and listed first in its report.
- **Progress file** (optional, for long waves): `<scratchpad>/progress/<id>.jsonl`, one JSON line per
  criterion event.

**While agents run:**
- Never read an agent's transcript; wait for its completion notice.
- SendMessage to a finished agent resumes it. A message that arrives just as an agent stops can be
  lost: if it doesn't resume, send it again.
- The scratchpad is per session. Anything a ticket references is copied into the repo before the
  session ends.

## 4. Merging (the orchestrator only, within git_autonomy)

1. **Integration worktree** per component: `<worktree_root>/integration/<component>`, detached at
   `origin/<default branch>`. Create it with `git -C <component> worktree add --detach` when missing.
   Merge one branch at a time: `git merge --no-ff <branch_prefix><id> -m "Merge <TICKET>: <title>"`.
2. **Conflicts:** keep both sides' intent. Never hand-merge generated files (lockfiles, schema dumps,
   generated API types, snapshots): regenerate them with the commands in `agent-workspace.md`.
   Duplicate migration versions go back to the agent to renumber.
3. **Test everything** the merged components need (the full suites in `agent-workspace.md`).
   **Read the result before pushing, and never chain the push onto a test command** (`test && push`
   pushes after a flaky pass, `test; push` pushes after a failure).
4. **Land it** per `git_autonomy`: push the default branch, or open the PR, or leave the integrated
   branch for the engineer and say so.
5. **The engineer's checkout:** fast-forward it only when its tree is clean (`git merge --ff-only`).
   Then run the post-merge steps from `agent-workspace.md` (dependency install, migrations, restarts)
   or tell the engineer which ones to run.
6. **Clean up:** remove merged worktrees and delete merged branches (`git worktree remove`,
   `git branch -d`). Unmerged ones without a running agent become merge-or-discard questions.
7. Tell the engineer what's live and anything they need to do.

## 5. Talking to the engineer
- **Lead with the outcome:** what's live, what's running, what needs them.
- Use tables for status. Number their decisions, each with the recommendation (and, under
  `build_conservative`, what's built today).
- **Relay agents' reports in plain language.** Surface their calls and risks; don't narrate plumbing.
- **Feedback on a screen or behaviour is a request:** ticket it, dispatch it, and say so.
- **Keep them unblocked without deciding for them.** Presentation choices with a sensible default:
  build them. Crucial calls: follow the policy and list them.

## 6. Tech debt found along the way
Small recurring problems an agent notices outside its ticket go on the team's tech-debt lists
(`/debt add`), not into new tickets. Check `/debt list` when planning a session's queue.

## End of session
- Stop servers the session started.
- Remove merged worktrees and branches.
- Copy anything tickets reference out of the scratchpad.
- Report what's still running, and what's waiting on whom.
