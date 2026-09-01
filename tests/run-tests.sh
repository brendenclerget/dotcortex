#!/usr/bin/env bash
# Synthetic-fixture tests for the deterministic substrate:
#   T1  render.sh — substitution, byte preservation, manifest, warnings, review tokens, non-UTF8
#   T2  render.sh — determinism, convergence (stale removal), strict atomicity
#   T3  rebuild-views.sh — resolution, override report, safety (incl. post-marker user files)
#   T4  install.sh — re-run over correct / broken / wrong symlinked views
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
assert() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi; }
assert_not() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$desc"; else ok "$desc"; fi; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

# ---------- T1: renderer basics ----------
echo "T1: render.sh substitution / bytes / manifest / tokens"
SRC="$WORK/t1/src"; DST="$WORK/t1/out"; mkdir -p "$SRC/sub"
printf 'Ticket {{TICKET_PREFIX}}-123 lives in {{TASKS_DIR}}.\n' > "$SRC/a.md"
printf 'no trailing newline {{TICKET_PREFIX}}' > "$SRC/sub/b.md"          # no \n on purpose
printf 'unknown {{MYSTERY_TOKEN}} stays\n' > "$SRC/c.md"
printf 'review: {{REVIEWER_CLI}} -m {{REVIEWER_MODEL}} / {{COORDINATOR_CLI}} {{COORDINATOR_MODEL}}\n' > "$SRC/review.md"
printf '\x00\x01\xff{{TICKET_PREFIX}}\xfe' > "$SRC/blob.bin"              # invalid UTF-8
cat > "$WORK/t1/config.json" <<'EOF'
{"config": {"prefix": "APP", "tasks_dir": ".dotcortex/tasks",
 "review": {"reviewer_cli": "revcli", "reviewer_model": "rev-model-1",
            "coordinator_cli": "coordcli", "coordinator_model": "coord-model-1"}}}
EOF

RENDER_ERR="$WORK/t1/stderr.txt"
bash "$REPO/bin/render.sh" --source "$SRC" --dest "$DST" \
  --config "$WORK/t1/config.json" --base-version v9.9.9-test >/dev/null 2>"$RENDER_ERR"

assert "substitutes both project tokens" grep -q 'Ticket APP-123 lives in .dotcortex/tasks.' "$DST/a.md"
assert "substitutes nested review tokens" grep -q 'review: revcli -m rev-model-1 / coordcli coord-model-1' "$DST/review.md"
if [ "$(wc -c < "$DST/sub/b.md" | tr -d ' ')" = "23" ] && grep -q 'APP$' "$DST/sub/b.md"; then
  ok "byte-preserving: no trailing newline added"
else
  fail "byte-preserving: no trailing newline added"
fi
assert "non-UTF8 copied verbatim" cmp -s "$SRC/blob.bin" "$DST/blob.bin"
assert "unknown token left intact" grep -q '{{MYSTERY_TOKEN}}' "$DST/c.md"
assert "unknown token warned on stderr" grep -q 'UNRESOLVED tokens in c.md' "$RENDER_ERR"

MANIFEST_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["managed_files"]["a.md"]["sha256"])' "$WORK/t1/config.json")
[ "$MANIFEST_SHA" = "$(sha "$DST/a.md")" ] && ok "manifest sha256 matches rendered file" || fail "manifest sha256 matches rendered file"
BASEV=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["managed_files"]["sub/b.md"]["base_version"])' "$WORK/t1/config.json")
[ "$BASEV" = "v9.9.9-test" ] && ok "manifest records base_version" || fail "manifest records base_version"

# ---------- T2: determinism / convergence / strict atomicity ----------
echo "T2: render.sh determinism + convergence + strict atomicity"
DST2="$WORK/t1/out2"
CFG_SHA_1="$(sha "$WORK/t1/config.json")"
bash "$REPO/bin/render.sh" --source "$SRC" --dest "$DST2" \
  --config "$WORK/t1/config.json" --base-version v9.9.9-test >/dev/null 2>&1
CFG_SHA_2="$(sha "$WORK/t1/config.json")"
assert "re-render is byte-identical (dest)" diff -r "$DST" "$DST2"
[ "$CFG_SHA_1" = "$CFG_SHA_2" ] && ok "re-render is byte-identical (config/manifest ordering)" || fail "re-render is byte-identical (config/manifest ordering)"

# Convergence: render a shrunken source into the SAME dest -> stale files removed
SRC2="$WORK/t2/src"; mkdir -p "$SRC2"
cp "$SRC/a.md" "$SRC2/a.md"
bash "$REPO/bin/render.sh" --source "$SRC2" --dest "$DST" \
  --config "$WORK/t1/config.json" --base-version v9.9.10-test >/dev/null 2>&1
assert "kept file survives convergence" test -f "$DST/a.md"
assert_not "stale file removed from dest" test -e "$DST/c.md"
assert_not "stale nested file removed (and empty dir pruned)" test -e "$DST/sub"
assert_not "stale entry removed from manifest" grep -q '"c.md"' "$WORK/t1/config.json"

# Strict atomicity: unresolved token -> NOTHING written (no dest, config untouched)
SRC3="$WORK/t2/strict-src"; mkdir -p "$SRC3"
printf 'good {{TICKET_PREFIX}}\n' > "$SRC3/good.md"
printf 'bad {{NOPE}}\n' > "$SRC3/bad.md"
CFG_SHA_BEFORE="$(sha "$WORK/t1/config.json")"
if bash "$REPO/bin/render.sh" --source "$SRC3" --dest "$WORK/t2/strict-out" \
     --config "$WORK/t1/config.json" --base-version vX --strict >/dev/null 2>&1; then
  fail "--strict exits nonzero on unresolved token"
else
  ok "--strict exits nonzero on unresolved token"
fi
assert_not "--strict wrote no dest files" test -e "$WORK/t2/strict-out"
[ "$CFG_SHA_BEFORE" = "$(sha "$WORK/t1/config.json")" ] && ok "--strict left config untouched" || fail "--strict left config untouched"

# ---------- T3: rebuild-views ----------
echo "T3: rebuild-views.sh resolution + safety"
PRJ="$WORK/t3"; mkdir -p "$PRJ/.dotcortex/layers/org/commands" "$PRJ/.dotcortex/layers/team/commands" "$PRJ/.dotcortex/layers/org/skills/demo"
printf 'org x\n'  > "$PRJ/.dotcortex/layers/org/commands/x.md"
printf 'team x\n' > "$PRJ/.dotcortex/layers/team/commands/x.md"
printf 'org y\n'  > "$PRJ/.dotcortex/layers/org/commands/y.md"
printf 'skill\n'  > "$PRJ/.dotcortex/layers/org/skills/demo/SKILL.md"

OUT3="$WORK/t3-out.txt"
bash "$REPO/bin/rebuild-views.sh" --root "$PRJ" > "$OUT3" 2>&1
assert "team wins collision" grep -q 'team x' "$PRJ/.dotcortex/commands/x.md"
assert "org survives non-collision" grep -q 'org y' "$PRJ/.dotcortex/commands/y.md"
assert "override reported" grep -q 'OVERRIDE (team wins over org): commands/x.md' "$OUT3"
assert "nested skill resolves" grep -q 'skill' "$PRJ/.dotcortex/skills/demo/SKILL.md"
assert ".claude view is symlink" test -L "$PRJ/.claude/commands"
assert ".claude view resolves" grep -q 'team x' "$PRJ/.claude/commands/x.md"
assert "rebuild is idempotent" bash "$REPO/bin/rebuild-views.sh" --root "$PRJ"

# Safety 1: unmarked non-empty resolved dir aborts
PRJ2="$WORK/t3b"; mkdir -p "$PRJ2/.dotcortex/layers/org/commands" "$PRJ2/.dotcortex/commands"
printf 'org\n' > "$PRJ2/.dotcortex/layers/org/commands/x.md"
printf 'precious user file\n' > "$PRJ2/.dotcortex/commands/mine.md"
if bash "$REPO/bin/rebuild-views.sh" --root "$PRJ2" >/dev/null 2>&1; then
  fail "unmarked dir: aborts instead of deleting user files"
else
  [ -f "$PRJ2/.dotcortex/commands/mine.md" ] && ok "unmarked dir: aborts instead of deleting user files" || fail "unmarked dir: aborts instead of deleting user files"
fi

# Safety 2 (regression): user file added INSIDE a marked tree after a rebuild
printf 'saved into the view by mistake\n' > "$PRJ/.dotcortex/commands/user.md"
if bash "$REPO/bin/rebuild-views.sh" --root "$PRJ" >/dev/null 2>&1; then
  fail "marked dir with user file: aborts and preserves it"
else
  [ -f "$PRJ/.dotcortex/commands/user.md" ] && ok "marked dir with user file: aborts and preserves it" || fail "marked dir with user file: aborts and preserves it"
fi
rm -f "$PRJ/.dotcortex/commands/user.md"
assert "rebuild recovers after offender removed" bash "$REPO/bin/rebuild-views.sh" --root "$PRJ"

# ---------- T4: installer re-run over symlinked views ----------
echo "T4: install.sh re-run safety"
TGT="$WORK/t4"; mkdir -p "$TGT"
bash "$REPO/install.sh" --yes "$TGT" >/dev/null 2>&1 || fail "first install runs"
# Correct directory-symlink view (post-init state)
rm -rf "$TGT/.claude/commands"
ln -s "../.dotcortex/commands" "$TGT/.claude/commands"
bash "$REPO/install.sh" --yes "$TGT" >/dev/null 2>&1 || fail "re-run over correct symlink succeeds"
if [ -f "$TGT/.dotcortex/commands/cortex-init.md" ] && [ ! -L "$TGT/.dotcortex/commands/cortex-init.md" ]; then
  ok "canonical cortex-init.md survives re-run as a regular file"
else
  fail "canonical cortex-init.md survives re-run as a regular file"
fi
assert "view still resolves after re-run" grep -q 'cortex-init' "$TGT/.claude/commands/cortex-init.md"

# Broken symlink -> repaired
rm -rf "$TGT/.claude/commands"
ln -s "../missing/commands" "$TGT/.claude/commands"
bash "$REPO/install.sh" --yes "$TGT" >/dev/null 2>&1 || fail "re-run over broken symlink succeeds"
assert "broken symlink repaired: view resolves" grep -q 'cortex-init' "$TGT/.claude/commands/cortex-init.md"

# Wrong-target symlink -> abort, untouched
mkdir -p "$TGT/elsewhere"
rm -rf "$TGT/.claude/commands"
ln -s "../elsewhere" "$TGT/.claude/commands"
if bash "$REPO/install.sh" --yes "$TGT" >/dev/null 2>&1; then
  fail "wrong-target symlink: install aborts"
else
  ok "wrong-target symlink: install aborts"
fi
[ "$(cd "$TGT/.claude/commands" && pwd -P)" = "$(cd "$TGT/elsewhere" && pwd -P)" ] \
  && ok "wrong-target symlink left untouched" || fail "wrong-target symlink left untouched"
rm -rf "$TGT/.claude/commands"

# Version round-trip: install-info + version file agree, unified scheme
VER="$(cat "$TGT/.dotcortex/version")"
INFOVER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["dotcortex_version"])' "$TGT/.dotcortex/install-info.json")"
[ "$VER" = "$INFOVER" ] && ok "version file mirrors install-info.dotcortex_version" || fail "version file mirrors install-info.dotcortex_version"
case "$VER" in
  v*|untagged-*) ok "version field uses unified scheme ($VER)" ;;
  *) fail "version field uses unified scheme (got: $VER)" ;;
esac

# Repo-relative source identity in manifest (render inside a git repo)
REPO_FIX="$WORK/t4-repo"; mkdir -p "$REPO_FIX/base/commands"
git -C "$REPO_FIX" init -q 2>/dev/null
printf 'hello {{TICKET_PREFIX}}\n' > "$REPO_FIX/base/commands/z.md"
cat > "$REPO_FIX/cfg.json" <<'EOF'
{"config": {"prefix": "APP", "tasks_dir": "t"}}
EOF
bash "$REPO/bin/render.sh" --source "$REPO_FIX/base" --dest "$WORK/t4-repo-out" \
  --config "$REPO_FIX/cfg.json" --base-version vZ >/dev/null 2>&1
SRCPATH="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["managed_files"]["commands/z.md"]["source"])' "$REPO_FIX/cfg.json")"
[ "$SRCPATH" = "base/commands/z.md" ] && ok "manifest source is repository-relative" || fail "manifest source is repository-relative (got: $SRCPATH)"

echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
