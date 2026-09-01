#!/usr/bin/env bash
# The one task/context mutation transaction. Every mutating command's inline
# git block implements this same contract; this helper is the canonical
# executable form (used by scaffolding, scripts, and anything that prefers a
# single call).
#
#   pull --rebase  ->  add EXACT paths  ->  commit  ->  push  ->  retry once
#
# Never `git add -A`, never bookends, never touches paths it wasn't given.
#
# Usage:
#   bin/task-tx.sh --dir <checkout> --msg <message> <path> [<path>...]
#   bin/task-tx.sh --dir <checkout> --pull-only
set -euo pipefail

DIR="" MSG="" PULL_ONLY=0
PATHS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir) DIR="${2:?}"; shift ;;
    --msg) MSG="${2:?}"; shift ;;
    --pull-only) PULL_ONLY=1 ;;
    *) PATHS+=("$1") ;;
  esac
  shift
done

[ -n "$DIR" ] || { echo "task-tx.sh: --dir required" >&2; exit 2; }
git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1 || { echo "task-tx.sh: $DIR is not a git repo" >&2; exit 2; }

HAS_REMOTE=1
git -C "$DIR" remote get-url origin >/dev/null 2>&1 || HAS_REMOTE=0

# Serialize concurrent local mutations (same checkout, parallel sessions).
LOCKDIR="$(git -C "$DIR" rev-parse --absolute-git-dir)/dotcortex-tx.lock"
if [ "$PULL_ONLY" -eq 0 ]; then
  tries=0
  until mkdir "$LOCKDIR" 2>/dev/null; do
    tries=$((tries + 1))
    [ "$tries" -ge 60 ] && { echo "task-tx.sh: lock held too long: $LOCKDIR" >&2; exit 1; }
    sleep 1
  done
  trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT
fi

# --autostash: callers legitimately edit tracked files BEFORE the transaction
# runs; the stash carries the working tree over the rebase and restores it.
if [ "$HAS_REMOTE" -eq 1 ]; then
  git -C "$DIR" pull --rebase --autostash
fi

if [ "$PULL_ONLY" -eq 1 ]; then
  exit 0
fi

[ -n "$MSG" ] || { echo "task-tx.sh: --msg required for a mutation" >&2; exit 2; }
[ "${#PATHS[@]}" -gt 0 ] || { echo "task-tx.sh: at least one exact path required (never -A)" >&2; exit 2; }

git -C "$DIR" add -- "${PATHS[@]}"

if git -C "$DIR" diff --cached --quiet -- "${PATHS[@]}"; then
  echo "task-tx.sh: nothing to commit for the given paths"
  exit 0
fi

# Pathspec'd commit: ONLY the given paths land, even if the index carries
# unrelated pre-staged entries from another session.
git -C "$DIR" commit -m "$MSG" -- "${PATHS[@]}"

if [ "$HAS_REMOTE" -eq 1 ]; then
  if ! git -C "$DIR" push; then
    git -C "$DIR" pull --rebase --autostash
    git -C "$DIR" push
  fi
fi
echo "task-tx.sh: committed '$MSG' (${#PATHS[@]} path(s))"
