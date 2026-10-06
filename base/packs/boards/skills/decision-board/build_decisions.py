#!/usr/bin/env python3
"""Build the team decision board from the team's decision logs.

Usage (from the workspace root):
  build_decisions.py --out DIR [--decisions FILE ...] [--tasks DIR ...] [--settings FILE ...]
                     [--board-url URL] [--ticket-board-url URL]

Writes DIR/index.html (the page) and DIR/decisions-data.json. Publish DIR/index.html with DIR/decisions-data.json
as its one supporting file.

Logs: every .dotcortex/layers/team/decisions/*.yml (team.yml is the team log; others are feature logs), plus each
--decisions FILE. D-ids are unique across all of them; the build prints the next free one. Each decision is joined
with the tickets it names (title, status, the criteria it answers) and, only when --settings is given, with the
settings it controls. Problems are diagnostics (level, code, message, decision); nothing is fixed here.
Exit status is non-zero only when an input can't be read.
"""
import argparse, datetime as dt, hashlib, json, os, re, shutil, subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent


# --- shared: keep identical in build_board.py and build_decisions.py ---
# Workspace layout, ticket keys, status rules, people matching and decision logs. Both builders apply exactly these
# rules (tests/boards-test.sh compares this block between the two files). Edit both copies together.
TEAM_DIR = Path(".dotcortex") / "layers" / "team"
STATUSES = ["TODO", "IN_PROGRESS", "BLOCKED", "PLANNING", "REVIEW", "DONE"]
GENERIC_TID = r"[A-Z][A-Z0-9]{1,9}-\d+[a-z]?"
TID_RE = re.compile(r"\b" + GENERIC_TID + r"\b")
TID_FILE_RE = re.compile(r"^(" + GENERIC_TID + r")(?:-.*)?\.md$")
# A ticket reference: "APP-012" or, across projects, "web.APP-012".
REF_RE = re.compile(r"(?:\b([A-Za-z0-9][A-Za-z0-9_-]*)\.)?\b(" + GENERIC_TID + r")\b")
FIELD_RE = re.compile(r"^\*\*([A-Za-z][A-Za-z /-]*?):\*\*\s*(.*?)\s*$")
CHECK_ANY_RE = re.compile(r"^\s*[-*]\s+\[( |x|X)\]\s+(.*)$")
AC_ID_RE = re.compile(r"^(AC\d+)\s*[:.)-]\s*(.*)$")
CODE_ID_RE = re.compile(r"^\*\*([A-Z]{1,3}\d{1,3}[a-z]?)\*\*\s*(.*)$")
D_ID_RE = re.compile(r"^D(\d+)$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class Diag:
    """Diagnostics: {level, code, message, file, line, ticket, decision}; file paths relative to the workspace."""
    def __init__(self, root):
        self.items, self.root = [], os.path.abspath(str(root))

    def rel(self, path):
        if path is None or isinstance(path, str):
            return path
        r = os.path.relpath(os.path.abspath(str(path)), self.root)
        return str(path) if r.startswith("..") else r

    def add(self, level, code, msg, path=None, line=None, ticket=None, decision=None):
        self.items.append({"level": level, "code": code, "message": msg, "file": self.rel(path), "line": line,
                           "ticket": ticket, "decision": decision})


def load_yaml(path, text=None):
    """PyYAML when installed, else Ruby's YAML through a subprocess, else stop and say what to install."""
    text = Path(path).read_text(encoding="utf-8") if text is None else text
    try:
        import yaml  # type: ignore
    except ImportError:
        yaml = None
    if yaml is not None:
        try:
            return yaml.safe_load(text)
        except yaml.YAMLError as e:
            raise ValueError(str(e).splitlines()[0])
    if not shutil.which("ruby"):
        raise SystemExit("install PyYAML (pip install pyyaml)")
    ruby = ('require "yaml"; require "json"; require "date"; '
            'print JSON.generate(YAML.safe_load(STDIN.read, permitted_classes: [Date, Time], aliases: true))')
    out = subprocess.run(["ruby", "-e", ruby], input=text, capture_output=True, text=True)
    if out.returncode:
        raise ValueError(out.stderr.strip().splitlines()[-1] if out.stderr.strip() else "YAML parse failed")
    return json.loads(out.stdout)


def read_json(path, default=None):
    if not Path(path).is_file():
        return default
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except ValueError as e:
        raise SystemExit(f"{path}: not valid JSON ({e})")


def as_list(v):
    return v if isinstance(v, list) else ([] if v is None else [v])


def workspace_config(ws):
    doc = read_json(ws / ".dotcortex" / "config.json", {}) or {}
    return (doc.get("config") or doc) if isinstance(doc, dict) else {}


def component_repos(ws, cfg):
    repos = cfg.get("component_repos") or ["."]
    if isinstance(repos, str):
        repos = [r.strip() for r in repos.split(",") if r.strip()]
    return [Path(os.path.normpath(str(ws / r))) for r in repos]


def orchestration(ws):
    o = read_json(ws / TEAM_DIR / "policy" / "orchestration.json", {}) or {}
    return {"worktree_root": o.get("worktree_root") or f"../{ws.name}-wt",
            "branch_prefix": o.get("branch_prefix") or "agent/", "max_agents": o.get("max_agents") or 4}


def board_urls(ws, ticket_board=None, decision_board=None):
    b = read_json(ws / TEAM_DIR / "boards.json", {}) or {}
    return {"ticket_board": ticket_board or b.get("ticket_board") or "",
            "decision_board": decision_board or b.get("decision_board") or ""}


def task_roots(ws, overrides=None):
    """[(project, path)]: --tasks DIR (repeatable), else every projects/*/ with a .ticket_counter, else
    .dotcortex/tasks. The project is the root's directory name."""
    if overrides:
        roots, names = [], set()
        for p in overrides:
            p = Path(os.path.abspath(p))
            name = p.name if p.name not in names else f"{p.parent.name}-{p.name}"
            names.add(name)
            roots.append((name, p))
        return roots
    proj = ws / TEAM_DIR / "projects"
    roots = [(p.name, p) for p in sorted(proj.iterdir()) if p.is_dir() and (p / ".ticket_counter").exists()] if proj.is_dir() else []
    return roots or [("tasks", ws / ".dotcortex" / "tasks")]


def ticket_files(root):
    """(path, archived) for each ticket file under one root: top level, family folders (<ID>/), archive/**."""
    ok = lambda p: TID_FILE_RE.match(p.name)
    out = [(p, False) for p in sorted(root.glob("*.md")) if ok(p)]
    out += [(p, False) for p in sorted(root.glob("*/*.md")) if ok(p) and re.fullmatch(GENERIC_TID, p.parent.name)]
    out += [(p, True) for p in sorted(root.glob("archive/**/*.md")) if ok(p)]
    return out


class TicketIndex:
    """Every ticket file across the task roots, keyed the same way on both boards. The key is <project>.<ID> when
    there is more than one root, else the ID. IDs repeat across projects; keys never do."""
    def __init__(self, roots):
        self.roots, self.multi = roots, len(roots) > 1
        self.items, self.by_key, self.by_id = [], {}, {}
        for project, root in roots:
            for p, archived in ticket_files(root):
                tid = TID_FILE_RE.match(p.name).group(1)
                key = f"{project}.{tid}" if self.multi else tid
                it = {"key": key, "id": tid, "project": project, "path": p, "archived": archived}
                self.items.append(it)
                if key not in self.by_key:
                    self.by_key[key] = it
                    self.by_id.setdefault(tid, []).append(key)

    def resolve(self, ref, here=None):
        """A reference -> (key, problem). "web.APP-001" is exact. A bare ID resolves in `here` (the project of the
        ticket or log that wrote it) first, then to the one project that has it. problem: None, "missing" or
        "ambiguous" (the ID is in several projects: write it as <project>.<ID>)."""
        m = REF_RE.fullmatch(str(ref or "").strip())
        if not m:
            return None, "missing"
        proj, tid = m.group(1), m.group(2)
        if not self.multi:
            return (tid, None) if tid in self.by_key else (None, "missing")
        if proj:
            k = f"{proj}.{tid}"
            return (k, None) if k in self.by_key else (None, "missing")
        if here and f"{here}.{tid}" in self.by_key:
            return f"{here}.{tid}", None
        cands = self.by_id.get(tid, [])
        if len(cands) == 1:
            return cands[0], None
        return None, ("ambiguous" if cands else "missing")


def ref_strings(text):
    """'web.APP-001, APP-002 and APP-003' -> ['web.APP-001', 'APP-002', 'APP-003']."""
    return [(f"{m.group(1)}.{m.group(2)}" if m.group(1) else m.group(2)) for m in REF_RE.finditer(text or "")]


def normalize_status(raw):
    """-> (status, note, problem). 'REVIEW (Closure proposed)' -> ('REVIEW', 'Closure proposed', None); BACKLOG reads
    as TODO ('status-legacy'); anything unknown reads as TODO ('bad-status'); none reads as TODO ('missing-status')."""
    raw = str(raw or "").strip()
    if not raw:
        return "TODO", "", "missing-status"
    m = re.match(r"^([A-Za-z_]+)\s*(?:\((.*)\))?", raw)
    st, note = (m.group(1).upper(), (m.group(2) or "").strip()) if m else ("", "")
    if st == "BACKLOG":
        return "TODO", note, "status-legacy"
    if st not in STATUSES:
        return "TODO", note, "bad-status"
    return st, note, None


def person_key(s):
    """How the boards compare people (an email or a display name): trimmed, spaces collapsed, case-insensitive."""
    return re.sub(r"\s+", " ", str(s or "")).strip().lower()


def clean_person(s):
    """A person field's value; template placeholders ("[email or name ...]", "<email or name>") read as empty."""
    s = str(s or "").strip()
    return "" if not s or s[0] in "[<" or s.lower() in ("none", "unassigned", "-", "n/a") else s


def people_list(values):
    seen, out = set(), []
    for v in values:
        v = clean_person(v)
        k = person_key(v)
        if k and k not in seen:
            seen.add(k)
            out.append(v)
    return out


def quick_ticket(path):
    """Title, status, assignee, parent and criteria of one ticket file (what the decision board reads)."""
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    title = next((l[2:].strip() for l in lines if l.startswith("# ")), "")
    title = re.sub(r"^" + GENERIC_TID + r":\s*", "", title)
    fields = {}
    for raw in lines:
        if raw.startswith("## "):
            break
        f = FIELD_RE.match(raw.strip())
        if f:
            fields.setdefault(f.group(1).strip().lower(), f.group(2))
    crit = []
    for i, raw in enumerate(lines, 1):
        c = CHECK_ANY_RE.match(raw)
        if c:
            body, cid = c.group(2).strip(), None
            for rx in (AC_ID_RE, CODE_ID_RE):
                mm = rx.match(body)
                if mm:
                    cid, body = mm.group(1), mm.group(2)
                    break
            crit.append({"id": cid, "text": body, "checked": c.group(1) != " ", "line": i})
    parent = ref_strings(fields.get("parent", ""))
    return {"title": title, "status": normalize_status(fields.get("status"))[0],
            "assignee": clean_person(fields.get("assignee") or fields.get("owner")),
            "parent": parent[0] if parent else None, "criteria": crit}


def decision_log_paths(ws, extra=None):
    """Team decision logs: .dotcortex/layers/team/decisions/*.yml (team.yml first), then each --decisions FILE.
    An older single-file install (.dotcortex/tasks/decisions.yml) is read when no log exists."""
    d = ws / TEAM_DIR / "decisions"
    paths = sorted(list(d.glob("*.yml")) + list(d.glob("*.yaml")), key=lambda p: (p.stem != "team", p.name)) if d.is_dir() else []
    legacy = ws / ".dotcortex" / "tasks" / "decisions.yml"
    if not paths and not extra and legacy.exists():
        paths = [legacy]
    for e in extra or []:
        p = Path(os.path.abspath(e))
        if p not in paths:
            paths.append(p)
    return paths


def read_decision_logs(paths, diag):
    """-> (logs, entries, next_free). Each entry is its YAML mapping plus `log` (the file stem) and `owner` (its own,
    else the log's). D-ids are unique across all the team's logs: a repeat is an error diagnostic and the entry gets
    `duplicate_of` (the log that uses the id first). next_free is max(D-number over every log) + 1."""
    logs, entries, first = [], [], {}
    for p in paths:
        try:
            doc = load_yaml(p) or {}
        except (OSError, ValueError) as e:
            diag.add("error", "decisions-yaml", f"Couldn't read {p.name}: {e}", p)
            continue
        if not isinstance(doc, dict):
            diag.add("error", "decisions-yaml", f"{p.name} is not a mapping", p)
            continue
        stem = p.stem
        log = {"log": stem, "file": diag.rel(p), "title": str(doc.get("title") or stem),
               "scope": doc.get("scope") or ("team" if stem in ("team", "decisions") else "feature"),
               "feature": doc.get("feature"), "owner": clean_person(doc.get("owner")), "updated": doc.get("updated"),
               "milestones": [m for m in as_list(doc.get("milestones")) if isinstance(m, dict)], "schema": doc.get("schema")}
        if doc.get("log") and str(doc["log"]) != stem:
            diag.add("warn", "log-name", f"{p.name}: log is {doc['log']!r} but the file stem is {stem!r}", p)
        logs.append(log)
        for pos, d in enumerate(as_list(doc.get("decisions"))):
            if not isinstance(d, dict):
                diag.add("error", "malformed", f"{p.name}: entry {pos + 1} is not a mapping", p)
                continue
            e = dict(d)
            e["id"] = str(d.get("id") or f"{stem}#{pos + 1}")
            e["log"] = stem
            e["owner"] = clean_person(d.get("owner")) or log["owner"]
            if e["id"] in first:
                e["duplicate_of"] = first[e["id"]]
                diag.add("error", "duplicate-id", f"{e['id']} in {stem} is already used in {first[e['id']]}: decision ids are unique "
                         "across the team's logs; give this one the next free id", p, decision=e["id"])
            else:
                first[e["id"]] = stem
            entries.append(e)
    nums = [int(m.group(1)) for e in entries for m in [D_ID_RE.match(e["id"])] if m]
    return logs, entries, f"D{max(nums, default=0) + 1}"


def log_project_hint(log, index):
    """A feature log's project (from `feature: web.APP-012`), so its bare ticket ids resolve there first."""
    key, _ = index.resolve(str((log or {}).get("feature") or ""))
    return index.by_key[key]["project"] if key else None


def decision_tickets(entry, hint, index):
    """[(ref, key, criteria, problem)] for a decision's `tickets` list (see TicketIndex.resolve)."""
    out = []
    for t in as_list(entry.get("tickets")):
        t = t if isinstance(t, dict) else {"id": t}
        ref = str(t.get("id") or "")
        key, problem = index.resolve(ref, hint)
        out.append((ref, key, [str(c) for c in as_list(t.get("criteria"))], problem))
    return out


def decision_lane(x):
    """An open decision's lane, as the decision board shows it: "now" (blocks a milestone), "later"
    (`blocks: later`) or "deferred" (the owner said not now: `deferred_at`). Closed ones return their status."""
    if (x or {}).get("status") != "open":
        return (x or {}).get("status") or "unknown"
    return "deferred" if x.get("deferred_at") else "later" if x.get("blocks") == "later" else "now"


def git_rev(path):
    try:
        rev = subprocess.run(["git", "-C", str(path), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
        dirty = bool(subprocess.run(["git", "-C", str(path), "status", "--porcelain", "--untracked-files=no", "--", "."],
                                    capture_output=True, text=True).stdout.strip()) if rev else None
        return {"rev": rev or None, "dirty": dirty}
    except Exception:
        return {"rev": None, "dirty": None}
# --- end shared ---


SCHEMA_VERSION = 1
BOARD_VERSION = 4
# Ticket statuses where work hasn't started: without an explicit `gates`, an open decision on such a ticket gates it.
NOT_STARTED = {"PLANNING", "TODO"}
# Ticket statuses where nothing is built yet: a decision whose tickets are all like this shapes new work; one whose
# ticket has started (or is done) confirms built work. `kind: shapes|confirms` overrides it.
UNBUILT = {"PLANNING", "TODO", "BLOCKED"}
KINDS = ["shapes", "confirms"]
STATUSES_D = ["open", "answered", "superseded"]
PRIORITIES = ["critical", "high", "medium", "low"]
FOLLOW_UP = ["none", "pending", "done"]
KNOWN = {"id", "title", "question", "context", "options", "items", "default_built", "built", "settings", "tickets",
         "status", "answer", "answered_at", "answered_by", "answered_by_id", "follow_up", "follow_up_status", "source",
         "source_ref", "priority", "blocks", "review_notes", "links", "deferred_at", "deferred_note", "superseded_by",
         "note", "gates", "recommended", "kind", "moved_to", "superseded_note", "owner", "log"}
RECOMMENDED_RE = re.compile(r"\([^()]*\brecommend(?:ed|ation)\b[^()]*\)", re.I)
MOVED_RE = re.compile(r"((?:[A-Za-z0-9][A-Za-z0-9_-]*\.)?" + GENERIC_TID + r"):(\d+)")


def fp_obj(obj):
    return hashlib.sha1(json.dumps(obj, sort_keys=True, ensure_ascii=False, default=str).encode("utf-8")).hexdigest()[:12]


def load_settings(paths, d):
    """--settings FILE (YAML or JSON), repeatable -> (lookup(key) -> {where: value} or None, sources). A key is a
    dotted path ("checkout.max_retries"); a bare key also matches one level down ("shared.max_retries", the
    per-environment layout). ERB (<%= ... %>) reads as "set by environment" and is never compared."""
    flat, tops, sources = {}, set(), []
    for p in paths:
        p = Path(p)
        try:
            text = p.read_text(encoding="utf-8")
        except OSError as e:
            raise SystemExit(f"--settings {p}: {e}")
        text = re.sub(r"<%=?(.*?)%>", lambda m: json.dumps("<erb>" + m.group(1).strip()), text)
        try:
            doc = json.loads(text) if p.suffix == ".json" else load_yaml(p, text)
        except ValueError as e:
            raise SystemExit(f"--settings {p}: {e}")
        sources.append({"file": d.rel(p), **git_rev(p.parent)})

        def walk(v, pre):
            if isinstance(v, dict):
                for k, x in v.items():
                    walk(x, f"{pre}.{k}" if pre else str(k))
            else:
                flat[pre] = v
        walk(doc if isinstance(doc, dict) else {}, "")
        tops.update(str(k) for k in (doc or {}) if isinstance(doc, dict))

    def lookup(key):
        if key in flat:
            return {"": flat[key]}
        envs = {t: flat[f"{t}.{key}"] for t in sorted(tops) if f"{t}.{key}" in flat}
        return envs or None
    return lookup, sources


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--workspace", default=".", help="the workspace root (holds .dotcortex/); default: the current directory")
    ap.add_argument("--tasks", action="append", help="a task root (repeatable); default: the team's projects, else .dotcortex/tasks")
    ap.add_argument("--decisions", action="append", help="an extra decision log (repeatable)")
    ap.add_argument("--settings", action="append", default=[], help="a YAML/JSON settings file to check decisions' settings against (repeatable; off by default)")
    ap.add_argument("--board-url", help="this board's URL (default: boards.json decision_board)")
    ap.add_argument("--ticket-board-url", help="the ticket board's URL (default: boards.json ticket_board)")
    a = ap.parse_args()
    ws = Path(os.path.abspath(a.workspace))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    d = Diag(ws)

    def diag(level, code, msg, did=None):
        d.add(level, code, msg, decision=did)

    urls = board_urls(ws, a.ticket_board_url, a.board_url)
    roots = task_roots(ws, a.tasks)
    index = TicketIndex(roots)
    tickets = {}
    for it in index.items:
        if it["key"] in tickets:
            continue
        q = quick_ticket(it["path"])
        pk = index.resolve(q["parent"], it["project"])[0] if q["parent"] else None
        if not pk:  # a lettered child counts under its parent in the same project
            m = re.match(r"^([A-Z][A-Z0-9]{1,9}-\d+)[a-z]$", it["id"])
            pk = index.resolve(m.group(1), it["project"])[0] if m else None
            pk = pk if pk and index.by_key[pk]["project"] == it["project"] else None
        tickets[it["key"]] = {**q, "parent": pk, "id": it["id"], "project": it["project"], "archived": it["archived"], "file": d.rel(it["path"])}

    paths = decision_log_paths(ws, a.decisions)
    if not paths:
        diag("warn", "no-logs", f"No decision logs: add {TEAM_DIR / 'decisions' / 'team.yml'}")
    logs, entries, next_free = read_decision_logs(paths, d)
    logs_by = {l["log"]: l for l in logs}
    for l in logs:
        if l["schema"] != SCHEMA_VERSION:
            diag("warn", "schema", f"{l['log']}: schema is {l['schema']!r}; this build reads schema {SCHEMA_VERSION}")
        if l["scope"] not in ("team", "feature"):
            diag("warn", "scope", f"{l['log']}: scope {l['scope']!r} is not team or feature")
        fk = None
        if l["feature"]:
            fk, problem = index.resolve(str(l["feature"]))
            if not fk:
                diag("warn", "feature-missing", f"{l['log']}: feature {l['feature']} " + ("is in several projects: write it as <project>.<ID>" if problem == "ambiguous" else "is not a ticket"))
        elif l["scope"] == "feature":
            diag("info", "feature-unset", f"{l['log']}: a feature log without `feature:` (the parent ticket key)")
        l["feature_key"] = fk
        l["feature_title"] = (tickets.get(fk) or {}).get("title") if fk else None
        if not l["owner"]:
            diag("info", "log-owner", f"{l['log']}: no owner (the default owner for entries without one)")

    lookup, settings_sources = load_settings(a.settings, d) if a.settings else (None, [])
    ids = {e["id"] for e in entries}
    base = lambda k: re.sub(r"[a-z]$", "", k) if k else k
    built = []
    for e0 in entries:
        dd = e0
        did = dd["id"]
        log = logs_by.get(dd["log"]) or {}
        mrank = {m.get("key"): i for i, m in enumerate(log.get("milestones") or [])}
        hint = log_project_hint(log, index)
        issues_before = len(d.items)
        if not D_ID_RE.match(did):
            diag("error", "id", f"id {did!r} is not D<n>", did)
        for k in dd:
            if k not in KNOWN and k != "duplicate_of":
                diag("info", "unknown-field", f"{did}: unknown field {k!r} (kept, not shown)", did)
        for k in ("title", "question"):
            if not dd.get(k):
                diag("error", "missing-" + k, f"{did}: no {k}", did)
        st = dd.get("status")
        if st not in STATUSES_D:
            diag("error", "status", f"{did}: status {st!r} is not one of {', '.join(STATUSES_D)}", did)
        if not dd["owner"] and st == "open":
            diag("warn", "no-owner", f"{did}: nobody owns it (set `owner` on the decision or the log)", did)
        if dd.get("follow_up_status") and dd["follow_up_status"] not in FOLLOW_UP:
            diag("warn", "follow-up-status", f"{did}: follow_up_status {dd['follow_up_status']!r} is not one of {', '.join(FOLLOW_UP)}", did)
        for k in ("answered_at", "deferred_at"):
            v = dd.get(k)
            if v is not None and not (isinstance(v, str) and DATE_RE.match(v)):
                diag("error", "date", f"{did}: {k} {v!r} must be a quoted YYYY-MM-DD string", did)
        if st == "open":
            b = dd.get("blocks")
            if (b is not None and b != "later" and b not in mrank) or (b is None and mrank):
                diag("warn", "blocks", f"{did}: blocks {b!r} is not a milestone key of {dd['log']} (or later)", did)
            if dd.get("priority") is not None and dd.get("priority") not in PRIORITIES:
                diag("warn", "priority", f"{did}: priority {dd.get('priority')!r} is not one of {', '.join(PRIORITIES)}", did)
            if dd.get("answer"):
                diag("warn", "open-with-answer", f"{did}: open but has an answer; set status: answered or clear it", did)
        if st == "answered":
            for k in ("answer", "answered_at", "answered_by"):
                if not dd.get(k):
                    diag("error", "answered-missing", f"{did}: answered without {k}", did)
        # Superseded by another decision (superseded_by: D<n>), or moved onto its ticket as an ask under the
        # in-flight rule (moved_to: "<ticket key>:<ask>", with superseded_note). Either needs a valid target.
        mv = MOVED_RE.fullmatch(str(dd.get("moved_to") or ""))
        moved_key = index.resolve(mv.group(1), hint)[0] if mv else None
        if st == "superseded" and dd.get("superseded_by") not in ids and not mv:
            diag("error", "superseded-by", f"{did}: superseded without a target: superseded_by {dd.get('superseded_by')!r} is not a decision id and moved_to isn't '<ticket>:<ask>'", did)
        if dd.get("moved_to") and not mv:
            diag("warn", "moved-to", f"{did}: moved_to {dd.get('moved_to')!r} isn't '<ticket>:<ask number>'", did)
        if dd.get("kind") is not None and dd.get("kind") not in KINDS:
            diag("warn", "kind", f"{did}: kind {dd.get('kind')!r} is not one of {', '.join(KINDS)}", did)
        if dd.get("deferred_at") and st != "open":
            diag("warn", "deferred-closed", f"{did}: deferred_at on a {st} decision", did)

        opts = [o for o in as_list(dd.get("options")) if isinstance(o, dict)]
        keys = [o.get("key") for o in opts]
        if len(keys) != len(set(keys)) or None in keys:
            diag("error", "option-keys", f"{did}: option keys must be present and unique", did)
        if sum(1 for o in opts if o.get("built")) > 1:
            diag("error", "option-built", f"{did}: more than one option is marked built", did)
        if set(keys) & {"default", "custom", "defer"}:
            diag("error", "option-reserved", f"{did}: option keys default/custom/defer are reserved for the board", did)
        items = [i for i in as_list(dd.get("items")) if isinstance(i, dict)]
        iids = [str(i.get("id")) for i in items]
        if len(iids) != len(set(iids)):
            diag("error", "item-ids", f"{did}: item ids must be unique", did)

        # settings: recorded vs live (only with --settings)
        srows = []
        for s in as_list(dd.get("settings")):
            s = {"key": s} if isinstance(s, str) else (s if isinstance(s, dict) else {})
            key = s.get("key")
            row = {"key": key, "recorded": s.get("value"), "has_recorded": "value" in s, "note": s.get("note"),
                   "live": None, "live_found": False, "envs": {}, "match": None, "checked": bool(lookup)}
            envs = lookup(key) if lookup and key else None
            if envs:
                row.update(live_found=True, envs=envs, live=envs.get("", envs.get("shared", next(iter(envs.values())))))
                live = row["live"]
                if not (isinstance(live, str) and live.startswith("<erb>")) and row["has_recorded"]:
                    row["match"] = live == row["recorded"]
                    if not row["match"] and st == "open":
                        diag("warn", "setting-drift", f"{did}: {key} is {json.dumps(live, default=str)} in the settings, the log records {json.dumps(row['recorded'], default=str)}", did)
            elif lookup:
                diag("info", "setting-absent", f"{did}: {key} is not in the settings files" + (f" ({s.get('note')})" if s.get("note") else ""), did)
            srows.append(row)

        # tickets: title, status, criteria this decision answers
        trows = []
        for ref, key, crit_refs, problem in decision_tickets(dd, hint, index):
            info = tickets.get(key) if key else None
            row = {"id": ref, "key": key or ref, "found": bool(info), "label": info["id"] if info else ref,
                   "project": info and info["project"], "title": info and info["title"], "status": info and info["status"],
                   "archived": bool(info and info["archived"]), "file": info and info["file"], "criteria": []}
            if problem == "ambiguous":
                diag("warn", "ticket-ambiguous", f"{did}: ticket {ref} is in several projects: write it as <project>.{ref}", did)
            elif not info:
                diag("warn", "ticket-missing", f"{did}: ticket {ref} not found in the task roots", did)
            for cref in crit_refs:
                hit = None
                if info:
                    hit = next((c for c in info["criteria"] if c["id"] == cref), None) or \
                          next((c for c in info["criteria"] if c["text"].lower().startswith(cref.lower())), None)
                    if not hit:
                        diag("warn", "criterion-missing", f"{did}: {row['key']} has no criterion matching {cref!r}", did)
                row["criteria"].append({"ref": cref, "found": bool(hit), "id": hit and hit["id"], "text": hit and hit["text"],
                                        "checked": bool(hit and hit["checked"]), "line": hit and hit["line"]})
            trows.append(row)

        # What it gates: explicit `gates` (ticket refs, or true/false), else tickets named in a leading "Gates ..."
        # sentence (the linked ticket or its children), else linked tickets that haven't started.
        ctx = str(dd.get("context") or "").strip()
        linked = {r["key"] for r in trows}
        named = []
        if ctx.lower().startswith("gates"):
            for ref in ref_strings(ctx.split(". ")[0]):
                k = index.resolve(ref, hint)[0] or ref
                if k in linked or base(k) in linked:
                    named.append(k)
        not_started = [r["key"] for r in trows if r["found"] and not r["archived"] and (r["status"] or "") in NOT_STARTED]
        g = dd.get("gates")
        if isinstance(g, list):
            gates_ids = []
            for ref in g:
                k = index.resolve(str(ref), hint)[0]
                if not k and not index.resolve(base(str(ref)), hint)[0]:
                    diag("warn", "gates-missing", f"{did}: gates names {ref}, which is not a ticket (nor a child of one)", did)
                gates_ids.append(k or str(ref))
        else:
            gates_ids = [] if g is False else list(dict.fromkeys(named or not_started))
        gating = bool(gates_ids) if g is not True else True
        unblocks = []
        for k in gates_ids:
            info = tickets.get(k)
            parent = tickets.get(base(k)) if not info and base(k) != k else None
            unblocks.append({"id": k, "found": bool(info), "title": info and info["title"], "status": info and info["status"],
                             "parent": base(k) if parent else None, "parent_title": parent and parent["title"]})
        rec = [o.get("key") for o in opts if RECOMMENDED_RE.search(str(o.get("label") or "") + " " + str(o.get("detail") or ""))]
        if dd.get("recommended") is not None:
            if dd["recommended"] in keys:
                rec = [dd["recommended"]]
            else:
                diag("warn", "recommended", f"{did}: recommended {dd['recommended']!r} is not an option key", did)
        if st == "open" and opts and len(rec) != 1:
            diag("info", "no-recommendation", f"{did}: no recommended option (add `recommended: <key>` or \"(recommended)\" in one label)", did)

        entry = {k: v for k, v in dd.items()}
        entry.update(id=did, options=opts, items=items, settings=srows, tickets=trows, owner=dd["owner"], log=dd["log"],
                     log_title=log.get("title") or dd["log"], duplicate=bool(dd.get("duplicate_of")),
                     moved_key=moved_key, moved_n=mv.group(2) if mv else None)
        entry["review_notes"] = as_list(dd.get("review_notes"))
        entry["links"] = sorted({n.get("ref") for n in entry["review_notes"] if isinstance(n, dict) and n.get("ref")} | set(as_list(dd.get("links"))))
        entry["deferred"] = bool(dd.get("deferred_at")) and st == "open"
        entry["gating"] = gating and st == "open"
        entry["unblocks"] = unblocks
        entry["recommended"] = rec[0] if len(rec) == 1 else None
        entry["nothing_built"] = not dd.get("default_built") and not any(o.get("built") for o in opts)
        # The board's lane for an open decision: "now" blocks a milestone, "later" doesn't (blocks: later) or was deferred.
        entry["lane"] = ("later" if entry["deferred"] or dd.get("blocks") == "later" else "now") if st == "open" else st
        entry["milestone"] = next((m for m in log.get("milestones") or [] if m.get("key") == dd.get("blocks")), None)
        entry["milestone_rank"] = mrank.get(dd.get("blocks"), len(mrank))
        # Kind: does the answer decide what gets built (shapes), or confirm something already built (confirms)?
        started = [r["key"] for r in trows if r["found"] and (r["archived"] or (r["status"] or "") not in UNBUILT)]
        if dd.get("kind") in KINDS:
            entry["kind"], entry["kind_source"] = dd["kind"], "the log says so"
        else:
            entry["kind"] = "confirms" if started else "shapes"
            entry["kind_source"] = f"{started[0]} has started" if started else ("no ticket has started" if trows else "no ticket")
        # Category: the log, then the ticket family (a lettered child counts under its parent).
        first = trows[0]["key"] if trows and trows[0]["found"] else None
        fam = ((tickets.get(first) or {}).get("parent") or first) if first else "none"
        finfo = tickets.get(fam)
        entry["family"] = f"{dd['log']}/{fam}"
        entry["family_ticket"] = fam if finfo else None
        ft = re.sub(r"^Decide:\s*", "", finfo["title"]) if finfo else "Not tied to a ticket"
        entry["family_title"] = ft[:1].upper() + ft[1:]
        # The one-click "keep what's built" answer: the built option; for built work without one, an option whose
        # label starts with "Keep"; else `default` when the log records what's built. None: nothing is built (the
        # block policy builds nothing), so every answer is follow-up work.
        keep = next((o.get("key") for o in opts if o.get("built")), None)
        if keep is None and entry["kind"] == "confirms":
            keep = next((o.get("key") for o in opts if re.match(r"^\s*keep\b", str(o.get("label") or ""), re.I)), None)
        if keep is None and (entry["kind"] == "confirms" or not opts) and dd.get("default_built"):
            keep = "default"
        entry["keep_key"] = keep
        entry["fingerprint"] = fp_obj({k: v for k, v in dd.items() if k not in ("log", "owner", "duplicate_of")})
        entry["issues"] = [x for x in d.items[issues_before:] if x["level"] in ("warn", "error")] + \
                          [x for x in d.items if x["code"] == "duplicate-id" and x["decision"] == did and dd.get("duplicate_of")]
        built.append(entry)

    prio = {p: i for i, p in enumerate(PRIORITIES)}
    num = lambda e: int(re.sub(r"\D", "", e["id"]) or 0)
    log_rank = {l["log"]: i for i, l in enumerate(logs)}

    def order(e):
        st = e.get("status")
        if st == "open":
            return (0 if not e["deferred"] else 1, e["milestone_rank"], 0 if e["gating"] else 1, prio.get(e.get("priority"), 9), num(e))
        if st == "answered":
            return (2, -int(str(e.get("answered_at") or "0000-00-00").replace("-", "") or 0), 0, 0, num(e))
        return (3, 0, 0, 0, num(e))
    built.sort(key=order)

    counts = {"open": 0, "deferred": 0, "answered": 0, "superseded": 0, "now": 0, "later": 0}
    for e in built:
        k = "deferred" if e["deferred"] else e.get("status")
        counts[k] = counts.get(k, 0) + 1
        if e.get("status") == "open":
            counts[e["lane"]] += 1

    # Sidebar: each log, then its families in order of their most urgent open decision (Now before Later, then
    # milestone order); fully decided families last.
    fams = {}
    for e in built:
        f = fams.setdefault(e["family"], {"id": e["family"], "log": e["log"], "ticket": e["family_ticket"], "title": e["family_title"],
                                          "total": 0, "open": 0, "rank": None,
                                          "status": (tickets.get(e["family_ticket"]) or {}).get("status"), "tickets": []})
        for r in e["tickets"]:
            if r["key"] not in f["tickets"]:
                f["tickets"].append(r["key"])
        if e.get("status") == "superseded":
            continue
        f["total"] += 1
        if e.get("status") == "open":
            f["open"] += 1
            rk = (1 if e["lane"] == "later" else 0, e["milestone_rank"])
            if f["rank"] is None or rk < f["rank"]:
                f["rank"] = rk
    families = sorted(fams.values(), key=lambda f: (log_rank.get(f["log"], 99), f["rank"] is None, f["rank"] or (9, 99), f["id"]))
    for f in families:
        f.pop("rank")
        f["tickets"].sort()
    kinds = {k: sum(1 for e in built if e.get("status") == "open" and e["kind"] == k) for k in KINDS}
    people = people_list([e["owner"] for e in built if e.get("status") == "open"] + [e["owner"] for e in built] + [l["owner"] for l in logs])

    data = {
        "board_version": BOARD_VERSION, "schema_version": SCHEMA_VERSION,
        "board_url": urls["decision_board"], "ticket_board_url": urls["ticket_board"],
        "generated_at": dt.datetime.now().astimezone().isoformat(timespec="minutes"),
        "title": str(workspace_config(ws).get("project_name") or ws.name),
        "source": {"logs": [l["file"] for l in logs], **(git_rev(paths[0].parent) if paths else {"rev": None, "dirty": None})},
        "settings_sources": settings_sources,
        "multi_project": index.multi, "projects": [p for p, _ in roots],
        "logs": [{k: l.get(k) for k in ("log", "title", "scope", "feature", "feature_key", "feature_title", "owner", "file", "milestones")} for l in logs],
        "next_decision_id": next_free, "people": people,
        "counts": counts, "kinds": kinds, "families": families,
        "diagnostics": d.items, "decisions": built,
    }
    (out / "decisions-data.json").write_text(json.dumps(data, indent=1, ensure_ascii=False, default=str), encoding="utf-8")
    shutil.copy2(HERE / "board.html", out / "index.html")
    lv = {}
    for x in d.items:
        lv[x["level"]] = lv.get(x["level"], 0) + 1
    print("decision logs: " + (", ".join(f"{l['log']} ({l['scope']})" for l in logs) or "none"))
    print(f"{len(built)} decisions -> {out}  {counts}  open by kind: shapes new work {kinds['shapes']}, confirms built work {kinds['confirms']}  "
          f"diagnostics: {lv}")
    print(f"next free decision id: {next_free}")
    print(f"owners: {', '.join(people) or 'none'}")
    for x in d.items:
        if x["level"] in ("warn", "error"):
            print(f"  {x['level']}: {x['message']}")


if __name__ == "__main__":
    main()
