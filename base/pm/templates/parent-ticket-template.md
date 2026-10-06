# {{TICKET_PREFIX}}-XXX: [Feature Name]

**Status:** TODO | IN_PROGRESS | BLOCKED | PLANNING | REVIEW | DONE
**Priority:** HIGH | MEDIUM | LOW
**Assignee:** [email or name of the engineer who owns this]
**Review:** none | decision-needed | closure-proposed
**Type:** PARENT
**Created:** YYYY-MM-DD
**Updated:** YYYY-MM-DD

## Feature Specification

### Overview
[What this feature does and why it matters]

### User Stories
1. As a [user], I want [action] so that [benefit]
2. As a [user], I want [action] so that [benefit]

### Acceptance Criteria
Parent-level outcomes only. Children carry their own criteria; finishing every child does not check these by itself.
- [ ] AC1: [Overall, checkable outcome]
- [ ] AC2: [Overall, checkable outcome]

### Needs from assignee
None.
<!-- Or explicit asks, one per question, numbered and never renumbered. The assignee answers them on the ticket
board without opening this file, so each one stands on its own (no "see above"):
### 1. <one plain question ending in ?>
- Kind: Question | Review | Approve | Confirm closure
- For: <email or name>   (optional; defaults to the Assignee)
- Why: <one line: why it matters or what it blocks>
- Options:   (a Question only)
  - (a) <choice>: <what happens>
- Recommended: (a) <short reason>
- Built today: (a), <what exists now>   (omit when nothing is built; the work waits on the answer)
A question needed to START work is a decision instead: "- Decision: D<n>" here, the question in the team's
decision log. -->

### Technical Design

**Data Models:**
- Model/schema changes needed
- New API endpoints

**UI/UX:**
- Screens affected
- Components to build

**Dependencies:**
- What must be done first
- External integrations needed

### Subtasks

See `{{TASKS_DIR}}/{{TICKET_PREFIX}}-XXX/` for detailed breakdown (letter children — they consume no counter numbers). Each child names this ticket in its own `**Parent:**` field, which is authoritative; this list is checked against it:
- [ ] {{TICKET_PREFIX}}-XXXa: First step description
- [ ] {{TICKET_PREFIX}}-XXXb: Second step description
- [ ] {{TICKET_PREFIX}}-XXXc: Third step description

### Testing Plan
- Unit tests for [X]
- Integration tests for [Y]
- Manual QA steps

### Git References
- Feature branch: feature/{{TICKET_PREFIX}}-XXX-feature-name
- Related PRs: #123, #456

### Notes / Log
- YYYY-MM-DD: Planned feature, created subtasks
- YYYY-MM-DD: Completed {{TICKET_PREFIX}}-YYY
- YYYY-MM-DD: All subtasks done
