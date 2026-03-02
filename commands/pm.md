---
name: pm
description: Project management ticket system commands
---

# PM Commands

Available commands:

## Task Management
- `/pm new <description>` - Create a single ticket (auto-assigns PREFIX-XXX). **Always one ticket, never subtasks.** If the description suggests a multi-day feature, create the single ticket and recommend: "This looks like it needs breakdown — run `/ticket-breakdown PREFIX-XXX` when ready."
- `/pm start PREFIX-XXX` - Mark task as in-progress, create branch
- `/pm done PREFIX-XXX` - Mark complete, add git references
- `/pm update PREFIX-XXX` - Update task file
- `/pm show PREFIX-XXX` - Display task details

## Discovery & Organization
- `/pm status` - Show all tasks grouped by status
- `/pm list [TODO|IN_PROGRESS|DONE]` - Filter tasks by status
- `/pm verify` - Cross-check tasks against git history
- `/pm cleanup` - Find untracked work, organize loose files

## Search
- `/pm find <keyword>` - Search task files for keyword
- `/pm similar <description>` - Find similar existing tasks

## Backlog
- `/pm backlog` - Show prioritized backlog summary
- `/pm backlog add PREFIX-XXX` - Add ticket to backlog
- `/pm backlog sync` - Verify all backlog entries have tickets

## Next Actions
- `/next` - What should I work on next?
- `/backlog` - Show current prioritized backlog
- `/standup` - Progress summary from git + ticket state

## Advanced
For complex features, use:
- `/ticket-new <name>` - Create parent ticket with breakdown
- `/ticket-breakdown PREFIX-XXX` - Split existing ticket into subtasks
- `/ticket-refine PREFIX-XXX` - Audit ticket progress against git

## Team Sync
- `/pm sync` - Push/pull task state with remote (manual or anytime)

## Backlog Sync

**Every ticket mutation must update `TASKS_DIR/BACKLOG.md`:**
- `/pm new` → add entry to backlog
- `/pm done` → remove entry from backlog
- `/pm start` → move entry to Active Work section
- Status/priority changes → move entry to correct section

Arguments: $ARGUMENTS
