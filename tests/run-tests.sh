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

# Traversal refusal: a poisoned ../ manifest key must never delete outside dest
PRJT="$WORK/t2-trav"; mkdir -p "$PRJT/src" "$PRJT/out"
printf 'safe {{TICKET_PREFIX}}\n' > "$PRJT/src/keep.md"
cat > "$PRJT/cfg.json" <<'EOF'
{"config": {"prefix": "APP", "tasks_dir": "t"}}
EOF
printf 'do not delete me\n' > "$PRJT/victim.md"
bash "$REPO/bin/render.sh" --source "$PRJT/src" --dest "$PRJT/out" --config "$PRJT/cfg.json" --base-version v1 >/dev/null 2>&1
python3 - "$PRJT/cfg.json" <<'EOF'
import json, sys
c = json.load(open(sys.argv[1]))
c["managed_files"]["../victim.md"] = {"sha256": "0"*64, "base_version": "v0", "source": "x"}
json.dump(c, open(sys.argv[1], "w"), indent=2)
EOF
TRAV_ERR="$WORK/t2-trav-err.txt"
bash "$REPO/bin/render.sh" --source "$PRJT/src" --dest "$PRJT/out" --config "$PRJT/cfg.json" --base-version v1 >/dev/null 2>"$TRAV_ERR"
assert "traversal stale key refused (victim survives)" test -f "$PRJT/victim.md"
assert "traversal refusal reported" grep -q 'REFUSING stale manifest entry escaping dest' "$TRAV_ERR"

# Modified-stale refusal: user edited a rendered file that later went stale
PRJM="$WORK/t2-mod"; mkdir -p "$PRJM/src" "$PRJM/out"
printf 'a {{TICKET_PREFIX}}\n' > "$PRJM/src/a.md"
printf 'b {{TICKET_PREFIX}}\n' > "$PRJM/src/b.md"
cat > "$PRJM/cfg.json" <<'EOF'
{"config": {"prefix": "APP", "tasks_dir": "t"}}
EOF
bash "$REPO/bin/render.sh" --source "$PRJM/src" --dest "$PRJM/out" --config "$PRJM/cfg.json" --base-version v1 >/dev/null 2>&1
printf 'user edits after render\n' >> "$PRJM/out/b.md"
rm "$PRJM/src/b.md"
MOD_ERR="$WORK/t2-mod-err.txt"
bash "$REPO/bin/render.sh" --source "$PRJM/src" --dest "$PRJM/out" --config "$PRJM/cfg.json" --base-version v2 >/dev/null 2>"$MOD_ERR"
assert "modified stale file preserved" grep -q 'user edits after render' "$PRJM/out/b.md"
assert "modified-stale conflict reported" grep -q 'CONFLICT' "$MOD_ERR"
assert_not "modified stale file dropped from manifest" grep -q '"b.md"' "$PRJM/cfg.json"

# Unmodified-stale still deleted (convergence intact after the safety change)
printf 'c {{TICKET_PREFIX}}\n' > "$PRJM/src/c.md"
bash "$REPO/bin/render.sh" --source "$PRJM/src" --dest "$PRJM/out" --config "$PRJM/cfg.json" --base-version v3 >/dev/null 2>&1
rm "$PRJM/src/c.md"
bash "$REPO/bin/render.sh" --source "$PRJM/src" --dest "$PRJM/out" --config "$PRJM/cfg.json" --base-version v4 >/dev/null 2>&1
assert_not "unmodified stale file still deleted" test -e "$PRJM/out/c.md"

# Symlinked-dir escape: a real dir-symlink under dest must not smuggle deletion outside
PRJS="$WORK/t2-sym"; mkdir -p "$PRJS/src" "$PRJS/out" "$PRJS/outside"
printf 'safe {{TICKET_PREFIX}}\n' > "$PRJS/src/keep.md"
printf 'outside victim\n' > "$PRJS/outside/victim.md"
ln -s "../outside" "$PRJS/out/link"
cat > "$PRJS/cfg.json" <<'EOF'
{"config": {"prefix": "APP", "tasks_dir": "t"}}
EOF
bash "$REPO/bin/render.sh" --source "$PRJS/src" --dest "$PRJS/out" --config "$PRJS/cfg.json" --base-version v1 >/dev/null 2>&1
VICTIM_SHA="$(sha "$PRJS/outside/victim.md")"
python3 - "$PRJS/cfg.json" "$VICTIM_SHA" <<'EOF'
import json, sys
c = json.load(open(sys.argv[1]))
c["managed_files"]["link/victim.md"] = {"sha256": sys.argv[2], "base_version": "v0", "source": "x"}
json.dump(c, open(sys.argv[1], "w"), indent=2)
EOF
SYM_ERR="$WORK/t2-sym-err.txt"
bash "$REPO/bin/render.sh" --source "$PRJS/src" --dest "$PRJS/out" --config "$PRJS/cfg.json" --base-version v1 >/dev/null 2>"$SYM_ERR"
assert "symlinked-dir escape refused (victim survives)" test -f "$PRJS/outside/victim.md"
assert "symlinked-dir escape reported" grep -q 'symlink indirection' "$SYM_ERR"

# Alias key: sub/../a.md must never delete the managed a.md
PRJA="$WORK/t2-alias"; mkdir -p "$PRJA/src" "$PRJA/out"
printf 'a {{TICKET_PREFIX}}\n' > "$PRJA/src/a.md"
cat > "$PRJA/cfg.json" <<'EOF'
{"config": {"prefix": "APP", "tasks_dir": "t"}}
EOF
bash "$REPO/bin/render.sh" --source "$PRJA/src" --dest "$PRJA/out" --config "$PRJA/cfg.json" --base-version v1 >/dev/null 2>&1
A_SHA="$(sha "$PRJA/out/a.md")"
python3 - "$PRJA/cfg.json" "$A_SHA" <<'EOF'
import json, sys
c = json.load(open(sys.argv[1]))
c["managed_files"]["sub/../a.md"] = {"sha256": sys.argv[2], "base_version": "v0", "source": "x"}
json.dump(c, open(sys.argv[1], "w"), indent=2)
EOF
ALIAS_ERR="$WORK/t2-alias-err.txt"
bash "$REPO/bin/render.sh" --source "$PRJA/src" --dest "$PRJA/out" --config "$PRJA/cfg.json" --base-version v1 >/dev/null 2>"$ALIAS_ERR"
assert "alias key refused: managed a.md survives" test -f "$PRJA/out/a.md"
assert "alias refusal reported" grep -q 'REFUSING stale alias' "$ALIAS_ERR"

# Self-referencing dir link (link -> .): stale link/a.md must not delete managed a.md
ln -s "." "$PRJA/out/selflink"
python3 - "$PRJA/cfg.json" "$A_SHA" <<'EOF'
import json, sys
c = json.load(open(sys.argv[1]))
c["managed_files"]["selflink/a.md"] = {"sha256": sys.argv[2], "base_version": "v0", "source": "x"}
json.dump(c, open(sys.argv[1], "w"), indent=2)
EOF
SELF_ERR="$WORK/t2-self-err.txt"
bash "$REPO/bin/render.sh" --source "$PRJA/src" --dest "$PRJA/out" --config "$PRJA/cfg.json" --base-version v1 >/dev/null 2>"$SELF_ERR"
assert "self-referencing link alias refused: a.md survives" test -f "$PRJA/out/a.md"
assert "symlink indirection reported" grep -q 'symlink indirection' "$SELF_ERR"
rm -f "$PRJA/out/selflink"

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

# Safety 3 (regression): tool-view symlink pointing somewhere unexpected -> abort untouched
mkdir -p "$PRJ/custom-commands"
rm -f "$PRJ/.claude/commands"
ln -s "../custom-commands" "$PRJ/.claude/commands"
if bash "$REPO/bin/rebuild-views.sh" --root "$PRJ" >/dev/null 2>&1; then
  fail "unexpected tool-view symlink: rebuild aborts"
else
  ok "unexpected tool-view symlink: rebuild aborts"
fi
[ "$(cd "$PRJ/.claude/commands" && pwd -P)" = "$(cd "$PRJ/custom-commands" && pwd -P)" ] \
  && ok "unexpected tool-view symlink left untouched" || fail "unexpected tool-view symlink left untouched"

# Safety 4: dangling tool-view symlink -> repaired
rm -f "$PRJ/.claude/commands"
ln -s "../nonexistent-target" "$PRJ/.claude/commands"
bash "$REPO/bin/rebuild-views.sh" --root "$PRJ" >/dev/null 2>&1 || fail "dangling tool-view symlink: rebuild succeeds"
assert "dangling tool-view symlink repaired" grep -q 'team x' "$PRJ/.claude/commands/x.md"

# Safety 5 (regression): tool-view symlink to a regular FILE -> unexpected, abort untouched
printf 'i am a file\n' > "$PRJ/somefile"
rm -f "$PRJ/.claude/commands"
ln -s "../somefile" "$PRJ/.claude/commands"
if bash "$REPO/bin/rebuild-views.sh" --root "$PRJ" >/dev/null 2>&1; then
  fail "file-target tool-view symlink: rebuild aborts"
else
  ok "file-target tool-view symlink: rebuild aborts"
fi
[ -L "$PRJ/.claude/commands" ] && [ "$(readlink "$PRJ/.claude/commands")" = "../somefile" ] \
  && ok "file-target tool-view symlink left untouched" || fail "file-target tool-view symlink left untouched"
rm -f "$PRJ/.claude/commands"

# Safety 6 (regression): symlink target behind a non-searchable parent -> abort untouched
mkdir -p "$PRJ/locked/inner"
chmod 000 "$PRJ/locked"
rm -f "$PRJ/.claude/commands"
ln -s "../locked/inner" "$PRJ/.claude/commands"
if bash "$REPO/bin/rebuild-views.sh" --root "$PRJ" >/dev/null 2>&1; then
  fail "inaccessible-target tool-view symlink: rebuild aborts"
else
  ok "inaccessible-target tool-view symlink: rebuild aborts"
fi
[ -L "$PRJ/.claude/commands" ] && [ "$(readlink "$PRJ/.claude/commands")" = "../locked/inner" ] \
  && ok "inaccessible-target symlink left untouched" || fail "inaccessible-target symlink left untouched"
chmod 755 "$PRJ/locked"
rm -f "$PRJ/.claude/commands"

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

# Symlink to a regular file -> unexpected (NOT "dangling"), abort untouched
printf 'plain file\n' > "$TGT/plainfile"
rm -rf "$TGT/.claude/commands"
ln -s "../plainfile" "$TGT/.claude/commands"
if bash "$REPO/install.sh" --yes "$TGT" >/dev/null 2>&1; then
  fail "file-target symlink: install aborts"
else
  ok "file-target symlink: install aborts"
fi
[ -L "$TGT/.claude/commands" ] && [ "$(readlink "$TGT/.claude/commands")" = "../plainfile" ] \
  && ok "file-target symlink left untouched" || fail "file-target symlink left untouched"

# Symlink target behind non-searchable parent -> abort untouched (installer path)
mkdir -p "$TGT/locked2/inner"
chmod 000 "$TGT/locked2"
rm -rf "$TGT/.claude/commands"
ln -s "../locked2/inner" "$TGT/.claude/commands"
if bash "$REPO/install.sh" --yes "$TGT" >/dev/null 2>&1; then
  fail "inaccessible-target symlink: install aborts"
else
  ok "inaccessible-target symlink: install aborts"
fi
[ -L "$TGT/.claude/commands" ] && [ "$(readlink "$TGT/.claude/commands")" = "../locked2/inner" ] \
  && ok "inaccessible-target symlink left untouched (install)" || fail "inaccessible-target symlink left untouched (install)"
chmod 755 "$TGT/locked2"

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

# ---------- T5: shipped base renders strict-clean + de-branded ----------
echo "T5: base/ payload renders strict + de-brand"
STAGE="$WORK/t5/staging"; BOUT="$WORK/t5/out"; mkdir -p "$STAGE"
# Assemble staging like cortex-init does: enabled profiles + optional packs,
# commands/skills/templates only (scaffolds are interview templates, not rendered).
for prof in core pm review packs/testing packs/design; do
  for sub in commands skills templates knowledge; do
    [ -d "$REPO/base/$prof/$sub" ] && { mkdir -p "$STAGE/$sub"; cp -R "$REPO/base/$prof/$sub/" "$STAGE/$sub/"; }
  done
done
cat > "$WORK/t5/config.json" <<'EOF'
{"schema_version": 1,
 "config": {
   "prefix": "APP", "tasks_dir": ".dotcortex/tasks", "project_name": "ExampleProject",
   "component_repos": ["api", "app", "web"],
   "profiles": ["core", "pm", "review", "testing", "design"],
   "review": {"reviewer_cli": "reviewer-cli", "reviewer_model": "reviewer-model",
              "coordinator_cli": "coordinator-cli", "coordinator_model": "coordinator-model"},
   "workflow_policy": {"test_authoring": "allowed", "test_execution": "user_only",
     "server_lifecycle": "user_only", "endpoint_probing": "ask",
     "documentation_creation": "ask", "ticket_creation": "followups_only", "ticket_close": "ask"},
   "linear": {"enabled": true}}}
EOF
if bash "$REPO/bin/render.sh" --source "$STAGE" --dest "$BOUT" \
     --config "$WORK/t5/config.json" --base-version vTEST --strict >/dev/null 2>"$WORK/t5/err.txt"; then
  ok "base payload renders with --strict (all tokens resolve)"
else
  fail "base payload renders with --strict (all tokens resolve)"
  head -5 "$WORK/t5/err.txt" | sed 's/^/    /'
fi
assert "rendered ticket-new carries substituted prefix" grep -q 'APP' "$BOUT/commands/ticket-new.md"
assert_not "no unsubstituted tokens survive in rendered output" grep -rq '{{[A-Z0-9_]*}}' "$BOUT"
if bash "$REPO/scripts/check-debrand.sh" "$BOUT" >/dev/null 2>&1; then
  ok "rendered base output passes de-brand scan"
else
  fail "rendered base output passes de-brand scan"
fi
assert "base source tree passes de-brand scan" bash "$REPO/scripts/check-debrand.sh" "$REPO/base"
MCOUNT=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["managed_files"]))' "$WORK/t5/config.json")
[ "$MCOUNT" -ge 25 ] && ok "manifest covers the full payload ($MCOUNT files)" || fail "manifest covers the full payload (got $MCOUNT)"

# ---------- T6: install -> init-pipeline -> render -> rebuild, end to end ----------
echo "T6: full install/init/render/rebuild integration"
PROJ="$WORK/t6"; mkdir -p "$PROJ"
bash "$REPO/install.sh" --yes "$PROJ" >/dev/null 2>&1 || fail "T6 install runs"
assert "engine installed into project" test -x "$PROJ/.dotcortex/bin/render.sh"
assert "schema installed into project" test -f "$PROJ/.dotcortex/schemas/config.schema.json"
SRCCHK="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["source_checkout"])' "$PROJ/.dotcortex/install-info.json")"
[ "$SRCCHK" = "$REPO" ] && ok "install-info records source_checkout" || fail "install-info records source_checkout"

# Simulate cortex-init Phase 4.5: config, staging with .sources.json, bootstrap migration
cp "$WORK/t5/config.json" "$PROJ/.dotcortex/config.json"
ISTAGE="$PROJ/.staging"; mkdir -p "$ISTAGE"
python3 - "$REPO/base" "$ISTAGE" <<'EOF'
import json, os, shutil, sys
base, stage = sys.argv[1], sys.argv[2]
srcmap = {}
for prof in ["core", "pm", "review", "packs/testing", "packs/design"]:
    for sub in ["commands", "skills", "templates", "knowledge"]:
        root = os.path.join(base, prof, sub)
        if not os.path.isdir(root):
            continue
        for dirpath, _, files in os.walk(root):
            for f in files:
                src = os.path.join(dirpath, f)
                rel = os.path.join(sub, os.path.relpath(src, root))
                dst = os.path.join(stage, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
                srcmap[rel] = os.path.relpath(src, os.path.dirname(base))
json.dump(srcmap, open(os.path.join(stage, ".sources.json"), "w"), indent=1)
EOF
mkdir -p "$PROJ/.dotcortex/layers/org/commands"
mv "$PROJ/.dotcortex/commands/"*.md "$PROJ/.dotcortex/layers/org/commands/"
rmdir "$PROJ/.dotcortex/commands"
INSTVER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["dotcortex_version"])' "$PROJ/.dotcortex/install-info.json")"
bash "$PROJ/.dotcortex/bin/render.sh" --source "$ISTAGE" --dest "$PROJ/.dotcortex/layers/org" \
  --config "$PROJ/.dotcortex/config.json" --base-version "$INSTVER" --strict >/dev/null 2>"$WORK/t6-render-err.txt" \
  && ok "T6 strict render into org layer succeeds" || { fail "T6 strict render into org layer succeeds"; head -3 "$WORK/t6-render-err.txt" | sed 's/^/    /'; }
bash "$PROJ/.dotcortex/bin/rebuild-views.sh" --root "$PROJ" >/dev/null 2>&1 \
  && ok "T6 rebuild-views succeeds over rendered layer + bootstrap" || fail "T6 rebuild-views succeeds over rendered layer + bootstrap"
assert "resolved view exposes bootstrap command" grep -q 'cortex-init' "$PROJ/.dotcortex/commands/cortex-init.md"
assert "resolved view exposes rendered PM command" grep -q 'APP' "$PROJ/.dotcortex/commands/ticket-new.md"
assert ".claude view resolves rendered content" grep -q 'APP' "$PROJ/.claude/commands/ticket-new.md"
T6SRC="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["managed_files"]["commands/ticket-new.md"]["source"])' "$PROJ/.dotcortex/config.json")"
[ "$T6SRC" = "base/pm/commands/ticket-new.md" ] && ok "manifest source is git-retrievable (base/...)" || fail "manifest source is git-retrievable (got: $T6SRC)"
T6VER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["managed_files"]["commands/ticket-new.md"]["base_version"])' "$PROJ/.dotcortex/config.json")"
[ "$T6VER" = "$INSTVER" ] && ok "manifest base_version matches installed version" || fail "manifest base_version matches installed version"

# Non-PM install: core profile alone renders strict-clean (lightweight setups)
CSTAGE="$WORK/t6-core"; mkdir -p "$CSTAGE"
for sub in commands skills templates knowledge; do
  [ -d "$REPO/base/core/$sub" ] && { mkdir -p "$CSTAGE/$sub"; cp -R "$REPO/base/core/$sub/" "$CSTAGE/$sub/"; }
done
cp "$WORK/t5/config.json" "$WORK/t6-core-cfg.json"
bash "$REPO/bin/render.sh" --source "$CSTAGE" --dest "$WORK/t6-core-out" \
  --config "$WORK/t6-core-cfg.json" --base-version vTEST --strict >/dev/null 2>&1 \
  && ok "core-only profile renders strict-clean (non-PM installs)" || fail "core-only profile renders strict-clean (non-PM installs)"

# Re-run install AFTER init: bootstrap goes to the layer, rebuild keeps views coherent
bash "$REPO/install.sh" --yes "$PROJ" >/dev/null 2>&1 \
  && ok "post-init install re-run succeeds" || fail "post-init install re-run succeeds"
assert "bootstrap landed in org layer on re-run" test -f "$PROJ/.dotcortex/layers/org/commands/cortex-init.md"
assert "views still resolve after post-init re-run" grep -q 'cortex-init' "$PROJ/.dotcortex/commands/cortex-init.md"

# ---------- T7: namespaced task repo — migration, two clones, transactions ----------
echo "T7: task-repo namespacing + transactions"
BARE="$WORK/t7/remote.git"; mkdir -p "$BARE"; git init -q --bare "$BARE"
FLAT="$WORK/t7/flat"
git clone -q "$BARE" "$FLAT" 2>/dev/null
( cd "$FLAT" && git config user.email t@t && git config user.name t \
  && echo "3" > .ticket_counter && echo "# Backlog" > BACKLOG.md && echo "# TODO" > TODO.md \
  && mkdir -p archive && touch archive/.gitkeep \
  && printf 'old ticket\n' > APP-001-old-ticket.md \
  && git add -A && git commit -qm "flat layout" && git push -q )

# History-preserving migration
bash "$REPO/scripts/migrate-task-repo.sh" --repo "$FLAT" --team acme --project pay --push >/dev/null 2>&1 \
  && ok "migration runs and pushes" || fail "migration runs and pushes"
assert "flat root emptied" test ! -e "$FLAT/APP-001-old-ticket.md"
assert "namespaced path holds the ticket" test -f "$FLAT/teams/acme/projects/pay/APP-001-old-ticket.md"
( cd "$FLAT" && git log --follow --oneline -- teams/acme/projects/pay/APP-001-old-ticket.md | grep -q "flat layout" ) \
  && ok "history preserved through the move (git log --follow)" || fail "history preserved through the move (git log --follow)"

# Dirty-tree refusal
( cd "$FLAT" && echo dirty > teams/acme/projects/pay/BACKLOG.md )
if bash "$REPO/scripts/migrate-task-repo.sh" --repo "$FLAT" --team x --project y >/dev/null 2>&1; then
  fail "migration refuses a dirty tree"
else
  ok "migration refuses a dirty tree"
fi
( cd "$FLAT" && git checkout -q -- . )

# Second user clones and resolves the same path; symlink chain works
U2="$WORK/t7/user2"
git clone -q "$BARE" "$U2" 2>/dev/null
( cd "$U2" && git config user.email u2@t && git config user.name u2 )
assert "second clone resolves the namespaced path" test -f "$U2/teams/acme/projects/pay/APP-001-old-ticket.md"
PRJ7="$WORK/t7/proj"; mkdir -p "$PRJ7/.dotcortex"
ln -s "$U2" "$PRJ7/.dotcortex/task-repo"
ln -s "task-repo/teams/acme/projects/pay" "$PRJ7/.dotcortex/tasks"
assert "project symlink chain resolves tickets" test -f "$PRJ7/.dotcortex/tasks/APP-001-old-ticket.md"

# Concurrent scoped transactions from two clones (task-tx.sh)
printf 'ticket A\n' > "$FLAT/teams/acme/projects/pay/APP-004-a.md"
bash "$REPO/bin/task-tx.sh" --dir "$FLAT" --msg "APP-004: create" teams/acme/projects/pay/APP-004-a.md >/dev/null 2>&1 \
  && ok "clone 1 transaction lands" || fail "clone 1 transaction lands"
printf 'ticket B\n' > "$U2/teams/acme/projects/pay/APP-005-b.md"
bash "$REPO/bin/task-tx.sh" --dir "$U2" --msg "APP-005: create" teams/acme/projects/pay/APP-005-b.md >/dev/null 2>&1 \
  && ok "clone 2 transaction lands after pulling clone 1's push" || fail "clone 2 transaction lands after pulling clone 1's push"
( cd "$FLAT" && git pull -q --rebase && test -f teams/acme/projects/pay/APP-005-b.md ) \
  && ok "both machines see both tickets" || fail "both machines see both tickets"

# Tracked-file EDIT transaction (pull must not choke on the pre-edited tree)
printf 'edited existing ticket\n' >> "$FLAT/teams/acme/projects/pay/APP-001-old-ticket.md"
bash "$REPO/bin/task-tx.sh" --dir "$FLAT" --msg "APP-001: update" teams/acme/projects/pay/APP-001-old-ticket.md >/dev/null 2>&1 \
  && ok "tracked-file edit transaction lands (autostash over pull)" || fail "tracked-file edit transaction lands (autostash over pull)"

# Pre-staged unrelated index entry must NOT ride into the commit
printf 'prestaged other work\n' > "$FLAT/teams/acme/projects/pay/APP-008-prestaged.md"
( cd "$FLAT" && git add teams/acme/projects/pay/APP-008-prestaged.md )
printf 'ticket D\n' > "$FLAT/teams/acme/projects/pay/APP-009-d.md"
bash "$REPO/bin/task-tx.sh" --dir "$FLAT" --msg "APP-009: create" teams/acme/projects/pay/APP-009-d.md >/dev/null 2>&1
( cd "$FLAT" && ! git log -1 --name-only | grep -q "APP-008" ) \
  && ok "pre-staged unrelated path excluded from pathspec'd commit" || fail "pre-staged unrelated path excluded from pathspec'd commit"
( cd "$FLAT" && git reset -q teams/acme/projects/pay/APP-008-prestaged.md && rm teams/acme/projects/pay/APP-008-prestaged.md )

# Double migration refused
if bash "$REPO/scripts/migrate-task-repo.sh" --repo "$FLAT" --team acme --project pay >/dev/null 2>&1; then
  fail "second migration into same namespace refused"
else
  ok "second migration into same namespace refused"
fi

# Ignored root artifact doesn't break migration (fresh flat repo)
BARE2="$WORK/t7/remote2.git"; mkdir -p "$BARE2"; git init -q --bare "$BARE2"
FLAT2="$WORK/t7/flat2"; git clone -q "$BARE2" "$FLAT2" 2>/dev/null
( cd "$FLAT2" && git config user.email t@t && git config user.name t \
  && echo "ignored.tmp" > .gitignore && echo scratch > ignored.tmp \
  && printf 'ticket\n' > APP-001-x.md && git add .gitignore APP-001-x.md && git commit -qm flat && git push -q )
bash "$REPO/scripts/migrate-task-repo.sh" --repo "$FLAT2" --team t2 --project p2 >/dev/null 2>&1 \
  && ok "migration succeeds with ignored root artifact present" || fail "migration succeeds with ignored root artifact present"
assert "ignored artifact left in place (reported, not moved)" test -f "$FLAT2/ignored.tmp"
assert "tracked file moved" test -f "$FLAT2/teams/t2/projects/p2/APP-001-x.md"

# Scoped: an unrelated dirty file is never swept into the commit
printf 'other session dirty\n' > "$U2/teams/acme/projects/pay/APP-006-dirty.md"
printf 'ticket C\n' > "$U2/teams/acme/projects/pay/APP-007-c.md"
bash "$REPO/bin/task-tx.sh" --dir "$U2" --msg "APP-007: create" teams/acme/projects/pay/APP-007-c.md >/dev/null 2>&1
( cd "$U2" && git status --porcelain | grep -q "APP-006-dirty" ) \
  && ok "unrelated dirty file left uncommitted (scoped staging)" || fail "unrelated dirty file left uncommitted (scoped staging)"
( cd "$U2" && ! git log --oneline -1 --name-only | grep -q "APP-006" ) \
  && ok "commit contains only the given paths" || fail "commit contains only the given paths"

echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
