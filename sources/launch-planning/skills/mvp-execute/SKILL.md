---
name: mvp-execute
description: Build a parallel MVP execution board by mapping dependencies, critical path, and independent work lanes from the launch backlog
---

# MVP Execute Skill

Use this skill when the user wants to plan **how to run MVP work in parallel**, not just what the MVP is.

## Auto-Invoke Triggers

Invoke this skill when the conversation is about:
- dependencies between MVP tickets
- what can be done in parallel
- multiple workstreams at once
- critical path vs non-critical path
- sequencing launch work across people or agents
- “what should start now vs wait”

## Core Files

- `{{TASKS_DIR}}/MVP_BACKLOG.md`
- `{{TASKS_DIR}}/BACKLOG.md`
- individual ticket files for Must Ship items and relevant Should Ship items

## Output Goal

Produce a practical execution board with four views:
1. critical path
2. parallel lanes
3. wait states / blocked work
4. immediate start set

## Analysis Rules

### 1. Prefer explicit dependencies first

If a ticket declares `Depends On`, use that.

### 2. Add practical dependencies where the backlog is underspecified

Common examples:
- design audit before implementing the new surfaces it covers
- backend/service work before the UI wiring that consumes it
- platform parity audit before broad feature commitment on that platform
- release/store screenshots after the launch UI is stable

### 3. Separate “can technically start” from “should start now”

A ticket may be technically unblocked but still be a poor first start if:
- the design is still in flux
- the product scope is unresolved
- it is downstream of a still-moving foundational ticket

### 4. Group by coordination cost

Good parallel lanes:
- product/design audits
- backend/data work
- launch ops
- infrastructure hardening

Higher-collision lanes:
- multiple people editing the same primary surfaces
- multiple people changing shared endpoints and their clients simultaneously

### 5. Keep launch focus

Do not recommend pulling deferred work into the execution board.
If a Should Ship item is optional, label it clearly as stretch or post-critical-path.

## Recommended Board Shape

When responding, structure the plan as:
- `Critical Path`
- `Parallel Lanes`
- `Wait States`
- `Independent Work`
- `Start Now`

Use tables for the first four sections whenever practical.

## Relationship to Other MVP Tools

- Use `/mvp` for launch status and blockers.
- Use `/mvp-execute` for sequencing and parallel execution.
- Use `pm-agent` if the user wants ticket states changed.

## Project-Specific Reminders — fill in

List the handful of tickets or workstreams that repeatedly drive sequencing in
this project, and why. One line each. Example shape:

- _`{{TICKET_PREFIX}}-NNN` is the core track for the primary surface_
- _`{{TICKET_PREFIX}}-NNN` is a common upstream dependency for downstream UI work_
- _`{{TICKET_PREFIX}}-NNN` gates confident scope decisions on a secondary platform_
- _`{{TICKET_PREFIX}}-NNN` is a launch quality concern, not just polish_
- _launch ops tickets are real blockers, not admin trivia_
