---
name: pm
description: Project management ticket system commands
---

# PM Commands

Available commands:

## Task Management
- `/pm new <description>` - Create a single ticket (auto-assigns {{TICKET_PREFIX}}-XXX). **Always one ticket, never subtasks.** If the description suggests a multi-day feature, create the single ticket and recommend: "This looks like it needs breakdown — run `/ticket-breakdown {{TICKET_PREFIX}}-XXX` when ready."
- `/pm start {{TICKET_PREFIX}}-XXX` - Mark task as in-progress, create branch
- `/pm done {{TICKET_PREFIX}}-XXX` - Mark complete, add git references
- `/pm update {{TICKET_PREFIX}}-XXX` - Update task file
- `/pm show {{TICKET_PREFIX}}-XXX` - Display task details

## Discovery & Organization
- `/pm status` - Show all tasks grouped by status
- `/pm list [TODO|IN_PROGRESS|DONE]` - Filter tasks by status
- `/pm verify` - Cross-check tasks against git history
- `/pm cleanup` - Find untracked work, organize loose files

## Search
- `/pm find <keyword>` - Search task files for keyword
- `/pm similar <description>` - Find similar existing tasks

## Next Actions
- `/todo [operation]` - Show or maintain the agreed ordered execution queue
- `/next` - What should I work on next?
- `/backlog` - Show current prioritized backlog
- `/standup` - Progress summary from git + ticket state

## Full Command Index

Every command shipped with the PM profile:

| Command | Purpose |
|---|---|
| `/pm` | This index |
| `/ticket-new <name>` | Create a parent ticket with feature spec and subtask breakdown |
| `/ticket-refine {{TICKET_PREFIX}}-XXX` | Audit ticket progress against git; create letter children for remaining work |
| `/ticket-breakdown {{TICKET_PREFIX}}-XXX` | Split an existing ticket into letter subtasks |
| `/ticket-implement {{TICKET_PREFIX}}-XXX` | Claim a ready ticket, reconcile its plan, implement, report honestly |
| `/ticket-status {{TICKET_PREFIX}}-XXX <STATUS> [OWNER]` | Explicit status/assignee transition (the claim/release primitive) |
| `/ticket-audit {{TICKET_PREFIX}}-XXX` | Generate a self-contained audit prompt for independent review |
| `/ticket-close {{TICKET_PREFIX}}-XXX` | Mark DONE, extract knowledge, archive, update boards, report |
| `/next` | Recommend what to work on next |
| `/backlog` | Show the current prioritized backlog |
| `/standup` | Progress summary from git history + ticket state |
| `/pm-sync` | Sync task state with the remote task repo |
| `/todo` | Show and maintain the canonical ordered execution queue |
| `/fix` | Verify external review findings against the tree, then fix in lanes |

## Team Sync
- `/pm-sync` - Push/pull task state with the remote task repo

## Backlog Sync

**Every ticket mutation must update `{{TASKS_DIR}}/BACKLOG.md`:**
- `/pm new` → add entry to backlog
- `/pm done` → remove entry from backlog
- `/pm start` → move entry to Active Work section
- Status/priority changes → move entry to correct section

Arguments: $ARGUMENTS
