# sources/ — sanitized contribution sources

Raw material extracted from a long-running production install (6 months of real multi-session use), sanitized for org-base inclusion. These are **inputs to W3.0/W3.1 reconciliation** (see `TASK-team-readiness.md`), not shipped assets — the install manifest never includes this directory.

## Sanitization rules applied

- Ticket prefix → `{{TICKET_PREFIX}}` (example IDs → `{{TICKET_PREFIX}}-123` style)
- Tasks path → `{{TASKS_DIR}}`
- Project name → `{{PROJECT_NAME}}`; component/repo lists → `{{COMPONENT_REPOS}}` or removed where the section was purely project-specific
- Reviewer/subagent model and CLI pins → `{{REVIEWER_CLI}}`, `{{REVIEWER_MODEL}}`, generic "subagent" language (concrete values come from config per the plan)
- Personal names, machine paths, shell aliases, product-specific domain content → removed
- **Tool-vendor names are exempt** (Claude, Anthropic, Codex, OpenAI): the forbidden set is donor-project identifiers, not the AI tooling this system is built around
- Cross-model review config: four values — `{{REVIEWER_CLI}}`, `{{REVIEWER_MODEL}}`, `{{COORDINATOR_CLI}}`, `{{COORDINATOR_MODEL}}` (see the review-config schema in TASK-team-readiness.md Step 0)
- **Behavior is preserved — including known-stale behaviors** (direct counter increments, BACKLOG-based /next, root-git /standup) — except documented generalizations where sanitization required them: ticket-close's fixed board list became discover-all-boards, commit.md's hardcoded repo table became config-driven guidance, and testing/MVP examples were genericized. Fixing stale behavior is W3.0 reconciliation work, deliberately not done here.

## Layout

- `commands/` — PM + review + queue commands
- `skills/` — pm-agent, todo-queue, testing-automation, figma-rn-parity (→ /design-implement donor), backlog-cleanup (reference for lightweight backlog validation)
- `templates/` — ticket templates (destined for context layers, not the task repo)
- `launch-planning/` — /mvp, /mvp-execute + skills; tracked as a future optional pack

Verification: `scripts/check-debrand.sh sources/` must pass.
