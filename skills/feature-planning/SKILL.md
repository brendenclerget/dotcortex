---
name: feature-planning
description: PRD-driven feature planning with specs and task breakdown. Auto-invokes when discussing PRDs, feature specs, or planning new features.
---

# Feature Planning Skill

## Planning Hierarchy
```
PRD (docs/PRD.md)
  ↓
Feature Specs (docs/specs/feature-name.md)
  ↓
Task Breakdown (docs/tasks/feature-name-tasks.md)
  ↓
Tickets (TASKS_DIR/PREFIX-XXX-feature-name.md)
```

## When to Use Each Level

**PRD:** New major features, significant changes
**Feature Spec:** Individual feature within PRD
**Task Breakdown:** Implementation steps for spec
**Tickets:** Actual work items with git branches

## Templates

### Feature Spec Template
```markdown
# Feature Specification: [Feature Name]

**Status**: Draft | In Review | Approved | In Progress | Complete
**Priority**: P0 | P1 | P2
**Author**: [Name]
**Last Updated**: [Date]
**Tickets**: PREFIX-XXX, PREFIX-YYY

## Overview
[Brief description]

## User Stories
1. As a [user], I want [action] so that [benefit]

## Acceptance Criteria
- [ ] AC1: [Specific, testable criterion]
- [ ] AC2: ...

## Technical Design

### Data Models
- API changes needed
- Database migrations

### UI/UX
- Key screens affected
- Component changes

## Dependencies
- What needs to be done first

## Testing Plan
- Unit tests
- Integration tests
- Manual QA steps

## Rollout
- Feature flag if needed
- Gradual rollout plan

## Open Questions
- Unresolved decisions
```

### Task Breakdown Template
```markdown
# Tasks: [Feature Name]

**Spec**: docs/specs/[feature].md
**Status**: Not Started | In Progress | Complete

## Implementation Steps

### 1. [Step Name]
**Ticket**: PREFIX-XXX
**Estimated**: [time]
- [ ] Subtask 1
- [ ] Subtask 2

**Notes**: Implementation approach

### 2. [Step Name]
**Ticket**: PREFIX-YYY
- [ ] Subtask 1

## Progress
- Completed: X/Y steps
- Current: Step Z
```

## Workflow Integration

### Creating New Feature

1. **Start with concise scoping (default):**
```
   Scope implementing [feature name] with minimal overhead.
   Consider: architecture, data flow, edge cases, testing.
```

2. **Generate spec** in docs/specs/

3. **Break into tasks** in docs/tasks/

4. **Create tickets from tasks:**
   For each task, use `/pm new` or `/ticket-new`

5. **Reference in ticket:**
   Each ticket should reference its spec file

### Ticket → Spec Linkage

In ticket files (PREFIX-XXX.md), add:
```markdown
**Related Spec**: docs/specs/feature-name.md
**Task Breakdown**: docs/tasks/feature-name-tasks.md
```

## Extended Thinking Usage

Default to concise planning. Escalate only when needed:
- Use `think hard` when tradeoffs are unclear
- Use `ultrathink` only for high-risk architecture or explicit user request
