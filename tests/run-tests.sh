#!/usr/bin/env bash
# Synthetic-fixture tests for the deterministic substrate:
#   T1  render.sh — token substitution, byte preservation, manifest, unresolved warning
#   T2  render.sh — determinism (same inputs => byte-identical output + manifest hash)
#   T3  rebuild-views.sh — org/team resolution, override report, safety abort
#   T4  install.sh — re-run over a symlinked .claude/commands view must not brick it
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
assert() { # assert <desc> <cmd...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi
}

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

# ---------- T1: renderer basics ----------
echo "T1: render.sh substitution / bytes / manifest"
SRC="$WORK/t1/src"; DST="$WORK/t1/out"; mkdir -p "$SRC/sub"
printf 'Ticket {{TICKET_PREFIX}}-123 lives in {{TASKS_DIR}}.\n' > "$SRC/a.md"
printf 'no trailing newline {{TICKET_PREFIX}}' > "$SRC/sub/b.md"          # no \n on purpose
printf 'unknown {{MYSTERY_TOKEN}} stays\n' > "$SRC/c.md"
cat > "$WORK/t1/config.json" <<'EOF'
{"config": {"prefix": "APP", "tasks_dir": ".dotcortex/tasks"}}
EOF

RENDER_ERR="$WORK/t1/stderr.txt"
bash "$REPO/bin/render.sh" --source "$SRC" --dest "$DST" \
  --config "$WORK/t1/config.json" --base-version v9.9.9-test >/dev/null 2>"$RENDER_ERR"

assert "substitutes both tokens" grep -q 'Ticket APP-123 lives in .dotcortex/tasks.' "$DST/a.md"
if [ "$(printf 'no trailing newline APP')" = "$(cat "$DST/sub/b.md")" ] \
   && [ "$(wc -c < "$DST/sub/b.md" | tr -d ' ')" = "23" ]; then
  ok "byte-preserving: no trailing newline added"
else
  fail "byte-preserving: no trailing newline added"
fi
assert "unknown token left intact" grep -q '{{MYSTERY_TOKEN}}' "$DST/c.md"
assert "unknown token warned on stderr" grep -q 'UNRESOLVED tokens in c.md' "$RENDER_ERR"

MANIFEST_SHA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["managed_files"]["a.md"]["sha256"])' "$WORK/t1/config.json")
[ "$MANIFEST_SHA" = "$(sha "$DST/a.md")" ] && ok "manifest sha256 matches rendered file" || fail "manifest sha256 matches rendered file"
BASEV=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["managed_files"]["sub/b.md"]["base_version"])' "$WORK/t1/config.json")
[ "$BASEV" = "v9.9.9-test" ] && ok "manifest records base_version" || fail "manifest records base_version"

# strict mode fails on unresolved token
if bash "$REPO/bin/render.sh" --source "$SRC" --dest "$WORK/t1/out2" \
     --config "$WORK/t1/config.json" --base-version v9.9.9-test --strict >/dev/null 2>&1; then
  fail "--strict exits nonzero on unresolved token"
else
  ok "--strict exits nonzero on unresolved token"
fi

# ---------- T2: determinism ----------
echo "T2: render.sh determinism"
DST2="$WORK/t1/out3"
bash "$REPO/bin/render.sh" --source "$SRC" --dest "$DST2" \
  --config "$WORK/t1/config.json" --base-version v9.9.9-test >/dev/null 2>&1
assert "re-render is byte-identical" diff -r "$DST" "$DST2"

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

# safety: unmarked non-empty resolved dir aborts
PRJ2="$WORK/t3b"; mkdir -p "$PRJ2/.dotcortex/layers/org/commands" "$PRJ2/.dotcortex/commands"
printf 'org\n' > "$PRJ2/.dotcortex/layers/org/commands/x.md"
printf 'precious user file\n' > "$PRJ2/.dotcortex/commands/mine.md"
if bash "$REPO/bin/rebuild-views.sh" --root "$PRJ2" >/dev/null 2>&1; then
  fail "aborts instead of deleting unmarked user files"
else
  [ -f "$PRJ2/.dotcortex/commands/mine.md" ] && ok "aborts instead of deleting unmarked user files" || fail "aborts instead of deleting unmarked user files"
fi

# ---------- T4: installer re-run over symlinked view ----------
echo "T4: install.sh re-run safety"
TGT="$WORK/t4"; mkdir -p "$TGT"
bash "$REPO/install.sh" --yes "$TGT" >/dev/null 2>&1 || fail "first install runs"
# Simulate post-init state: whole-directory symlink view.
rm -rf "$TGT/.claude/commands"
ln -s "../.dotcortex/commands" "$TGT/.claude/commands"
bash "$REPO/install.sh" --yes "$TGT" >/dev/null 2>&1 || fail "second install runs"
if [ -f "$TGT/.dotcortex/commands/cortex-init.md" ] && [ ! -L "$TGT/.dotcortex/commands/cortex-init.md" ]; then
  ok "canonical cortex-init.md survives re-run as a regular file"
else
  fail "canonical cortex-init.md survives re-run as a regular file"
fi
assert "view still resolves after re-run" grep -q 'cortex-init' "$TGT/.claude/commands/cortex-init.md"
VER="$(cat "$TGT/.dotcortex/version")"
case "$VER" in
  v*|untagged-*) ok "version field uses unified scheme ($VER)" ;;
  *) fail "version field uses unified scheme (got: $VER)" ;;
esac

echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
