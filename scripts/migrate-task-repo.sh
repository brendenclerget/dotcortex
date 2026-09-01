#!/usr/bin/env bash
# History-preserving migration of a FLAT task repo (project tasks at the repo
# root — the pre-namespacing layout) into the namespaced layout:
#
#   teams/<team_key>/projects/<project_key>/<everything that was at root>
#
# The move is a single `git mv` commit, so `git log --follow` keeps every
# ticket's history and rollback is exactly `git revert <migration-commit>`.
#
# Usage:
#   scripts/migrate-task-repo.sh --repo <checkout> --team <team_key> --project <project_key> [--push]
set -euo pipefail

REPO="" TEAM="" PROJECT="" PUSH=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)    REPO="${2:?}"; shift ;;
    --team)    TEAM="${2:?}"; shift ;;
    --project) PROJECT="${2:?}"; shift ;;
    --push)    PUSH=1 ;;
    *) echo "migrate-task-repo.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$REPO" ] && [ -n "$TEAM" ] && [ -n "$PROJECT" ] || {
  echo "usage: $0 --repo <checkout> --team <team_key> --project <project_key> [--push]" >&2; exit 2; }
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo: $REPO" >&2; exit 2; }

DEST="teams/$TEAM/projects/$PROJECT"

# Refuse on dirty tree — the migration must be the only change in its commit.
if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
  echo "migrate-task-repo.sh: ABORT — working tree is dirty. Commit or stash first:" >&2
  git -C "$REPO" status --porcelain | head -10 | sed 's/^/    /' >&2
  exit 1
fi

if [ -e "$REPO/$DEST" ]; then
  echo "migrate-task-repo.sh: ABORT — $DEST already exists (already migrated?)" >&2
  exit 1
fi

if git -C "$REPO" remote get-url origin >/dev/null 2>&1; then
  git -C "$REPO" pull --rebase
fi

mkdir -p "$REPO/$DEST"

# Move everything at root except .git and the teams/ tree itself.
moved=0
for entry in "$REPO"/* "$REPO"/.[!.]*; do
  name="$(basename "$entry")"
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  case "$name" in .git|teams) continue ;; esac
  git -C "$REPO" mv "$name" "$DEST/$name"
  moved=$((moved + 1))
done

[ "$moved" -gt 0 ] || { echo "migrate-task-repo.sh: nothing to move" >&2; exit 1; }

git -C "$REPO" commit -m "migrate: flat task layout -> $DEST

History-preserving namespacing migration ($moved entries moved with git mv;
use 'git log --follow' on any file). Rollback: git revert this commit."

echo "Migrated $moved entries to $DEST (commit $(git -C "$REPO" rev-parse --short HEAD))."

if [ "$PUSH" -eq 1 ] && git -C "$REPO" remote get-url origin >/dev/null 2>&1; then
  git -C "$REPO" push
  echo "Pushed."
else
  echo "NOT pushed — review, then push (or 'git revert HEAD' to roll back)."
fi

cat <<EOF

Next, in each project workspace that uses this repo:
  1. Clone/point the checkout at .dotcortex/task-repo
  2. ln -s task-repo/$DEST .dotcortex/tasks   (replacing the old direct dir/link)
  3. .tasks -> .dotcortex/tasks stays unchanged
EOF
