# Agent workspace

_What every build agent needs to work in this team's repos without touching anyone's setup. The
orchestrator and the agent brief read this file. Keep it current: when a command changes, change it
here. It lives in the team layer at `knowledge/agent-workspace.md`._

## Repos

One section per component repo (paths from the workspace root, as in `config.component_repos`).

### <component path>
- **Default branch:** main
- **Install** (run in a fresh worktree): `<command>`
- **Build / typecheck / lint:** `<commands>`
- **Tests:** `<the full suite>`; one file: `<command>`
- **Dev server:** `<command with a port flag>`. Agents use ports <range>, one or more per agent, never
  the engineer's usual ports (<ports>).
- **Own test database:** `<how an agent creates, uses and drops its own database or schema>`
- **Generated files** (never hand-merged; regenerate after merging): `<file>`: `<command>`
- **Post-merge steps** for the engineer's checkout: `<dependency install, migrations, restarts>`

## Shared files

Files several agents are likely to touch. Agents make small, additive changes only and list each one
in their report.

- `<path>`: <why it's shared>

## Never

- Environments, accounts and services agents must not use (the engineer's own sign-in, shared
  staging data, production).
- Commands agents must not run (resets, seeds or migrations against shared databases).

## Accounts and seed data agents may use

- `<test accounts, fixtures, seed commands for an agent's own database>`
