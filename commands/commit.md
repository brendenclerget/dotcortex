---
name: commit
description: Commit outstanding changes across all repos, or a specific repo by name
---

# Multi-Repo Commit

Commit changes across project repositories. Optionally target a single repo.

## Repository Map

Define your repos in CLAUDE.md or `.claude/.dotcortex.json`. Example:

| Alias | Path | Remote |
|-------|------|--------|
| `backend` | `backend/` | org/backend |
| `frontend` | `frontend/` | org/frontend |
| `tasks` | `TASKS_DIR/` | org/project-management |

## Arguments

`$ARGUMENTS` — optional repo alias (e.g., `backend`, `frontend`, `tasks`). If empty, process ALL repos.

## Process

### Step 1: Determine target repos

- If `$ARGUMENTS` contains a repo alias, only process that repo
- If `$ARGUMENTS` is empty, process all repos defined in the repository map

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

**IMPORTANT:** If any repo has its own `.git` directory nested inside a parent repo, always `cd` into it before running git commands. Quote paths with special characters to avoid shell expansion errors.

### Step 4: Report

```
Commit summary:

✅ backend — "<commit message>" (3 files)
✅ tasks — "<commit message>" (2 files)
⏭ frontend — clean, no changes
```

## Rules

- NEVER push — only commit locally
- NEVER use `git add -A` or `git add .` — stage specific files
- NEVER commit .env, credentials, or secret files
- If a repo has only untracked files that look auto-generated or temporary, ask before committing
- Each repo gets its own independent commit with a message relevant to its changes
