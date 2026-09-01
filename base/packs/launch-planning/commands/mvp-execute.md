---
name: mvp-execute
description: Build a parallel execution board from the MVP backlog, with dependencies and work lanes
---

# MVP Execute

Read the current MVP backlog and produce a practical execution board for parallel work.

## Purpose

This command is for sequencing and staffing, not status only.

Use it to answer:
- what should start now
- what is on the true critical path
- what can run in parallel safely
- what should wait for an audit, backend work, or product decision

## Process

1. Read `{{TASKS_DIR}}/MVP_BACKLOG.md`.
2. Read the current ticket files for all `Must Ship` items and any `Should Ship` items that affect launch sequencing.
3. Extract explicit dependencies from the ticket files.
4. Infer practical dependencies where the backlog is missing them.
   Examples:
   - design audit before UI implementation
   - backend service before UI wiring that consumes it
   - platform parity audit before committing to scope on that platform
5. Group work into parallel lanes.
6. Separate:
   - start now
   - wait for dependency
   - optional / stretch

## Output Format

Use markdown tables for the core output.

### Critical Path

| Order | Ticket | Title | Status | Depends On | Why It Matters |
|------|--------|-------|--------|------------|----------------|
| … | … | … | … | … | … |

### Parallel Execution Board

One row per lane. Keep lane names practical, not abstract.

| Lane | Start Now Tickets | Why These Group Together | Shared Risks / Coordination |
|------|-------------------|--------------------------|-----------------------------|
| … | … | … | … |

### Wait States

| Ticket | Title | Waiting On | What Unlocks It |
|--------|-------|------------|-----------------|
| … | … | … | … |

### Independent / Low-Coordination Work

| Ticket | Title | Why It Can Run Independently |
|--------|-------|------------------------------|
| … | … | … |

### Suggested Immediate Start Set

Recommend the best set of tickets to start at the same time right now.

| Priority | Ticket | Title | Reason |
|----------|--------|-------|--------|
| 1 | … | … | … |

### Sequencing Notes

Short prose only. Cover:
- where the true launch risk is
- what not to start too early
- what can be delegated to separate people/agents without collisions

## Rules

- This command is **read-only**.
- Do not mutate tickets, statuses, or backlog files.
- Do not recommend starting Deferred work.
- Prefer concrete dependency language over generic “this depends on that” phrasing.
- If ticket files and `MVP_BACKLOG.md` disagree, call that out explicitly.

## Difference from `/mvp`

- `/mvp` = status + blockers
- `/mvp-execute` = dependency graph + parallel work plan

Arguments: $ARGUMENTS
