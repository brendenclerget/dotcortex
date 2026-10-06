#!/usr/bin/env python3
"""Build the team ticket board's data from the team's task roots.

Usage (from the workspace root):
  build_board.py --out DIR [--tasks DIR ...] [--decisions FILE ...] [--closed-days 14]
                 [--board-url URL] [--decision-board-url URL] [--worktrees DIR] [--repo DIR ...]

Writes DIR/index.html (the page) and DIR/board-data.json. Publish DIR/index.html with DIR/board-data.json as a
supporting file.

Task roots: every .dotcortex/layers/team/projects/*/ that has a .ticket_counter, else .dotcortex/tasks (--tasks
overrides, repeatable). With more than one root a ticket's key is <project>.<ID>; with one it is the plain ID.
Decision logs: .dotcortex/layers/team/decisions/*.yml (plus --decisions FILE, repeatable).

The ticket core is described in SKILL.md. The parser also reads older tickets unchanged (compatibility reader):
bold metadata fields, `##`/`###` headings, acceptance-heading aliases, `Notes` / `Notes / Log`, Owner for Assignee.
Nothing is inferred as complete: missing criteria are "unavailable", never 0% or done.
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
PRIORITIES = ["CRITICAL", "HIGH", "MEDIUM", "LOW"]
TYPES = ["TASK", "PARENT", "SUBTASK", "FOLLOW-UP"]
REVIEWS = ["none", "decision-needed", "closure-proposed"]
EVIDENCE_KINDS = ["commit", "screenshot", "test", "decision"]
KNOWN_FIELDS = {"schema", "status", "priority", "type", "created", "updated", "completed", "parent",
                "follow-up for", "depends on", "review", "owner", "assignee", "subtasks", "last updated"}

# Section aliases (lower-cased heading text -> canonical key). "Needs from <anyone>" is the asks section.
SECTION_ALIASES = {
    "description": "description", "overview": "description", "feature specification": "spec",
    "acceptance criteria": "criteria", "findings (acceptance criteria)": "criteria",
    "findings": "findings",
    "what shipped": "shipped", "evidence": "evidence",
    "needs from assignee": "needs", "needs from owner": "needs", "needs from you": "needs",
    "notes / log": "log", "notes": "log", "log": "log", "notes/log": "log",
    "subtasks": "subtasks", "completion summary": "completion",
}
NEEDS_HEAD_RE = re.compile(r"^needs from \S+", re.I)
EMPTY_MARKERS = re.compile(r"^_?(not recorded|none( recorded| yet)?|n/?a|nothing yet)\.?_?$", re.I)

HEAD_RE = re.compile(r"^(#{2,4})\s+(.+?)\s*$")
CHECK_RE = re.compile(r"^(\s*)[-*]\s+\[( |x|X)\]\s+(.*)$")
BAD_CHECK_RE = re.compile(r"^\s*[-*]?\s*\[(?:\s{2,}|[^ xX\]]|)\]|^\s*[-*]\[( |x|X)\]|^\s*[-*]\s+\[( |x|X)\]\S")
ASK_HEAD_RE = re.compile(r"^(\d+)[.)]\s+(.+?)\s*$")          # "### 1. Should we ...?"
ASK_FIELD_RE = re.compile(r"^[-*]\s+(?:\*\*)?([A-Za-z][A-Za-z ]*?)(?::\*\*|\*\*:|:)\s*(.*)$")
ASK_OPT_RE = re.compile(r"^\s+[-*]\s+(?:\*\*)?\(?([a-z])[).](?:\*\*)?\s+(.+)$")
ASK_KINDS = {"question": "Question", "confirm closure": "Confirm closure", "review": "Review", "approve": "Approve"}
ASK_FIELDS = {"kind": "kind", "why": "why", "blocks": "why", "options": "options", "recommended": "recommended",
              "built today": "built", "built": "built", "decision": "decision", "answered": "answered", "for": "for"}
D_RE = re.compile(r"\b(D\d+)\b")
# An unchecked criterion tracked by another ticket: "…; covered by APP-056 (pilot metrics)". It stays unchecked here
# (it isn't met on this ticket); the board asks the assignee to close or keep the ticket instead.
REF_TXT = r"(?:[A-Za-z0-9][A-Za-z0-9_-]*\.)?" + GENERIC_TID
COVERED_RE = re.compile(r"\bcovered by\s+((?:" + REF_TXT + r"(?:\s*(?:,|and|&|/)\s*)?)+)", re.I)
NOTHING_BUILT_RE = re.compile(r"^\s*(nothing|none|no)\b", re.I)

# One primary state per ticket, in precedence order. The page refines it with the saved answers and calls, which
# only it can see (see SKILL.md, "Ticket states").
STATES = [
    ("needs", "Needs you"), ("ready", "Ready to close"), ("covered", "Close or keep?"), ("blocked", "Blocked"), ("work", "Work left"),
    ("progress", "In progress"), ("notstarted", "Not started"), ("parked", "Parked"), ("planning", "Planning"), ("done", "Done"),
]
STATE_LABEL = dict(STATES)
BUILT_KEY_RE = re.compile(r"^\(?([a-z])\)(?=[\s,.:;]|$)")

LANES = [
    ("review", "In review", {"REVIEW"}),
    ("planning", "Planning", {"PLANNING"}),
    ("active", "In progress", {"IN_PROGRESS"}),
    ("blocked", "Blocked", {"BLOCKED"}),
    ("todo", "To do", {"TODO"}),
]


def plural(n, one, many=None):
    return f"{n} {one if n == 1 else (many or one + 's')}"


def fp(s):
    return hashlib.sha1(s.encode("utf-8")).hexdigest()[:12]


def split_sections(lines):
    """Return [{level, title, key, line, body}] for ##/### headings (1-based line numbers)."""
    secs, cur = [], None
    for i, raw in enumerate(lines):
        m = HEAD_RE.match(raw)
        if m and len(m.group(1)) == 3 and cur is not None and cur["key"] == "needs" and ASK_HEAD_RE.match(m.group(2).strip()):
            cur["body"].append((i + 1, raw))  # an explicit ask ("### 1. ...?") stays inside the Needs section
            continue
        if m and len(m.group(1)) in (2, 3):
            title = m.group(2).strip()
            key = SECTION_ALIASES.get(title.lower().rstrip(":"))
            if key is None and NEEDS_HEAD_RE.match(title):
                key = "needs"  # "## Needs from assignee (queued as D27+ ...)", or an older name
            cur = {"level": len(m.group(1)), "title": title, "key": key, "line": i + 1, "body": []}
            secs.append(cur)
        elif cur is not None:
            cur["body"].append((i + 1, raw))
    return secs


def bullets(body):
    out = []
    for ln, raw in body:
        m = re.match(r"^\s*[-*]\s+(?!\[[ xX]\])(.+)$", raw)
        if m:
            t = m.group(1).strip()
            if not EMPTY_MARKERS.match(t):
                out.append({"text": t, "line": ln})
        elif raw.strip() and out and raw.startswith("  "):
            out[-1]["text"] += " " + raw.strip()
    if not out:  # a paragraph-only section: keep paragraphs as items
        para = " ".join(r.strip() for _, r in body if r.strip() and not r.strip().startswith("|"))
        if para and not EMPTY_MARKERS.match(para):
            out.append({"text": para, "line": body[0][0] if body else None})
    return out


def parse_evidence(body, d, path, key):
    rows, header = [], None
    for ln, raw in body:
        s = raw.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue
        if header is None:
            header = [c.lower() for c in cells]
            continue
        row = dict(zip(header, cells))
        ev = {"criterion": row.get("criterion", ""), "kind": row.get("kind", "").lower(),
              "ref": row.get("reference", row.get("ref", "")), "result": row.get("result", ""), "line": ln}
        if ev["kind"] and ev["kind"] not in EVIDENCE_KINDS:
            d.add("warn", "evidence-kind", f"Evidence kind '{ev['kind']}' is not one of {', '.join(EVIDENCE_KINDS)}", path, ln, key)
        rows.append(ev)
    if not rows:  # free-form bullets are accepted too
        rows = [{"criterion": "", "kind": "", "ref": b["text"], "result": "", "line": b["line"]} for b in bullets(body)]
    return rows


def parse_needs(secs, d, path, key):
    """The Needs section -> (state, asks, legacy).

    state: "none" (the section says None), "explicit" (one or more "### N. question?" asks), "legacy" (free text
    the board can only show as bullets), "missing" (no section). Asks are self-contained: kind, question, for, why,
    options, recommended, built today, an optional D-number, and "Answered:" once an apply wrote it.
    """
    if not secs:
        return "missing", [], []
    asks, cur, field, pre = [], None, None, []
    for s in secs:
        for ln, raw in s["body"]:
            if re.match(r"^\s*<!--.*-->\s*$", raw):
                continue
            h = HEAD_RE.match(raw)
            am = ASK_HEAD_RE.match(h.group(2).strip()) if h and len(h.group(1)) == 3 else None
            if am:
                cur = {"n": int(am.group(1)), "question": am.group(2).strip(), "kind": None, "for": "", "why": "", "options": [],
                       "recommended": None, "recommended_note": "", "built": "", "decision": None, "answered": "",
                       "line": ln, "extra": []}
                asks.append(cur)
                field = None
                continue
            if cur is None:
                pre.append((ln, raw))
                continue
            if not raw.strip():
                continue
            om = ASK_OPT_RE.match(raw)
            if om and field == "options":
                cur["options"].append({"key": om.group(1), "text": om.group(2).strip(), "line": ln})
                continue
            fm = ASK_FIELD_RE.match(raw)
            if fm and not raw.startswith((" ", "\t")):
                name, val = fm.group(1).strip().lower(), fm.group(2).strip()
                field = ASK_FIELDS.get(name)
                if field is None:
                    cur["extra"].append({"name": fm.group(1).strip(), "text": val, "line": ln})
                    d.add("info", "needs-field", f"Ask {cur['n']}: unknown field '{fm.group(1).strip()}'", path, ln, key)
                elif field == "kind":
                    cur["kind"] = ASK_KINDS.get(val.lower().rstrip("."), None)
                    if not cur["kind"]:
                        d.add("warn", "needs-malformed", f"Ask {cur['n']}: Kind '{val}' isn't Question, Confirm closure, Review or Approve", path, ln, key)
                elif field == "decision":
                    m = D_RE.search(val)
                    cur["decision"] = m.group(1) if m else None
                elif field == "for":
                    cur["for"] = clean_person(val)
                elif field == "recommended":
                    m = re.match(r"^\(?([a-z])\)?(?:[\s.:,;-]+(.*))?$", val)
                    if m:
                        cur["recommended"], cur["recommended_note"] = m.group(1), (m.group(2) or "").strip(" -—")
                    else:
                        cur["recommended_note"] = val
                elif field != "options":
                    cur[field] = val
                continue
            if raw.startswith((" ", "\t")):  # continuation of the previous field or option (wrapped text)
                if field == "options" and cur["options"]:
                    cur["options"][-1]["text"] += " " + raw.strip()
                elif field in ("why", "built", "answered"):
                    cur[field] += " " + raw.strip()
                elif field == "recommended":
                    cur["recommended_note"] = (cur["recommended_note"] + " " + raw.strip()).strip()
                continue
            cur["extra"].append({"name": "", "text": raw.strip(), "line": ln})
    body_pre = [(ln, r) for ln, r in pre if r.strip()]
    if not asks:
        text = " ".join(r.strip() for _, r in body_pre)
        if not text or EMPTY_MARKERS.match(text):
            return "none", [], []
        d.add("warn", "needs-not-explicit", "The Needs section is free text, not explicit asks ('### 1. question?' with Kind, Why, "
              "Options, Recommended, Built today) or 'None.'", path, body_pre[0][0], key)
        return "legacy", [], bullets(body_pre)
    if body_pre:
        d.add("warn", "needs-not-explicit", "Text before the first '### N.' ask; move it into an ask or drop it", path, body_pre[0][0], key)
    seen_n = {}
    for a in asks:
        if a["n"] in seen_n:
            d.add("warn", "needs-malformed", f"Ask number {a['n']} repeats (first at line {seen_n[a['n']]})", path, a["line"], key)
        seen_n[a["n"]] = a["line"]
        a["fingerprint"] = fp(a["question"])
        probs = []
        if not a["kind"]:
            probs.append("no Kind")
        if not a["question"].rstrip("*_ ").endswith("?"):
            probs.append("the question doesn't end in '?'")
        if not a["why"] and not a["answered"]:
            probs.append("no Why")
        if a["kind"] == "Question" and not a["options"] and not a["decision"] and not a["answered"]:
            probs.append("a Question needs Options (or a Decision: D-number)")
        if a["options"] and a["recommended"] and a["recommended"] not in {o["key"] for o in a["options"]}:
            probs.append(f"Recommended ({a['recommended']}) isn't one of the options")
        if probs:
            d.add("warn", "needs-malformed", f"Ask {a['n']}: " + "; ".join(probs), path, a["line"], key)
    return "explicit", asks, []


def parse(entry, d):
    """One ticket file -> its board record. `entry` comes from TicketIndex (key, id, project, path, archived)."""
    path, key, archived = entry["path"], entry["key"], entry["archived"]
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    head = next(((i, re.match(r"^# (\S+?):\s*(.+)$", l)) for i, l in enumerate(lines) if l.startswith("# ")), (None, None))
    if not head[1]:
        d.add("error", "no-title", "No '# <ID>: Title' line; ticket skipped", path, 1)
        return None
    tid, title = entry["id"], head[1].group(2).strip()
    if head[1].group(1) != tid:
        d.add("warn", "id-filename", f"Title id {head[1].group(1)} doesn't match file name {path.name}", path, head[0] + 1, key)

    # Metadata block: bold fields between the title and the first heading
    fields, field_lines = {}, {}
    for i in range(head[0] + 1, len(lines)):
        if HEAD_RE.match(lines[i]):
            break
        m = FIELD_RE.match(lines[i])
        if m:
            k = m.group(1).strip().lower()
            if k not in KNOWN_FIELDS:
                d.add("info", "unknown-field", f"Unknown metadata field '{m.group(1)}'", path, i + 1, key)
            fields[k], field_lines[k] = m.group(2), i + 1

    def fline(k):
        return field_lines.get(k, head[0] + 1)

    raw_status = fields.get("status", "")
    status, status_note, problem = normalize_status(raw_status)
    if problem == "missing-status":
        d.add("warn", "missing-status", "No Status field; read as TODO", path, head[0] + 1, key)
    elif problem == "status-legacy":
        d.add("warn", "status-legacy", "Status BACKLOG is legacy; read as TODO", path, fline("status"), key)
    elif problem == "bad-status":
        d.add("warn", "bad-status", f"Status '{raw_status}' isn't one of {'|'.join(STATUSES)}; read as TODO", path, fline("status"), key)
    if status_note:
        d.add("info", "status-suffix", f"Status carries '({status_note})'; move it to the Review field", path, fline("status"), key)

    priority = (fields.get("priority", "").split() or [""])[0].upper()
    if priority and priority not in PRIORITIES:
        d.add("warn", "bad-priority", f"Priority '{fields['priority']}' isn't one of {'|'.join(PRIORITIES)}", path, fline("priority"), key)
    for k in ("created", "updated", "completed"):
        v = fields.get(k)
        if v and not DATE_RE.match(v.split()[0]):
            d.add("warn", "bad-date", f"{k.title()} '{v}' isn't YYYY-MM-DD", path, fline(k), key)

    ttype = fields.get("type", "").strip().upper() or None
    if ttype and ttype not in TYPES:
        d.add("warn", "bad-type", f"Type '{fields['type']}' isn't one of {'|'.join(TYPES)}", path, fline("type"), key)

    review_field = fields.get("review", "").strip().lower() or None
    if review_field and review_field not in REVIEWS:
        d.add("warn", "bad-review", f"Review '{fields['review']}' isn't one of {'|'.join(REVIEWS)}", path, fline("review"), key)
        review_field = None

    parent_refs = ref_strings(fields.get("parent", ""))
    if fields.get("parent") and not parent_refs:
        d.add("warn", "bad-parent", f"Parent '{fields['parent']}' isn't a ticket id", path, fline("parent"), key)
    follow_refs = ref_strings(fields.get("follow-up for", ""))[:1]
    depends_refs = ref_strings(fields.get("depends on", ""))
    assignee = clean_person(fields.get("assignee") or fields.get("owner"))

    secs = split_sections(lines)
    by_key = {}
    for s in secs:
        if s["key"]:
            by_key.setdefault(s["key"], []).append(s)

    # Criteria: authoritative from the criteria section(s); plain "Findings" is a secondary group
    criteria, seen_ids = [], {}
    crit_secs = by_key.get("criteria", [])
    groups = [(s, "Acceptance criteria" if s["title"].lower() == "acceptance criteria" else s["title"]) for s in crit_secs]
    groups += [(s, s["title"]) for s in by_key.get("findings", [])]
    if by_key.get("findings") and crit_secs:
        d.add("info", "findings-group", "Separate '## Findings' checklist shown as its own group and counted with the criteria", path, by_key["findings"][0]["line"], key)
    for s, label in groups:
        n = 0
        for ln, raw in s["body"]:
            m = CHECK_RE.match(raw)
            if not m:
                if raw.strip() and BAD_CHECK_RE.match(raw):
                    d.add("warn", "malformed-checkbox", f"Malformed checkbox: {raw.strip()[:60]}", path, ln, key)
                continue
            if m.group(1):  # nested sub-bullet checkbox: part of the parent item
                if criteria:
                    criteria[-1]["text"] += " · " + m.group(3).strip()
                continue
            n += 1
            body = m.group(3).strip()
            cid, src = None, "position"
            am, cm = AC_ID_RE.match(body), CODE_ID_RE.match(body)
            if am:
                cid, body, src = am.group(1), am.group(2), "explicit"
            elif cm:
                cid, body, src = cm.group(1), cm.group(2), "code"
            if not cid:
                cid = f"AC{len(criteria) + 1}"
            if cid in seen_ids:
                d.add("warn", "duplicate-criterion", f"Criterion id {cid} repeats (first at line {seen_ids[cid]})", path, ln, key)
                cid = f"{cid}#{ln}"
            seen_ids[cid] = ln
            checked = m.group(2).lower() == "x"
            cov = COVERED_RE.search(body)
            criteria.append({"id": cid, "text": body, "checked": checked, "line": ln, "group": label, "id_source": src,
                             "covered_refs": ref_strings(cov.group(1)) if cov and not checked else []})
        if n == 0:
            d.add("warn", "empty-criteria", f"'{s['title']}' has no checklist items", path, s["line"], key)
    if not crit_secs and not by_key.get("findings"):
        d.add("warn", "criteria-missing", "No Acceptance Criteria section: criteria unavailable", path, head[0] + 1, key)

    # Subtasks list (validated later against Parent-derived children)
    subtask_list = []
    for s in by_key.get("subtasks", []):
        for ln, raw in s["body"]:
            if re.match(r"^\s*[-*]\s+", raw):
                ids = ref_strings(raw)
                if ids:
                    subtask_list.append({"ref": ids[0], "line": ln})
    if fields.get("subtasks"):
        subtask_list += [{"ref": i, "line": fline("subtasks")} for i in ref_strings(fields["subtasks"])]

    shipped = [b for s in by_key.get("shipped", []) for b in bullets(s["body"])]
    evidence = [e for s in by_key.get("evidence", []) for e in parse_evidence(s["body"], d, path, key)]
    needs_state, asks, legacy_needs = parse_needs(by_key.get("needs", []), d, path, key)
    for a in asks:
        a["for_explicit"] = bool(a["for"])
        a["for"] = a["for"] or assignee
    needs = [dict(b, inferred=False) for b in legacy_needs]
    for e in evidence:
        c = e["criterion"]
        if c and c.lower() not in ("all", "-", "—") and not any(x["id"] == c for x in criteria):
            d.add("warn", "evidence-ref", f"Evidence refers to unknown criterion '{c}'", path, e["line"], key)
    completion = " ".join(r.strip() for s in by_key.get("completion", []) for _, r in s["body"] if r.strip())

    log = []
    for s in by_key.get("log", []):
        for ln, raw in s["body"]:
            if re.match(r"^\s*[-*] ", raw):
                log.append({"text": raw.strip()[2:].strip(), "line": ln})
            elif raw.strip() and log:
                log[-1]["text"] += " " + raw.strip()

    description = "\n".join(r for s in by_key.get("description", []) for _, r in s["body"]).strip()
    summary = description.split("\n\n")[0].strip()

    # The ticket core (SKILL.md): what an older ticket is missing. Read anyway; migrate_tickets.py adds it.
    core_missing = []
    if not raw_status:
        core_missing.append("Status")
    if not assignee:
        core_missing.append("Assignee")
    if not review_field:
        core_missing.append("Review")
    if "needs" not in by_key:
        core_missing.append("Needs from assignee")
    if any(c["id_source"] == "position" for c in criteria):
        core_missing.append("criterion ids")
    if core_missing and not archived:
        d.add("info", "core-missing", f"Older ticket format: no {', '.join(core_missing)}", path, head[0] + 1, key)

    shown = {"criteria", "findings", "shipped", "evidence", "needs", "log", "description"}
    other = [{"title": s["title"], "level": s["level"], "markdown": "\n".join(r for _, r in s["body"]).strip()}
             for s in secs if s["key"] not in shown]

    done = sum(1 for c in criteria if c["checked"])
    return {
        "key": key, "id": tid, "project": entry["project"], "title": title, "file": d.rel(path), "line": head[0] + 1,
        "type": ttype, "status": status, "status_raw": raw_status, "status_note": status_note,
        "priority": priority, "created": fields.get("created", ""), "updated": fields.get("updated", ""),
        "completed": fields.get("completed", ""), "assignee": assignee,
        "parent_refs": parent_refs, "follow_refs": follow_refs, "depends_refs": depends_refs,
        "review_field": review_field, "subtask_list": subtask_list,
        "summary": summary, "description": description,
        "criteria": criteria, "criteria_state": "ok" if criteria else "unavailable",
        "ac_done": done, "ac_total": len(criteria),
        "shipped": shipped, "evidence": evidence, "needs": needs, "needs_state": needs_state, "asks": asks,
        "completion": completion, "core_missing": core_missing, "legacy": bool(core_missing),
        "log": log, "log_count": len(log), "latest": log[-1]["text"] if log else "",
        "other_sections": other, "archived": archived, "markdown": text,
        "fingerprint": fp(text),
    }


def built_key(ask, dec):
    """The answer that means "keep what's built, no change": the decision's built option (or `default` when it
    records what's built and has no options), the option named at the start of Built today ("(a), on main"), or
    approve/ok for a plain Approve/Review on something built. None when nothing is built or it can't be read: then
    every answer to that ask is follow-up work (the block policy builds nothing)."""
    if dec:
        opts = [o for o in as_list(dec.get("options")) if isinstance(o, dict)]
        if not opts:
            return "default" if dec.get("default_built") else None
        built = [str(o.get("key")) for o in opts if o.get("built")]
        return built[0] if len(built) == 1 else None
    if ask["options"]:
        m = BUILT_KEY_RE.match((ask["built"] or "").strip())
        return m.group(1) if m and m.group(1) in {o["key"] for o in ask["options"]} else None
    if ask["built"] and NOTHING_BUILT_RE.match(ask["built"]):
        return None
    return {"Approve": "approve", "Review": "ok"}.get(ask["kind"])


def id_ranges(ids):
    """D45, D46, D47 -> "D45–D47"; keeps order, joins runs of consecutive numbers."""
    out, run = [], []
    for i in ids:
        m = re.match(r"^([A-Z]+)(\d+)$", i)
        if run and m and run[-1][0] == m.group(1) and int(m.group(2)) == run[-1][1] + 1:
            run.append((m.group(1), int(m.group(2)), i))
            continue
        if run:
            out.append(run[0][2] if len(run) == 1 else f"{run[0][2]}–{run[-1][2]}")
        run = [(m.group(1), int(m.group(2)), i)] if m else []
        if not m:
            out.append(i)
    if run:
        out.append(run[0][2] if len(run) == 1 else f"{run[0][2]}–{run[-1][2]}")
    return ", ".join(out)


def owners_of(ids, all_decisions):
    return ", ".join(people_list((all_decisions.get(x) or {}).get("owner") for x in ids)) or "the decision's owner"


def derive_state(t, by_key, all_decisions):
    """One primary state per ticket. Precedence: done > planning > needs > blocked > work > ready > progress >
    notstarted > parked. Blocked = waiting on a person now (a "now"-lane decision) or on another ticket; Parked =
    otherwise ready to close, held only by decisions their owners set aside (Later / Deferred).

    `state` is what the ticket file says; `state_base` is the same ignoring open asks and open decisions: what the
    ticket becomes once they're answered, if every answer keeps what's built. The page applies saved answers and
    calls on top (see SKILL.md, "Ticket states")."""
    crit = t["criteria_state"] == "ok"
    ac = f"AC {t['ac_done']}/{t['ac_total']}" if crit else "No criteria"
    left = t["ac_total"] - t["ac_done"] - t.get("ac_covered", 0)  # unchecked and not covered by another ticket
    fam = t.get("family")
    kids_open = fam["children"] - fam["done"] if fam else 0
    now = [a for a in t["asks"] if a["state"] == "open" and a.get("tier") == "now"]
    closure_ask = any(a["state"] == "open" and a.get("tier") == "closure" for a in t["asks"])
    closed = t["lane"] == "closed"
    reviewish = t["status"] == "REVIEW" or t["review"]["state"] == "closure-proposed" or closure_ask
    waiting = [x for x in t["depends_on"] if x in by_key and by_key[x]["lane"] != "closed"]
    t["close_eligible_own"] = bool(not closed and t["status"] not in ("PLANNING", "TODO", "BLOCKED") and crit and left == 0 and not t.get("ac_covered")
                                   and not t["needs"] and reviewish and not waiting)
    t["close_eligible"] = t["close_eligible_own"] and not kids_open
    t["close_eligible_covered"] = bool(not closed and t["status"] not in ("PLANNING", "TODO", "BLOCKED") and crit and left == 0
                                       and t.get("ac_covered") and not t["needs"] and reviewish and not waiting and not kids_open)
    unchecked = next((f for f in t["flags"] if f["code"] == "closure-unchecked"), None)
    tail = []
    if kids_open:
        open_kids = [by_key[c] for c in t["children"] if c in by_key and by_key[c]["lane"] != "closed"]
        names = ", ".join(f"{k['key']} ({k['ac_done']}/{k['ac_total']})" if k["criteria_state"] == "ok" else k["key"] for k in open_kids[:3])
        tail.append(f"waiting on {names}{f' +{len(open_kids) - 3}' if len(open_kids) > 3 else ''}")
    if unchecked:
        tail.append(f"closure proposed, but {left} unchecked")
    if t.get("ac_covered"):
        tail.append(f"{t['ac_covered']} covered by {', '.join(t['covered_by'])}")
    if kids_open:
        ac = "Own " + ac

    def mk(key, why, **kw):
        return {"key": key, "label": STATE_LABEL[key], "why": why, **kw}

    dopen = [] if closed else t["decisions_open"]
    dnow = [x for x in dopen if decision_lane(all_decisions.get(x)) == "now"]
    daside = [x for x in dopen if x not in dnow]
    if closed:
        base = mk("done", f"Closed {t['completed'] or t['updated']}".strip())
    elif t["status"] == "PLANNING":
        why = (f"Waiting on {owners_of(dnow, all_decisions)}: {id_ranges(dnow)}" + (f" · {id_ranges(daside)} set aside" if daside else "")) if dnow \
            else f"Parked until {id_ranges(daside)} {'is' if len(daside) == 1 else 'are'} picked up" if daside else "Scoped · not started"
        base = mk("planning", why, waiting_on=dopen)
    elif t["status"] == "BLOCKED" and not waiting and dnow:
        # Blocked on a decision (the block policy: nothing is built until it's answered).
        built = "nothing built" if not any(a.get("built_key") for a in t["asks"] if a["state"] == "open") else ac
        base = mk("blocked", f"Waiting on {owners_of(dnow, all_decisions)}: {id_ranges(dnow)} · {built}", waiting_on=dnow, on_decision=True)
    elif t["status"] == "BLOCKED" or waiting:
        why = f"Waiting on {', '.join(waiting)}" if waiting else "Blocked"
        if not waiting:
            hit = next((l["text"] for l in reversed(t["log"]) if re.search(r"block|wait", l["text"], re.I)), "")
            if hit:
                why += ": " + re.sub(r"^\d{4}-\d{2}-\d{2}:?\s*", "", hit)[:90]
        base = mk("blocked", f"{why} · {ac}", waiting_on=waiting)
    elif t["close_eligible"]:
        base = mk("ready", f"{ac} · " + ("closure proposed" if t["review"]["state"] == "closure-proposed" or closure_ask else "in review, nothing open"))
    elif t["close_eligible_covered"]:
        base = mk("covered", f"{ac} · closure proposed; {plural(t['ac_covered'], 'criterion', 'criteria')} unmet here, covered by {', '.join(t['covered_by'])}")
    elif t["status"] == "IN_PROGRESS" and (t.get("agent") or {}).get("active"):
        # In progress only when an agent is actually on it (a worktree, or an agent branch commit in the last 24h).
        base = mk("progress", " · ".join([ac, *([f"an agent is on it ({t['agent']['why']})"] if not tail else []), *tail]))
    elif t["status"] == "TODO":
        base = mk("notstarted", " · ".join([ac, *(["queued in TODO.md"] if t.get("todo_rank") else []), *tail]))
    else:
        base = mk("work", " · ".join([ac, *([f"{left} left"] if crit and left and not unchecked else []), *(["criteria unavailable"] if not crit else []), *tail]))
    t["state_base"] = base
    # Open decisions naming this ticket hold it. Only decisions in the decision board's "now" lane make it Blocked;
    # decisions set aside (Later, Deferred) never do: an otherwise ready ticket is Parked.
    if now and not closed and t["status"] != "PLANNING":
        t["state"] = mk("needs", f"{plural(len(now), 'ask')} to answer · {ac}")
    elif dnow and base["key"] not in ("blocked", "planning"):
        t["state"] = mk("blocked", f"Waiting on {owners_of(dnow, all_decisions)}: {id_ranges(dnow)} on the decision board · {ac}", waiting_on=dnow, on_decision=True)
    elif daside and base["key"] == "ready":
        t["state"] = mk("parked", f"Parked until {id_ranges(daside)} {'is' if len(daside) == 1 else 'are'} picked up · {ac}", waiting_on=daside)
    else:
        t["state"] = base
    # What holds the ticket, named: open decisions (with their lane and owner) and open tickets it depends on.
    t["blockers"] = [{"kind": "decision", "id": x, "title": (all_decisions.get(x) or {}).get("title") or "",
                      "lane": decision_lane(all_decisions.get(x)), "owner": (all_decisions.get(x) or {}).get("owner") or ""} for x in t["decisions_open"]] + \
                    [{"kind": "ticket", "id": x, "title": by_key[x]["title"], "status": by_key[x]["status"]} for x in waiting]
    t["asks_now"] = len(now)


def read_table(path, d, stop_at=None):
    """[(line_no, section, cells, header)] for markdown table rows."""
    rows, section, header = [], "", None
    for i, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if stop_at and raw.startswith(stop_at):
            break
        if raw.startswith("#"):
            section, header = raw.lstrip("#").strip(), None
            continue
        s = raw.strip()
        if not s.startswith("|"):
            header = None if not s else header
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue
        if header is None:
            header = cells
            continue
        if len(cells) != len(header):
            d.add("warn", "board-row", f"{path.name} row has {len(cells)} cells under a {len(header)}-column header ({section})", path, i)
        rows.append((i, section, cells, header))
    return rows


def agent_activity(ws, orch, repos, wt_override=None):
    """Tickets an agent is actually on: the directory <worktree_root>/<name>/ exists and is not empty, or a branch
    <branch_prefix><name> (local or origin) in any component repo has a commit from the last 24h. <name> is the
    ticket id lowercased ("app-045c"), or its key lowercased ("web.app-045c") when ids repeat across projects.
    Returns {name: why}. Status IN_PROGRESS in the file alone never counts."""
    out = {}
    wt = Path(wt_override).expanduser() if wt_override else Path(os.path.normpath(str(ws / orch["worktree_root"])))
    if wt.is_dir():
        for p in sorted(wt.iterdir()):
            try:
                if p.is_dir() and any(p.iterdir()):
                    out[p.name.lower()] = f"worktree {p}"
            except OSError:
                pass
    prefix = orch["branch_prefix"]
    cutoff = dt.datetime.now().timestamp() - 24 * 3600
    for repo in repos:
        try:
            refs = subprocess.run(["git", "-C", str(repo), "for-each-ref", "--format=%(refname:short) %(committerdate:unix)",
                                   f"refs/heads/{prefix}", f"refs/remotes/origin/{prefix}"], capture_output=True, text=True).stdout
        except Exception:
            continue
        for line in refs.splitlines():
            ref, _, ts = line.rpartition(" ")
            name = ref.split(prefix, 1)[1] if prefix in ref else ""
            if name and "/" not in name and ts.isdigit() and int(ts) >= cutoff:
                out.setdefault(name.lower(), f"{ref} in {repo.name or '.'} has a commit from {dt.datetime.fromtimestamp(int(ts)).strftime('%b %d %H:%M')}")
    return out, wt


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--workspace", default=".", help="the workspace root (holds .dotcortex/); default: the current directory")
    ap.add_argument("--tasks", action="append", help="a task root (repeatable); default: the team's projects, else .dotcortex/tasks")
    ap.add_argument("--decisions", action="append", help="an extra decision log (repeatable)")
    ap.add_argument("--closed-days", type=int, default=14)
    ap.add_argument("--board-url", help="this board's URL (default: boards.json ticket_board)")
    ap.add_argument("--decision-board-url", help="the decision board's URL (default: boards.json decision_board)")
    ap.add_argument("--worktrees", help="agent worktrees (default: orchestration.json worktree_root)")
    ap.add_argument("--repo", action="append", help="a component repo to check for agent branches (default: config component_repos)")
    a = ap.parse_args()
    ws = Path(os.path.abspath(a.workspace))
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    d = Diag(ws)
    cfg = workspace_config(ws)
    urls = board_urls(ws, a.board_url, a.decision_board_url)
    roots = task_roots(ws, a.tasks)
    for _, r in roots:
        if not r.is_dir():
            raise SystemExit(f"task root not found: {r}")
    index = TicketIndex(roots)
    prefix = str(cfg.get("prefix") or "")
    if prefix:
        others = sorted({it["id"].rsplit("-", 1)[0] for it in index.items} - {prefix})
        if others:
            d.add("info", "other-prefix", f"Ticket ids with a prefix other than {prefix}: {', '.join(others)}")
    orch = orchestration(ws)
    repos = [Path(os.path.abspath(r)) for r in a.repo] if a.repo else component_repos(ws, cfg)
    active_agents, wt_root = agent_activity(ws, orch, repos, a.worktrees)

    # Decision logs (shared rules with the decision board: discovery, D-id uniqueness, ticket resolution).
    logs, entries, next_free = read_decision_logs(decision_log_paths(ws, a.decisions), d)
    logs_by = {l["log"]: l for l in logs}
    all_decisions = {}
    for e in entries:
        if e.get("duplicate_of"):
            continue
        hint = log_project_hint(logs_by.get(e["log"]), index)
        e["ticket_keys"] = []
        for ref, key, _, problem in decision_tickets(e, hint, index):
            if key:
                e["ticket_keys"].append(key)
            elif problem == "ambiguous":
                d.add("warn", "ticket-ambiguous", f"{e['id']} names {ref}, which is in several projects: write it as <project>.{ref}", decision=e["id"])
        all_decisions[e["id"]] = e

    parsed = [t for it in index.items if (t := parse(it, d))]
    active = [t for t in parsed if not t["archived"]]
    archived_all = [t for t in parsed if t["archived"]]
    cutoff = (dt.date.today() - dt.timedelta(days=a.closed_days)).isoformat()
    closed = [t for t in archived_all if (t["completed"] or t["updated"]) >= cutoff]
    shown = {t["key"] for t in active + closed}
    d.items = [x for x in d.items if not x["ticket"] or x["ticket"] in shown or x["code"] == "no-title"]
    everything = active + closed
    by_key = {t["key"]: t for t in everything}
    all_keys = set(index.by_key)

    def res(ref, t, what):
        key, problem = index.resolve(ref, t["project"])
        if not key:
            d.add("warn", "missing-ref" if problem == "missing" else "ambiguous-ref",
                  f"{what} {ref} " + ("doesn't exist" if problem == "missing" else "is in several projects: write it as <project>." + ref),
                  t["file"], t["line"], t["key"])
        return key

    # Relationships: Parent fields are authoritative; the letter-suffix fallback is flagged. References resolve in
    # the same project first.
    for t in everything:
        t["parent"] = res(t["parent_refs"][0], t, "Parent") if t["parent_refs"] else None
        t["follow_up_for"] = res(t["follow_refs"][0], t, "Follow-up for") if t["follow_refs"] else None
        t["depends_on"] = [k for r in t["depends_refs"] if (k := res(r, t, "Depends on"))]
        for c in t["criteria"]:
            c["covered_by"] = [k for r in c.pop("covered_refs") if (k := res(r, t, "Covered by"))]
        if not t["parent"]:
            m = re.match(r"^([A-Z][A-Z0-9]{1,9}-\d+)[a-z]$", t["id"])
            if m and t["type"] != "FOLLOW-UP" and not t["follow_up_for"]:
                pk, _ = index.resolve(m.group(1), t["project"])
                if pk and index.by_key[pk]["project"] == t["project"]:
                    t["parent"] = pk
                    d.add("info", "parent-inferred", f"No Parent field; {pk} inferred from the letter suffix", t["file"], t["line"], t["key"])
        t["children"] = []
    for t in everything:
        if t["parent"]:
            if t["parent"] in by_key:
                by_key[t["parent"]]["children"].append(t["key"])
            elif t["parent"] not in all_keys:
                d.add("error", "missing-parent", f"Parent {t['parent']} not found", t["file"], t["line"], t["key"])
    for t in everything:  # cycles
        seen, cur = set(), t
        while cur and cur.get("parent"):
            if cur["key"] in seen:
                d.add("error", "cycle", f"Parent chain loops back through {cur['key']}", t["file"], t["line"], t["key"])
                break
            seen.add(cur["key"])
            cur = by_key.get(cur["parent"])
    for t in everything:
        t["children"].sort()
        listed = set()
        for s in t["subtask_list"]:
            k, _ = index.resolve(s["ref"], t["project"])
            listed.add(k)
            if not k:
                d.add("warn", "subtask-missing", f"Subtasks lists {s['ref']}, which doesn't exist", t["file"], s["line"], t["key"])
            elif k not in t["children"] and k in by_key:
                d.add("warn", "subtask-parent", f"Subtasks lists {k}, but its Parent field says {by_key[k]['parent'] or 'nothing'}", t["file"], s["line"], t["key"])
        for c in t["children"]:
            if c not in listed and t["subtask_list"]:
                d.add("warn", "subtask-unlisted", f"{c} names this ticket as Parent but isn't in its Subtasks list", t["file"], t["line"], t["key"])
        if t["children"] and t["type"] and t["type"] != "PARENT":
            d.add("warn", "type-mismatch", f"Has children but Type is {t['type']}", t["file"], t["line"], t["key"])
        kids = [by_key[c] for c in t["children"]]
        if kids:  # family rollup: children counted once, kept separate from the parent's own criteria
            st = {}
            for k in kids:
                st[k["status"]] = st.get(k["status"], 0) + 1
            t["family"] = {
                "children": len(kids), "done": sum(1 for k in kids if k["status"] == "DONE" or k["archived"]), "by_status": st,
                "criteria_done": sum(k["ac_done"] for k in kids), "criteria_total": sum(k["ac_total"] for k in kids),
                "criteria_unavailable": [k["key"] for k in kids if k["criteria_state"] == "unavailable"],
            }

    # BACKLOG and TODO per task root: reconciliation signals only (never ticket truth)
    backlog_notes, todo_order, todo_rank = {}, [], {}
    for project, root in roots:
        bl = root / "BACKLOG.md"
        if bl.exists():
            seen_rows = {}
            for ln, section, cells, header in read_table(bl, d):
                refs = ref_strings(cells[0]) if cells else []
                if not refs or not TID_RE.fullmatch(cells[0].split(".")[-1].strip()):
                    continue
                k, _ = index.resolve(refs[0], project)
                if not k:
                    d.add("warn", "board-missing", f"BACKLOG lists {refs[0]}, which has no ticket file", bl, ln)
                    continue
                if k in seen_rows:
                    same = seen_rows[k][1] == section
                    d.add("warn" if same else "info", "board-duplicate",
                          f"BACKLOG lists {k} twice {'in' if same else 'across sections; also'} {section if same else seen_rows[k][1]} (line {seen_rows[k][0]})", bl, ln)
                seen_rows.setdefault(k, (ln, section))
                t = by_key.get(k)
                if not t:
                    continue
                stv = next((c.upper() for c in cells if c.upper() in STATUSES + ["BACKLOG"]), None)
                if stv and normalize_status(stv)[0] != t["status"] and not t["archived"]:
                    d.add("warn", "board-status", f"BACKLOG says {stv} for {k}, the ticket says {t['status']}", bl, ln)
                if re.search(r"closure proposed", " | ".join(cells), re.I):
                    backlog_notes[k] = {"line": ln, "text": cells[-1]}
        td = root / "TODO.md"
        if td.exists():
            rank = 0
            for ln, section, cells, header in read_table(td, d, stop_at="## Log"):
                ref = next((c for c in cells if REF_RE.fullmatch(c)), None)
                if not ref:
                    continue
                k, _ = index.resolve(ref, project)
                if not k or k not in by_key:
                    d.add("warn", "todo-missing", f"TODO lists {ref}, which isn't an open ticket", td, ln)
                    continue
                rank += 1
                todo_order.append(k)
                todo_rank.setdefault(k, rank)
                if by_key[k]["archived"] or by_key[k]["status"] == "DONE":
                    d.add("warn", "todo-closed", f"TODO still lists {k}, which is closed", td, ln)

    # Review state: explicit field > status suffix > BACKLOG > recent log. Inferred states say where from.
    used_decisions = {}
    lane_of = {s: k for k, _, ss in LANES for s in ss}
    for t in everything:
        t["lane"] = "closed" if t["archived"] or t["status"] == "DONE" else lane_of.get(t["status"], "todo")
    for t in everything:
        rv = {"state": "none", "inferred": False, "source": None, "detail": ""}
        if t["review_field"]:
            rv = {"state": t["review_field"], "inferred": False, "source": "Review field", "detail": ""}
        elif re.search(r"closure proposed", t["status_note"], re.I):
            rv = {"state": "closure-proposed", "inferred": True, "source": "Status line", "detail": t["status_raw"]}
        elif t["key"] in backlog_notes:
            rv = {"state": "closure-proposed", "inferred": True, "source": "BACKLOG.md", "detail": backlog_notes[t["key"]]["text"]}
        else:
            hit = next((l for l in reversed(t["log"][-3:]) if re.search(r"closure proposed", l["text"], re.I)), None)
            if hit:
                rv = {"state": "closure-proposed", "inferred": True, "source": f"log, line {hit['line']}", "detail": ""}
        if t["archived"]:
            rv = {"state": "none", "inferred": False, "source": None, "detail": ""}
        t["review"] = rv
        for ask in t["asks"]:
            dec = all_decisions.get(ask["decision"]) if ask["decision"] else None
            ask["state"] = "answered" if ask["answered"] else "open"
            if ask["decision"] and not dec:
                d.add("warn", "needs-decision-missing", f"Ask {ask['n']} cites {ask['decision']}, which isn't in any decision log", t["file"], ask["line"], t["key"])
            elif dec and dec.get("status") in ("answered", "superseded") and ask["state"] == "open":
                ask["state"] = "answered"
                ask["answered"] = f"{ask['decision']} {dec.get('status')} {dec.get('answered_at') or ''} in {dec['log']}".replace("  ", " ")
                if not t["archived"]:
                    d.add("warn", "needs-decision-answered", f"Ask {ask['n']} cites {ask['decision']}, already {dec.get('status')} in {dec['log']}: "
                          "mark the ask answered or remove it", t["file"], ask["line"], t["key"])
            if dec:
                used_decisions[ask["decision"]] = dec
        t["asks_open"] = sum(1 for x in t["asks"] if x["state"] == "open")
        # Tiers: asks on built or in-progress work are answered here ("now"); a PLANNING ticket's asks are scoping
        # questions that belong on the decision board ("planning"); Confirm closure feeds closure.
        for ask in t["asks"]:
            dec = all_decisions.get(ask["decision"]) if ask["decision"] else None
            ask["tier"] = ("decision" if ask["decision"] else "planning" if t["status"] == "PLANNING"
                           else "closure" if ask["kind"] == "Confirm closure" else "now")
            ask["decision_title"] = (dec or {}).get("title") or ""
            ask["on_decision_board"] = bool(dec and dec.get("status") == "open")
            ask["built_key"] = built_key(ask, dec)
            ask["nothing_built"] = not ask["built_key"] and ask["kind"] in ("Question", "Approve", "Review")
            if ask["state"] == "open" and not t["archived"] and t["lane"] != "closed" and ask["tier"] == "planning":
                d.add("warn", "needs-not-decision", f"Ask {ask['n']} is a scoping question with no D-number, so no board shows it: "
                      f"move it to a decision log and cite it (“{ask['question']}”)", t["file"], ask["line"], t["key"])
        if not t["archived"] and t["lane"] != "closed":
            if t["review_field"] == "decision-needed" and t["needs_state"] in ("none", "explicit") and not t["asks_open"]:
                d.add("warn", "review-needs-mismatch", "Review is decision-needed but the Needs section has no open ask", t["file"], t["line"], t["key"])
            if t["asks_open"] and t["review_field"] in (None, "none") and any(x["state"] == "open" and x["kind"] != "Confirm closure" for x in t["asks"]):
                d.add("info", "review-needs-mismatch", f"{plural(t['asks_open'], 'open ask')} but Review is {t['review_field'] or 'missing'} (expected decision-needed)", t["file"], t["line"], t["key"])
        if rv["state"] == "none" and (t["needs"] or t["asks_open"]) and not t["archived"] and t["status"] in ("REVIEW", "PLANNING"):
            t["review"] = {"state": "decision-needed", "inferred": True, "source": "open asks", "detail": ""}
        open_c = [c for c in t["criteria"] if not c["checked"]]
        own_c = [c for c in open_c if not c["covered_by"]]
        cov_c = [c for c in open_c if c["covered_by"]]
        t["ac_covered"] = len(cov_c)
        t["covered_by"] = sorted({x for c in cov_c for x in c["covered_by"]})
        t["flags"] = []
        if t["review"]["state"] == "closure-proposed" and own_c:
            t["flags"].append({"code": "closure-unchecked", "text": f"Closure proposed with {len(own_c)} unchecked criteri{'on' if len(own_c) == 1 else 'a'}"})
            d.add("warn", "closure-unchecked", f"Closure proposed but {len(own_c)} of {len(t['criteria'])} criteria are unchecked", t["file"], t["line"], t["key"])
        if t["review"]["state"] == "closure-proposed" and t["criteria_state"] == "unavailable":
            t["flags"].append({"code": "closure-no-criteria", "text": "Closure proposed with no criteria to check against"})
        if t["review"]["state"] == "closure-proposed" and t.get("family") and t["family"]["done"] < t["family"]["children"]:
            t["flags"].append({"code": "closure-open-children", "text": f"{plural(t['family']['children'] - t['family']['done'], 'child', 'children')} still open"})
        if t["legacy"] and not t["archived"]:
            t["flags"].append({"code": "core-missing", "text": f"Older format: no {', '.join(t['core_missing'])}"})
        t["reconcile"] = t["review"]["inferred"] and t["review"]["state"] == "closure-proposed"

    # Open decisions per ticket, counted exactly as the decision board counts them for #ticket-<key>: status open
    # and the ticket in its `tickets` list (a decision naming two tickets counts under both).
    open_by_ticket = {}
    for x in all_decisions.values():
        if x.get("status") == "open":
            for k in x.get("ticket_keys") or []:
                open_by_ticket.setdefault(k, []).append(x["id"])
    num = lambda i: int(re.sub(r"\D", "", i) or 0)
    for t in everything:
        t["decisions_open"] = sorted(set(open_by_ticket.get(t["key"], [])), key=num) if t["lane"] != "closed" else []
    for t in everything:
        t["todo_rank"] = todo_rank.get(t["key"])
        # an agent's worktree or branch is named by the id; by the key when the id repeats across projects
        names = [t["key"].lower()] + ([t["id"].lower()] if len(index.by_id.get(t["id"], [])) == 1 else [])
        hit = next((n for n in names if n in active_agents), None)
        t["agent"] = {"active": bool(hit) and t["lane"] != "closed", "why": active_agents.get(hit, "") if hit else ""}
        derive_state(t, by_key, all_decisions)
        t["issues"] = [x for x in d.items if x["ticket"] == t["key"] and x["file"] == t["file"] and x["level"] in ("warn", "error")
                       and x["code"] != "closure-unchecked"]
        t["snapshot"] = {
            "fp": t["fingerprint"], "status": t["status"], "review": t["review"]["state"],
            # keyed by criterion text (ids stripped), so adding AC ids never reads as "checked/unchecked"
            "checked": ["t:" + fp(c["text"])[:8] for c in t["criteria"] if c["checked"]],
            "criteria": len(t["criteria"]),
            "shipped": len(t["shipped"]), "evidence": len(t["evidence"]), "log": t["log_count"],
            "asks": sorted(x["fingerprint"][:8] for x in t["asks"] if x["state"] == "open"),
            "children_done": t.get("family", {}).get("done"),
            "covered": t.get("ac_covered", 0),
        }
        for k in ("review_field", "subtask_list", "status_note", "parent_refs", "follow_refs", "depends_refs"):
            t.pop(k, None)

    legacy = [t["key"] for t in everything if t["legacy"] and not t["archived"]]
    if legacy:
        d.add("info", "legacy-format", f"{len(legacy)} of {len(everything)} tickets lack part of the ticket core; they are read with the "
              "compatibility reader. Run migrate_tickets.py to add Review, criterion ids and the Needs section.")

    people = people_list([t["assignee"] for t in everything if t["lane"] != "closed"]
                         + [a["for"] for t in everything if t["lane"] != "closed" for a in t["asks"] if a["state"] == "open"])
    prio = {p: i for i, p in enumerate(PRIORITIES)}
    proj_rank = {p: i for i, (p, _) in enumerate(roots)}
    everything.sort(key=lambda t: (t["todo_rank"] or 999, prio.get(t["priority"], 9), proj_rank.get(t["project"], 9), t["id"]))
    dec_out = {**used_decisions, **{x: all_decisions[x] for t in everything for x in t["decisions_open"] if x in all_decisions}}
    data = {
        "board_version": 3, "schema_version": SCHEMA_VERSION,
        "generated_at": dt.datetime.now().astimezone().isoformat(timespec="minutes"),
        "title": str(cfg.get("project_name") or ws.name),
        "source": {"tasks": ", ".join(d.rel(r) for _, r in roots), **git_rev(roots[0][1])},
        "sources": [{"project": p, "path": d.rel(r), **git_rev(r)} for p, r in roots],
        "multi_project": index.multi, "projects": [p for p, _ in roots],
        "closed_days": a.closed_days,
        "lanes": [{"key": k, "title": title} for k, title, _ in LANES] + [{"key": "closed", "title": f"Closed in the last {a.closed_days} days"}],
        "todo_order": todo_order,
        "states": [{"key": k, "label": v} for k, v in STATES],
        "board_url": urls["ticket_board"], "decision_board": urls["decision_board"],
        "people": people,
        "decision_logs": [{k: l[k] for k in ("log", "title", "scope", "feature", "owner", "file")} for l in logs],
        "next_decision_id": next_free,
        # Only what this board needs to read saved answers on asks that cite a D-number (never rendered as questions),
        # plus every open decision naming a ticket, with its lane and owner, so each card can name it.
        "decisions": {k: {**{f: v.get(f) for f in ("id", "title", "status", "options", "blocks", "deferred_at", "default_built", "owner", "log")},
                          "lane": decision_lane(v)} for k, v in dec_out.items()},
        "decisions_open_total": sum(1 for x in all_decisions.values() if x.get("status") == "open"),
        "agents_active": active_agents,
        "diagnostics": d.items,
        "tickets": everything,
    }
    (out / "board-data.json").write_text(json.dumps(data, indent=1, ensure_ascii=False, default=str), encoding="utf-8")
    shutil.copy2(HERE / "board.html", out / "index.html")

    counts, lv, by_state, by_primary = {}, {}, {}, {}
    for t in everything:
        counts[t["lane"]] = counts.get(t["lane"], 0) + 1
        by_primary[t["state"]["key"]] = by_primary.get(t["state"]["key"], 0) + 1
        if t["lane"] != "closed":
            by_state[t["needs_state"]] = by_state.get(t["needs_state"], 0) + 1
    for x in d.items:
        lv[x["level"]] = lv.get(x["level"], 0) + 1
    asks_open = sum(t["asks_open"] for t in everything if t["lane"] != "closed")
    print(f"task roots: {', '.join(f'{p} ({d.rel(r)})' for p, r in roots)}" + ("; keys are <project>.<ID>" if index.multi else ""))
    print("states (before saved answers): " + ", ".join(f"{STATE_LABEL[k]} {by_primary.get(k, 0)}" for k, _ in STATES))
    print(f"agents on a ticket (worktrees under {wt_root}, or a {orch['branch_prefix']}<id> commit in 24h): "
          + (", ".join(f"{k} ({v})" for k, v in active_agents.items()) or "none"))
    dec_open = sum(len(t["decisions_open"]) for t in everything)
    print(f"decision logs: {', '.join(l['log'] for l in logs) or 'none'}; decisions open on tickets: {dec_open} across "
          f"{sum(1 for t in everything if t['decisions_open'])} tickets ({data['decisions_open_total']} open in all logs); next free decision id: {next_free}")
    print(f"people: {', '.join(people) or 'none'}")
    print(f"{len(everything)} tickets -> {out}  {counts}  open asks: {asks_open}  needs sections: {by_state}  diagnostics: {lv}  "
          f"source: {data['source']['rev']}{' (dirty)' if data['source']['dirty'] else ''}")
    for x in d.items:
        if x["level"] in ("warn", "error"):
            print(f"  {x['level']}: {x['message']}" + (f" ({x['file']}{':' + str(x['line']) if x['line'] else ''})" if x["file"] else ""))


if __name__ == "__main__":
    main()
