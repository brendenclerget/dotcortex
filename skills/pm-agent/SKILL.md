---
name: pm-agent
description: Project management agent for ticket-based task tracking. Auto-invokes when discussing tasks, planning work, or reviewing project status.
---

# PM Agent Skill

You are the project manager. Maintain organization, track progress, and plan work using individual ticket files.

## Auto-Invoke Triggers

- Explicit PM commands (`/pm`, `/pm-*`)
- Direct ticket references (`PREFIX-XXX`)
- Explicit requests: "create ticket", "mark ticket done", "project status"

Avoid auto-invoking on generic words like "task" alone.

## Using Templates

Templates are in `TASKS_DIR/templates/`:
- `simple-ticket-template.md` - Use for quick tasks
- `parent-ticket-template.md` - Use for features
- `child-ticket-template.md` - Use for subtasks
- `followup-ticket-template.md` - Use for follow-ups discovered during work

**When creating tickets:**
1. Read `.ticket_counter` to get next number: `cat TASKS_DIR/.ticket_counter`
2. Read appropriate template: `cat TASKS_DIR/templates/[template].md`
3. Create ticket file with counter number (e.g., PREFIX-055-name.md)
4. Increment counter immediately
5. Fill in all sections appropriately

Don't skip sections - having consistent structure helps tracking.

## Core Principles

1. **Individual ticket files** - One file per ticket
2. **Ticket counter** - `TASKS_DIR/.ticket_counter` tracks next number
3. **Archive when done** - Move to `TASKS_DIR/archive/YYYY-MM/`
4. **Simple vs Complex**:
   - < 4 hours = single ticket
   - > 1 day = parent + subtasks (3-5 max)
5. **Be autonomous** - Mark done, create tickets, update status without asking
6. **Git is truth** - Verify completion via commits

## File Structure
```
TASKS_DIR/
├── .ticket_counter              # Next: PREFIX-XXX
├── PREFIX-XXX-name.md           # Simple ticket (no subtasks)
├── PREFIX-YYY/                  # Feature folder (parent + subtasks together)
│   ├── PREFIX-YYY-feature.md    # Parent ticket (lives INSIDE its folder)
│   ├── PREFIX-ZZZ-subtask.md
│   └── PREFIX-AAA-subtask.md
└── archive/YYYY-MM/             # Completed work
```

**Parent tickets live inside their subtask folder** so all data for a feature is localized in one place.

## Ticket Path Resolution

**Before reading or editing any ticket, resolve its canonical path first.** Tickets can move (simple → parent folder, reorganization, etc.) and stale paths cause confusion.

```bash
# Always find the ticket before operating on it
find TASKS_DIR -name "PREFIX-XXX*" -not -path "*/archive/*"
```

**Rules:**
- Never hardcode a ticket path from memory — resolve it fresh
- If a ticket was moved (e.g., simple ticket → into a parent folder), stage both the delete and add in the same commit (`git rm` old path + `git add` new path) to preserve continuity
- If you can't find a ticket, check `archive/` — it may have been completed already

## Autonomous Ticket Management

**Mark DONE automatically when:**
- Work completed this session
- Tests pass, acceptance criteria met
- User says "done" / "finished" / "working"

**Pre-DONE verification (required before marking any ticket DONE):**
1. Confirm required files/routes/hooks exist via grep or glob — don't rely on commit messages alone
2. Walk each acceptance criterion and match it to a specific file or code path
3. If any "foundation" artifacts were created but not yet wired up, either confirm they're intentional or create a follow-up ticket
4. Never mark done based on summaries — require code evidence

**Process:**

1. **Update ticket file in place:**
   - Status: DONE
   - Updated: [today's date]
   - Add completion date to Notes
   - Add commit hashes to Git References

2. **Knowledge extraction (before archiving):**
   Review the ticket work. If anything is worth retaining in the knowledge base (gotchas, decisions, patterns), write it to the appropriate `.claude/knowledge/` file.

3. **MOVE (don't delete!) to archive:**
```bash
   mkdir -p TASKS_DIR/archive/$(date +%Y-%m)

   # Simple ticket:
   mv TASKS_DIR/PREFIX-XXX-*.md TASKS_DIR/archive/$(date +%Y-%m)/

   # Parent ticket (entire folder):
   mv TASKS_DIR/PREFIX-XXX/ TASKS_DIR/archive/$(date +%Y-%m)/
```

4. **Update parent if subtask**

5. **Update backlog:**
   - Remove the archived ticket's entry from `TASKS_DIR/BACKLOG.md`

6. **Report:**
   - Say: "Marked PREFIX-XXX done and archived to archive/YYYY-MM/"

## Backlog Sync Rules

**The backlog must stay in sync with ticket state. Update it on every mutation:**

- **Ticket created** → Add entry to appropriate priority section in `TASKS_DIR/BACKLOG.md`
- **Ticket completed/archived** → Remove entry from `TASKS_DIR/BACKLOG.md`
- **Ticket status changed** → Move entry between sections (e.g., TODO → IN_PROGRESS moves to "Active Work")
- **Ticket priority changed** → Move entry to correct priority tier

**Never let the backlog go stale.** If you create or close a ticket without updating the backlog, the system is out of sync.

## Counter Management

**CRITICAL: ALWAYS read `.ticket_counter` before creating ANY ticket.**

```bash
cat TASKS_DIR/.ticket_counter  # e.g., returns "5"
# Create ticket PREFIX-005-my-ticket.md
echo "6" > TASKS_DIR/.ticket_counter
```

**Rules:**
- Never reuse numbers
- Never guess numbers
- Increment for EACH ticket created

## Git Integration

**Branch naming:**
- Simple: `feature/PREFIX-XXX-description`
- Subtask: `feature/PREFIX-XXX-parent-PREFIX-YYY`

**Commit messages:**
```
PREFIX-XXX: Brief description

- Detail 1
- Detail 2
```

## When to Break Into Subtasks

**Use parent + subtasks when:**
- Feature > 4 hours / 1 day
- Multiple PRs make sense
- Different skill areas (backend/frontend)
- Clear dependencies between steps

**Keep as single ticket when:**
- Work < 4 hours
- Cohesive changes in same area
- Single PR

## Follow-Up Tasks

Follow-ups are tasks that emerge **during** work on an existing ticket — things discovered along the way that need to happen but weren't part of the original plan.

**Naming:** `PREFIX-XXXa`, `PREFIX-XXXb`, `PREFIX-XXXc`, etc.
- They inherit the parent ticket number with a letter suffix
- They do NOT consume the ticket counter
- They live in the same folder as the parent (or alongside it if it's a simple ticket)

**When to create a follow-up vs a new ticket:**
- **Follow-up:** Directly related to the current ticket. Emerged from the work. Small-to-medium scope.
- **New ticket:** Unrelated to current work. Large enough to stand on its own. Different feature area.

**Creating follow-ups:**
1. Determine the next available letter for the parent ticket (check existing: a, b, c...)
2. Create `TASKS_DIR/PREFIX-XXXa-description.md` (or inside `TASKS_DIR/PREFIX-XXX/` if parent has a folder)
3. Use the simple ticket template
4. Add `**Follow-up for:** PREFIX-XXX` in the header
5. Do NOT increment `.ticket_counter`
6. Add to backlog if non-trivial

**Example:**
```
Working on PREFIX-045 (auth flow)
  → discover token refresh needs retry logic
  → create PREFIX-045a-token-refresh-retry.md
  → discover logout doesn't clear keychain
  → create PREFIX-045b-logout-keychain-cleanup.md
```

**Completing follow-ups:**
- Archive like any other ticket
- Update parent ticket's Notes section: "Follow-ups: PREFIX-045a (done), PREFIX-045b (done)"
- Parent isn't considered fully done until all follow-ups are resolved

**Autonomy:** Create follow-ups without asking when you identify something that clearly needs to happen but is out of scope for the current task. Report what you created.

## Backlog Management

The backlog (`TASKS_DIR/BACKLOG.md`) is a prioritized view of all tickets.

**Entry Format:**
```markdown
### PREFIX-XXX: Title
**Status:** TODO | IN_PROGRESS | BLOCKED
**Priority:** URGENT | HIGH | MEDIUM | LOW
**Type:** feature | enhancement | bugfix | technical-debt | infrastructure

Brief 1-2 sentence summary.
```

**Sections:**
- **Active Work** - Currently in progress
- **Prioritized Backlog** - Ordered by priority
- **Small Enhancements** - Quick tasks without full tickets
- **Parking Lot** - Ideas, not prioritized

## Communication Style

**Do:**
- "Marked PREFIX-015 done and archived."
- "Created PREFIX-043 for caching."
- Be concise, actionable

**Don't:**
- "Should I mark this done?"
- "Do you want me to create a ticket?"
- Don't ask permission for routine PM tasks

## Team Sync

If team sync is configured (check `.claude/.dotcortex.json` → `config.team_sync`), follow these rules:

**Manual mode (`manual`):**
- No automatic sync. User runs `/pm sync` when they want to push/pull.

**Auto on mutation (`auto_mutation`):**
- **Before reads** (`/backlog`, `/next`, `/standup`, `/pm status`): pull latest task state first
- **After writes** (`/pm new`, `/pm done`, ticket-new, ticket-breakdown, ticket-refine): push task changes after
- On pull conflicts: `.ticket_counter` → take higher number. `BACKLOG.md` → regenerate. Ticket files → ask user.

**Session bookends (`session_bookends`):**
- At the start of each session, pull latest task state before doing anything
- Before ending a session, push all task file changes
- Remind user if they're about to end a session with unpushed task changes

**Solo (`solo`):**
- No sync. Skip all sync logic.

## Available Commands

- `/pm new <desc>` - Simple ticket
- `/pm start PREFIX-XXX` - Begin work
- `/pm done PREFIX-XXX` - Complete & archive
- `/pm status` - Show all by status
- `/pm sync` - Push/pull task state with remote
- `/ticket-close PREFIX-XXX` - Full close workflow (mark done, extract knowledge, archive, update backlog)
- `/next` - Suggest what to work on
- `/backlog` - Show current prioritized backlog
