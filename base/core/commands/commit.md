---
name: commit
description: Commit outstanding changes across all repos, or a specific repo by name
---

# Multi-Repo Commit

Commit changes across project repositories. Optionally target a single repo.

## Repository Map

The repos this command operates on are `{{COMPONENT_REPOS}}` — the component
repositories defined in CLAUDE.md / project config. Build the map from there;
the table below is only an example of the shape:

| Alias | Path | Remote |
|-------|------|--------|
| `api` | `<api-repo>/` | `<org>/<api-repo>` |
| `app` | `<app-repo>/` (has its own `.git` — always `cd <app-repo>/` before git commands) | `<org>/<app-repo>` |
| `web` | `<web-repo>/` | `<org>/<web-repo>` |
| `tasks` | `{{TASKS_DIR}}/` | `<org>/<tasks-repo>` |

## Arguments

`$ARGUMENTS` — optional repo alias (e.g., `api`, `app`, `web`, `tasks`). If empty, process ALL repos.

## Process

### Step 1: Determine target repos

- If `$ARGUMENTS` contains a repo alias, only process that repo
- If `$ARGUMENTS` is empty, process every repo in the map

### Step 2: For each target repo, check for changes

```bash
cd <repo_path> && git status --short
```

If no changes, skip that repo and note it as clean.

### Step 3: For each repo WITH changes

1. Run `git status` and `git diff` (staged + unstaged) to understand changes
2. Run `git log --oneline -5` to match commit message style
3. Stage all changed files (use specific filenames, not `git add -A`)
4. Generate a concise commit message summarizing the changes
5. Commit using HEREDOC format:
```bash
git commit -m "$(cat <<'EOF'
<commit message>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**IMPORTANT for nested repos:** Any component directory with its own `.git` must
be entered before running git commands (e.g., `cd <app-repo>/`). The workspace
root is not that repo. Quote paths with parentheses (e.g.,
`'app/(app)/_layout.tsx'`) to avoid zsh glob expansion errors.

### Step 4: Report

```
Commit summary:

✅ api — "<commit message>" (3 files)
✅ tasks — "<commit message>" (2 files)
⏭ app — clean, no changes
⏭ web — clean, no changes
```

## Rules

- NEVER push — only commit locally
- NEVER use `git add -A` or `git add .` — stage specific files
- NEVER commit .env, credentials, or secret files
- If a repo has only untracked files that look auto-generated or temporary, ask before committing
- Each repo gets its own independent commit with a message relevant to its changes
