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

## Advanced
For complex features, use:
- `/ticket-new <name>` - Create parent ticket with breakdown
- `/ticket-breakdown {{TICKET_PREFIX}}-XXX` - Split existing ticket into subtasks
- `/ticket-refine {{TICKET_PREFIX}}-XXX` - Audit ticket progress against git

## Team Sync
- `/pm sync` - Push/pull task state with remote

## Backlog Sync

**Every ticket mutation must update `{{TASKS_DIR}}/BACKLOG.md`:**
- `/pm new` → add entry to backlog
- `/pm done` → remove entry from backlog
- `/pm start` → move entry to Active Work section
- Status/priority changes → move entry to correct section

Arguments: $ARGUMENTS
