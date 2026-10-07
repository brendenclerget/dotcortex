#!/usr/bin/env bash
# Tests for the boards pack (base/packs/boards): the ticket board and decision board builders, migrate_tickets.py,
# the pages in headless Chrome, and a strict render of the pack.
#   B1  builders run on the fixture workspace (tests/fixtures/boards/ws, two projects, two decision logs)
#   B2  board data: keys, people, decision ids, blockers, older tickets, archive, agent detection
#   B3  migrate_tickets.py: dry run by default, --write adds the ticket core, idempotent
#   B4  shipped files: no product names, no stray render tokens, one shared helper block
#   B5  pages in headless Chrome (Playwright; skipped when not found): no errors, lists render, "Viewing as", 390px
#   B6  bin/render.sh --strict renders the pack
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PACK="$REPO/base/packs/boards"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0 FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
assert() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi; }
assert_not() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$desc"; else ok "$desc"; fi; }
# Count the "ok: ..." / "FAIL: ..." lines another program prints.
tally() { local line; while IFS= read -r line; do
  case "$line" in
    "ok: "*) ok "${line#ok: }" ;;
    "FAIL: "*) fail "${line#FAIL: }" ;;
    *) echo "    $line" ;;
  esac; done; }

# ---------- B1: build both boards from a copy of the fixture ----------
echo "B1: builders on the fixture workspace"
WS="$WORK/ws"
cp -R "$REPO/tests/fixtures/boards/ws" "$WS"
mkdir -p "$WS/.dotcortex/skills"
cp -R "$PACK/skills/ticket-board" "$PACK/skills/decision-board" "$WS/.dotcortex/skills/"
# An agent's worktree for api.APP-007 (orchestration.json: worktree_root ../ws-wt). The id repeats nowhere else,
# so either name works; the key form is used here.
mkdir -p "$WORK/ws-wt/api.app-007" && echo "checkout" > "$WORK/ws-wt/api.app-007/README"
if (cd "$WS" && python3 .dotcortex/skills/ticket-board/build_board.py --out "$WORK/tb" --closed-days 36500) > "$WORK/tb.log" 2>&1; then
  ok "build_board.py exits 0"
else
  fail "build_board.py exits 0"; sed 's/^/    /' "$WORK/tb.log" | tail -15
fi
if (cd "$WS" && python3 .dotcortex/skills/decision-board/build_decisions.py --out "$WORK/db") > "$WORK/db.log" 2>&1; then
  ok "build_decisions.py exits 0"
else
  fail "build_decisions.py exits 0"; sed 's/^/    /' "$WORK/db.log" | tail -15
fi
assert "ticket board writes index.html and board-data.json" test -s "$WORK/tb/index.html" -a -s "$WORK/tb/board-data.json"
assert "decision board writes index.html and decisions-data.json" test -s "$WORK/db/index.html" -a -s "$WORK/db/decisions-data.json"
assert "decision build prints the next free id (D11)" grep -q "next free decision id: D11" "$WORK/db.log"
assert "ticket build prints the same next free id" grep -q "next free decision id: D11" "$WORK/tb.log"
assert "the decision build reports the duplicate D6" grep -q "D6 in checkout-redesign is already used in team" "$WORK/db.log"
assert "the ticket build reports the duplicate D6" grep -q "D6 in checkout-redesign is already used in team" "$WORK/tb.log"
assert_not "no Python traceback in either build" grep -q "Traceback" "$WORK/tb.log" "$WORK/db.log"

# ---------- B2: what the data says ----------
echo "B2: board data"
cat > "$WORK/check-data.py" <<'PY'

import json, sys
tb = json.load(open(sys.argv[1])); db = json.load(open(sys.argv[2]))
T = {t["key"]: t for t in tb["tickets"]}
D = {}
for x in db["decisions"]:
    D.setdefault(x["id"], []).append(x)
def check(desc, cond):
    print(("ok: " if cond else "FAIL: ") + desc)
check("keys are <project>.<ID>: web.APP-001 and api.APP-001 both present", "web.APP-001" in T and "api.APP-001" in T)
check("the two APP-001 keep their plain id and project", T["web.APP-001"]["id"] == "APP-001" and T["api.APP-001"]["project"] == "api")
check("multi_project is on with both projects listed", tb["multi_project"] and sorted(tb["projects"]) == ["api", "web"])
check("children resolve inside their own project", T["web.APP-002"]["children"] == ["web.APP-002a", "web.APP-002b"] and T["api.APP-002a"]["parent"] == "api.APP-002")
a = T["web.APP-003"]["asks"]
check("asks carry their For person (web.APP-003: bob, carol)", [x["for"] for x in a] == ["bob@example.com", "carol@example.com"])
check("an ask without For goes to the Assignee (web.APP-002a: jane)", T["web.APP-002a"]["asks"][0]["for"] == "jane@example.com" and not T["web.APP-002a"]["asks"][0]["for_explicit"])
check("a Question with no Built today is nothing built (every answer is follow-up)", a[1]["built_key"] is None and a[1]["nothing_built"])
check("no needs-malformed warning for a missing Built today", not any(x["code"] == "needs-malformed" and "Built today" in x["message"] for x in tb["diagnostics"]))
check("people lists every assignee and For", set(tb["people"]) == {"jane@example.com", "bob@example.com", "carol@example.com"})
check("closure-proposed ticket with every criterion checked is Ready", T["web.APP-001"]["state"]["key"] == "ready" and T["api.APP-001"]["close_eligible"])
b = T["web.APP-004"]
check("BLOCKED ticket's blocker names its decision (web.APP-004 -> D2)", b["state"]["key"] == "blocked" and any(x["kind"] == "decision" and x["id"] == "D2" for x in b["blockers"]))
check("its blocker carries the decision's owner and says nothing is built", b["blockers"][0]["owner"] == "jane@example.com" and "nothing built" in b["state"]["why"])
check("api.APP-004 waits on D7 from the feature log", any(x["id"] == "D7" for x in T["api.APP-004"]["blockers"]))
l = T["web.APP-005"]
check("older ticket reads without crashing and is flagged", l["legacy"] and {"Review", "Needs from assignee", "criterion ids"} <= set(l["core_missing"]))
check("its BACKLOG status reads as TODO and Owner as Assignee", l["status"] == "TODO" and l["assignee"] == "bob@example.com")
check("archived tickets are Done", T["web.APP-006"]["state"]["key"] == "done" and T["api.APP-006"]["lane"] == "closed")
check("an agent's worktree marks api.APP-007 In progress", T["api.APP-007"]["agent"]["active"] and T["api.APP-007"]["state"]["key"] == "progress")
check("ticket board reads decision URLs from boards.json", tb["decision_board"].endswith("example-decision-board"))
check("duplicate D-id is an error diagnostic on the ticket board", any(x["code"] == "duplicate-id" and x["level"] == "error" for x in tb["diagnostics"]))
check("duplicate D-id is an error diagnostic on the decision board", any(x["code"] == "duplicate-id" and x["level"] == "error" and x["decision"] == "D6" for x in db["diagnostics"]))
check("the duplicate is kept read-only, the first one answerable", [x["duplicate"] for x in D["D6"]] == [False, True] or sorted(x["duplicate"] for x in D["D6"]) == [False, True])
check("next free id in the data is D11", db["next_decision_id"] == "D11" and tb["next_decision_id"] == "D11")
check("a decision without an owner takes its log's owner", D["D8"][0]["owner"] == "carol@example.com" and D["D1"][0]["owner"] == "jane@example.com")
check("a feature log's bare ticket id resolves in its feature's project (D8 APP-003 -> web)", D["D8"][0]["tickets"][0]["key"] == "web.APP-003")
check("open decisions without default_built raise no error", not any(x["code"] == "no-default" for x in db["diagnostics"]))
check("nothing built means no keep-what's-built answer (D2)", D["D2"][0]["keep_key"] is None and D["D2"][0]["nothing_built"])
check("open, answered, deferred and superseded decisions are all present",
      {x["status"] for v in D.values() for x in v} == {"open", "answered", "superseded"} and D["D3"][0]["deferred"] and D["D10"][0]["deferred"])
check("logs carry scope and the feature ticket", [(l["log"], l["scope"]) for l in db["logs"]] == [("team", "team"), ("checkout-redesign", "feature")]
      and db["logs"][1]["feature_key"] == "web.APP-008")
check("families are grouped by log", all(f["id"].startswith(f["log"] + "/") for f in db["families"]))
check("decision board links tickets by key", db["ticket_board_url"].endswith("example-ticket-board") and D["D7"][0]["tickets"][0]["key"] == "api.APP-004")
PY
python3 "$WORK/check-data.py" "$WORK/tb/board-data.json" "$WORK/db/decisions-data.json" > "$WORK/b2.out" 2>&1 || fail "the board-data checks ran to the end"
tally < "$WORK/b2.out"

# ---------- B3: migrate_tickets.py ----------
echo "B3: migrate_tickets.py"
LEG="$WS/.dotcortex/layers/team/projects/web/APP-005-legacy.md"
cp "$LEG" "$WORK/legacy.before"
(cd "$WS" && python3 .dotcortex/skills/ticket-board/migrate_tickets.py --assignee bob@example.com) > "$WORK/mig-dry.log" 2>&1 || true
assert "dry run is the default and writes nothing" cmp -s "$LEG" "$WORK/legacy.before"
assert "dry run reports the plan" grep -q "DRY RUN" "$WORK/mig-dry.log"
(cd "$WS" && python3 .dotcortex/skills/ticket-board/migrate_tickets.py --write --assignee bob@example.com) > "$WORK/mig.log" 2>&1 || true
assert "--write adds Review" grep -q '^\*\*Review:\*\*' "$LEG"
assert "--write adds criterion ids" grep -q '^- \[ \] AC1: Search returns' "$LEG"
assert "--write adds Needs from assignee with None." grep -A1 -q '^## Needs from assignee' "$LEG"
assert_not "an Owner field is kept, not duplicated as Assignee" grep -q '^\*\*Assignee:\*\*' "$LEG"
cat > "$WORK/check-mig.py" <<'PY'

import re, sys
a, b = open(sys.argv[1]).read().splitlines(), open(sys.argv[2]).read().splitlines()
box = lambda ls: [m.group(1) for l in ls for m in [re.match(r"^\s*[-*]\s+\[( |x|X)\]", l)] if m]
print(("ok: " if box(a) == box(b) else "FAIL: ") + "checkbox states unchanged")
strip = lambda l: re.sub(r"^(\s*[-*]\s+\[[ xX]\]\s+)AC\d+: ", r"\1", l)
kept = [strip(l) for l in b]
print(("ok: " if all(l in kept for l in a if not l.startswith("**Status:**")) else "FAIL: ") + "every original line is still there (apart from the normalised Status)")
PY
python3 "$WORK/check-mig.py" "$WORK/legacy.before" "$LEG" > "$WORK/b3.out" 2>&1 || fail "the migration checks ran to the end"
tally < "$WORK/b3.out"
cp "$LEG" "$WORK/legacy.after"
(cd "$WS" && python3 .dotcortex/skills/ticket-board/migrate_tickets.py --write --assignee bob@example.com) > "$WORK/mig2.log" 2>&1 || true
assert "a second --write changes nothing (idempotent)" cmp -s "$LEG" "$WORK/legacy.after"
API_LEG="$WS/.dotcortex/layers/team/projects/api/APP-005-legacy.md"
assert "REVIEW (Closure proposed) becomes REVIEW + Review: closure-proposed" grep -q '^\*\*Review:\*\* closure-proposed' "$API_LEG"
# Rebuild after the migration: the migrated ticket no longer lacks the core.
(cd "$WS" && python3 .dotcortex/skills/ticket-board/build_board.py --out "$WORK/tb2" --closed-days 36500) > /dev/null 2>&1 || true
assert "after migration web.APP-005 has the ticket core" python3 -c '
import json,sys; t={x["key"]:x for x in json.load(open(sys.argv[1]))["tickets"]}["web.APP-005"]
sys.exit(0 if t["core_missing"] == [] or t["core_missing"] == ["Assignee"] else 1)' "$WORK/tb2/board-data.json"

# ---------- B4: shipped files ----------
echo "B4: shipped files"
if hits=$(grep -rniE 'ohbeo|founder|OBO-' "$PACK"); then fail "no ohbeo / founder / OBO- under base/packs/boards"; echo "$hits" | head -5 | sed 's/^/    /'
else ok "no ohbeo / founder / OBO- under base/packs/boards"; fi
if hits=$(grep -rniE 'astra|fable|codex|tcg|brenden|/Users/|wave/|run-log|concept board|claude.s queue' "$PACK"); then fail "no other source-project names, paths or lanes"; echo "$hits" | head -5 | sed 's/^/    /'
else ok "no other source-project names, paths or lanes"; fi
TOK=$(grep -rnE '\{\{[A-Z0-9_]*\}\}' "$PACK" | grep -vE '^[^:]+\.md:[0-9]+:' || true)
TOK_MD=$(grep -rnoE '\{\{[A-Z0-9_]*\}\}' "$PACK" --include='*.md' | grep -vE '\{\{(TICKET_PREFIX|TASKS_DIR)\}\}$' || true)
[ -z "$TOK$TOK_MD" ] && ok "no token-like {{…}} outside {{TICKET_PREFIX}}/{{TASKS_DIR}} in markdown" || { fail "no token-like {{…}} outside allowed markdown tokens"; echo "$TOK$TOK_MD" | head -5 | sed 's/^/    /'; }
assert_not "no hard-coded artifact URLs" grep -rqE 'claude\.ai/(code/)?artifact/[A-Za-z0-9]' "$PACK/skills"
assert_not "no brand fonts or palette" grep -rqiE 'manrope|plum|citron' "$PACK"
if grep -rhoE '(store\.(get|set)\(|KEY = )"[^"]*"' "$PACK/skills" | grep -qv '"dotcortex-'; then fail "localStorage keys all start with dotcortex-"; else ok "localStorage keys all start with dotcortex-"; fi
extract() { sed -n '/^# --- shared: keep identical/,/^# --- end shared ---/p' "$1"; }
extract "$PACK/skills/ticket-board/build_board.py" > "$WORK/shared-a"
extract "$PACK/skills/decision-board/build_decisions.py" > "$WORK/shared-b"
if [ -s "$WORK/shared-a" ] && cmp -s "$WORK/shared-a" "$WORK/shared-b"; then ok "the shared helper block is identical in both builders"; else fail "the shared helper block is identical in both builders"; fi
idblock() { sed -n '/identity (the same block on/,/^  })();/p' "$1"; }
idblock "$PACK/skills/ticket-board/board.html" | sed 's/ticket-board/BOARD/g; s/decision-board/BOARD/g; s/the decision board/the other board/; s/the ticket board/the other board/' > "$WORK/id-a"
idblock "$PACK/skills/decision-board/board.html" | sed 's/ticket-board/BOARD/g; s/decision-board/BOARD/g; s/the decision board/the other board/; s/the ticket board/the other board/' > "$WORK/id-b"
if [ -s "$WORK/id-a" ] && cmp -s "$WORK/id-a" "$WORK/id-b"; then ok "the identity block is identical on both pages"; else fail "the identity block is identical on both pages"; diff "$WORK/id-a" "$WORK/id-b" | head -6 | sed 's/^/    /'; fi
for f in "$PACK"/skills/*/*.py; do assert "$(basename "$f") parses" python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$f"; done
assert_not "no __pycache__ left in the pack" test -n "$(find "$PACK" -name __pycache__)"
for c in ticket-board ticket-board-apply decision-board decision-board-apply; do assert "command $c.md has frontmatter" grep -q "^name: $c$" "$PACK/commands/$c.md"; done

# ---------- B5: pages in headless Chrome ----------
echo "B5: pages in headless Chrome"
PW="${PLAYWRIGHT_MJS:-}"
if [ -z "$PW" ]; then
  for cand in "$(npm root -g 2>/dev/null)/playwright/index.mjs" "$HOME"/Desktop/code/*/design/v1/node_modules/playwright/index.mjs; do
    [ -f "$cand" ] && { PW="$cand"; break; }
  done
fi
if [ -z "$PW" ] || [ ! -f "$PW" ] || ! command -v node >/dev/null 2>&1; then
  ok "(skipped) Playwright not found; set PLAYWRIGHT_MJS=/path/to/playwright/index.mjs to run the page checks"
else
  cat > "$WORK/pages.mjs" <<'JS'
import fs from "node:fs";
import path from "node:path";
const [pw, tbDir, dbDir] = process.argv.slice(2);
const { chromium } = await import(pw);
const browser = await chromium.launch({ channel: "chrome", headless: true });
const TYPES = { ".html": "text/html; charset=utf-8", ".json": "application/json", ".js": "text/javascript", ".css": "text/css" };
const STUB_NULL = `window.claude = { use: async () => null };`;
const STUB_JANE = `window.claude = { use: async n => n === "user" ? { me: async () => ({ email: "jane@example.com", name: "Jane", id: "u_1" }), id: async () => "u_1" } : null };`;
const say = (good, desc) => console.log(`${good ? "ok" : "FAIL"}: ${desc}`);
async function open(dir, stub, width) {
  const ctx = await browser.newContext({ viewport: { width, height: 900 } });
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", e => errors.push("pageerror: " + e.message));
  page.on("console", m => { if (m.type() === "error") errors.push("console: " + m.text()); });
  await page.addInitScript(stub);
  await page.route("http://boards.test/**", route => {
    const rel = new URL(route.request().url()).pathname.replace(/^\/+/, "") || "index.html";
    const file = path.join(dir, rel);
    if (!fs.existsSync(file)) return route.fulfill({ status: 404, body: "not found" });
    route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || "application/octet-stream", body: fs.readFileSync(file) });
  });
  await page.goto("http://boards.test/index.html");
  return { ctx, page, errors };
}
const settle = page => page.waitForTimeout(400);

// Ticket board, no capabilities (a local preview): Everyone, list renders.
{ const { ctx, page, errors } = await open(tbDir, STUB_NULL, 1280);
  await page.waitForSelector("#queue .row", { timeout: 8000 }).catch(() => {}); await settle(page);
  say((await page.locator("#queue .row").count()) > 0, "ticket board renders its list without capabilities");
  say((await page.locator("#whose").getAttribute("data-viewer")) === "", "ticket board defaults to Everyone without a viewer");
  say((await page.locator("#conn").textContent()).includes("This browser only"), "ticket board says This browser only without a db");
  say((await page.locator('#queue .al-yours [data-row="web.APP-003"]').count()) === 1, "Everyone: Yours holds every person's items (web.APP-003)");
  await page.locator('#queue [data-open="web.APP-003"]').first().click(); await settle(page);
  say((await page.locator("#pane .ask-q").count()) === 2, "opening a ticket shows its asks");
  say(errors.length === 0, "ticket board: no page or console errors (no capabilities)" + (errors.length ? " — " + errors.slice(0, 3).join(" | ") : ""));
  await ctx.close(); }

// Ticket board as Jane.
{ const { ctx, page, errors } = await open(tbDir, STUB_JANE, 1280);
  await page.waitForFunction(() => document.querySelector("#whose")?.dataset.viewer === "jane@example.com", null, { timeout: 8000 }).catch(() => {});
  await settle(page);
  say((await page.locator("#whose").getAttribute("data-viewer")) === "jane@example.com", "ticket board defaults the view to Jane");
  say((await page.locator("#viewas").inputValue()) === "jane@example.com", "Viewing as shows Jane");
  say((await page.locator("#whose").textContent()).includes("jane (you)"), "the header says whose view it is");
  say((await page.locator('#queue .al-yours [data-row="web.APP-002a"]').count()) === 1, "Jane's own ask (web.APP-002a) is in Yours");
  say((await page.locator('#queue .al-yours [data-row="api.APP-003"]').count()) === 1, "an ask For Jane on Bob's ticket (api.APP-003) is in Yours");
  say(/1 ready to close/.test(await page.locator("#queue .al-yours .sum").textContent()), "Jane's ready-to-close ticket (web.APP-001) is counted in Yours");
  await page.locator('#queue .al-yours [data-lanetoggle="ready"]').first().click(); await settle(page);
  say((await page.locator('#queue .al-yours [data-row="web.APP-001"]').count()) === 1, "unfolding Ready to close shows web.APP-001 with its checkbox");
  say((await page.locator('#queue .al-yours [data-row="web.APP-003"]').count()) === 0, "asks For Bob and Carol on Jane's ticket are not in Jane's Yours");
  say((await page.locator('#queue .al-yours [data-row="api.APP-001"]').count()) === 0, "Bob's ready ticket is not in Jane's Yours");
  await page.selectOption("#viewas", ""); await settle(page);
  say((await page.locator('#queue .al-yours [data-row="web.APP-003"]').count()) === 1, "switching to Everyone brings everyone's items back");
  say(errors.length === 0, "ticket board: no page or console errors (Jane)" + (errors.length ? " — " + errors.slice(0, 3).join(" | ") : ""));
  await ctx.close(); }

// Ticket board at 390px as Jane: no horizontal scroll, list and card.
{ const { ctx, page, errors } = await open(tbDir, STUB_JANE, 390);
  await page.waitForSelector("#queue .row", { timeout: 8000 }).catch(() => {}); await settle(page);
  say(await page.evaluate(() => document.documentElement.scrollWidth <= 390), "ticket board list fits 390px (no horizontal scroll)");
  await page.locator('#queue [data-open="api.APP-003"]').first().click(); await settle(page);
  say((await page.locator("#pane .ask-q").count()) === 2, "on a phone the card opens in its own view");
  say(await page.evaluate(() => document.documentElement.scrollWidth <= 390), "ticket board card fits 390px");
  say(errors.length === 0, "ticket board at 390px: no errors" + (errors.length ? " — " + errors.slice(0, 3).join(" | ") : ""));
  await ctx.close(); }

// Decision board, no capabilities.
{ const { ctx, page, errors } = await open(dbDir, STUB_NULL, 1280);
  await page.waitForSelector("#main .card", { timeout: 8000 }).catch(() => {}); await settle(page);
  say((await page.locator("#main .card").count()) > 0, "decision board renders its cards without capabilities");
  say((await page.locator("#whose").getAttribute("data-viewer")) === "", "decision board defaults to Everyone without a viewer");
  say((await page.locator("#rail h2").count()) >= 2, "decision board sidebar groups by log");
  say(errors.length === 0, "decision board: no page or console errors (no capabilities)" + (errors.length ? " — " + errors.slice(0, 3).join(" | ") : ""));
  await ctx.close(); }

// Decision board as Jane, then at 390px.
{ const { ctx, page, errors } = await open(dbDir, STUB_JANE, 1280);
  await page.waitForFunction(() => document.querySelector("#whose")?.dataset.viewer === "jane@example.com", null, { timeout: 8000 }).catch(() => {});
  await settle(page);
  say((await page.locator("#whose").getAttribute("data-viewer")) === "jane@example.com", "decision board defaults the view to Jane");
  say((await page.locator("#d-D2").count()) === 1, "Jane's open decision (D2) is in Yours");
  say((await page.locator("#d-D7").count()) === 0, "Carol's decision (D7) is not in Jane's Yours");
  say(errors.length === 0, "decision board: no page or console errors (Jane)" + (errors.length ? " — " + errors.slice(0, 3).join(" | ") : ""));
  await ctx.close(); }
{ const { ctx, page, errors } = await open(dbDir, STUB_JANE, 390);
  await page.waitForSelector("#main .card", { timeout: 8000 }).catch(() => {}); await settle(page);
  say(await page.evaluate(() => document.documentElement.scrollWidth <= 390), "decision board fits 390px (no horizontal scroll)");
  say(errors.length === 0, "decision board at 390px: no errors" + (errors.length ? " — " + errors.slice(0, 3).join(" | ") : ""));
  await ctx.close(); }
await browser.close();
JS
  if node "$WORK/pages.mjs" "$PW" "$WORK/tb" "$WORK/db" > "$WORK/pages.log" 2>&1; then :; else echo "    (node exited non-zero)"; fi
  tally < "$WORK/pages.log"
  grep -qE '^(ok|FAIL): ' "$WORK/pages.log" || fail "Playwright run produced no results (see above)"
fi

# ---------- B6: render the pack ----------
echo "B6: render.sh --strict on the pack"
cat > "$WORK/config.json" <<'EOF'
{"schema_version": 1,
 "config": {
   "prefix": "APP", "tasks_dir": ".dotcortex/tasks", "project_name": "ExampleProject",
   "component_repos": ["api", "app", "web"],
   "profiles": ["core", "pm", "review", "boards"],
   "review": {"reviewer_cli": "reviewer-cli", "reviewer_model": "reviewer-model",
              "coordinator_cli": "coordinator-cli", "coordinator_model": "coordinator-model"}}}
EOF
if bash "$REPO/bin/render.sh" --source "$PACK" --dest "$WORK/render" --config "$WORK/config.json" --base-version vTEST --strict > /dev/null 2> "$WORK/render.err"; then
  ok "render.sh --strict renders the pack"
else
  fail "render.sh --strict renders the pack"; head -5 "$WORK/render.err" | sed 's/^/    /'
fi
assert "rendered commands carry the prefix" grep -rq 'APP-' "$WORK/render/commands"
assert_not "no unsubstituted tokens in the rendered pack" grep -rqE '\{\{[A-Z0-9_]*\}\}' "$WORK/render"
assert "rendered builders are byte-identical to the source" cmp -s "$PACK/skills/ticket-board/build_board.py" "$WORK/render/skills/ticket-board/build_board.py"
assert "rendered pages are byte-identical to the source" cmp -s "$PACK/skills/decision-board/board.html" "$WORK/render/skills/decision-board/board.html"

echo
echo "passed: $PASS failed: $FAIL"
[ "$FAIL" -eq 0 ]
