#!/usr/bin/env python3
"""Add the ticket core to older tickets without touching their prose or checkbox states.

Usage (from the workspace root):
  migrate_tickets.py [--tasks DIR ...] [--dry-run | --write] [--diff] [--include-archive] [--assignee WHO] [IDS...]

Dry run is the default. For each ticket it plans:
  - metadata: `**Review:**` (none, or closure-proposed when the Status line, BACKLOG.md or the last log lines say
    so; inferred values are listed for reconciliation), `**Assignee:** WHO` when --assignee is given and the ticket
    has neither Assignee nor Owner; normalise legacy status values (`BACKLOG` -> `TODO`,
    `REVIEW (Closure proposed)` -> `REVIEW` + Review: closure-proposed);
  - criteria: prefix top-level checklist items in the acceptance section with stable ids (`- [ ] AC3: ...`),
    continuing after any existing ACn; items that already carry an id (`AC2:` or a bold code like `**A28**`) are
    left alone; `[ ]`/`[x]` never change;
  - sections: add `## Needs from assignee` with `None.` (before the log) when the ticket has no Needs section.
Every run verifies that removing the added lines and id prefixes gives back the original file exactly (apart from
the normalised Status value), and refuses to write otherwise. Idempotent: a migrated ticket plans no changes.
IDS are ticket ids (APP-012) or keys (web.APP-012).

Commit a --write run with .dotcortex/bin/task-tx.sh (exact paths), never while other agents edit the same tickets.
"""
import argparse, difflib, os, re, sys
from pathlib import Path

sys.dont_write_bytecode = True  # never leave __pycache__ in the skill
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_board as bb  # noqa: E402  (shares the task roots, section aliases and regexes)

NEEDS_SECTION = ("Needs from assignee", "None.")


def plan(path, backlog_closure, key, assignee):
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    notes, inferred = [], []
    ti = next((i for i, l in enumerate(lines) if re.match(r"^# \S+?:", l)), None)
    if ti is None:
        return text, ["skipped: no '# <ID>: Title' line"], []
    tid = re.match(r"^# (\S+?):", lines[ti]).group(1)
    first_head = next((i for i in range(ti + 1, len(lines)) if bb.HEAD_RE.match(lines[i])), len(lines))
    fields = {}
    for i in range(ti + 1, first_head):
        m = bb.FIELD_RE.match(lines[i])
        if m:
            fields[m.group(1).strip().lower()] = (i, m.group(2))
    out = list(lines)
    replaced = {}  # line index -> original text (metadata normalisation only)
    inserts = {}   # insert-before index -> [lines]

    def add_field(after_keys, line):
        anchor = max((fields[k][0] for k in after_keys if k in fields), default=None)
        if anchor is None:
            anchor = max((i for i, _ in fields.values()), default=ti + 1)
        inserts.setdefault(anchor + 1, []).append(line)

    review = None
    if "status" in fields:
        i, v = fields["status"]
        m = re.match(r"^([A-Za-z_]+)\s*(?:\((.*)\))?\s*$", v)
        if m:
            st, note = m.group(1).upper(), (m.group(2) or "")
            new = "TODO" if st == "BACKLOG" else st
            if re.search(r"closure proposed", note, re.I):
                review = "closure-proposed"
            elif note:
                new = v  # unknown parenthetical: leave it for a person
                notes.append(f"status note '({note})' left as is")
            if new != v:
                replaced[i] = out[i]
                out[i] = out[i].replace(v, new)
                notes.append(f"Status '{v}' -> '{new}'")

    if assignee and "assignee" not in fields and "owner" not in fields:
        add_field(["priority", "status"], f"**Assignee:** {assignee}")
        notes.append(f"+Assignee: {assignee}")

    secs = bb.split_sections(lines)
    by_key = {}
    for s in secs:
        if s["key"]:
            by_key.setdefault(s["key"], []).append(s)

    # Criterion ids (acceptance section only; a plain "Findings" group keeps its own codes)
    for s in by_key.get("criteria", []):
        used = [int(m.group(1)) for _, r in s["body"] if (m := re.search(r"\]\s+AC(\d+)\s*[:.)-]", r))]
        n, added = max(used, default=0), 0
        for ln, raw in s["body"]:
            m = bb.CHECK_RE.match(raw)
            if not m or m.group(1):
                continue
            body = m.group(3)
            if bb.AC_ID_RE.match(body) or bb.CODE_ID_RE.match(body):
                continue
            n += 1
            added += 1
            out[ln - 1] = f"{raw[: len(raw) - len(body)]}AC{n}: {body}"
        if added:
            notes.append(f"{added} criterion ids")

    if "review" not in fields:
        if not review:
            if key in backlog_closure:
                review = "closure-proposed"
                inferred.append("Review: closure-proposed from BACKLOG.md")
            elif any(re.search(r"closure proposed", r, re.I) for s in by_key.get("log", []) for _, r in s["body"][-3:]):
                review = "closure-proposed"
                inferred.append("Review: closure-proposed from the log")
            else:
                review = "none"
        add_field(["assignee", "owner", "type", "priority", "status"], f"**Review:** {review}")
        notes.append(f"+Review: {review}")

    if "needs" not in by_key:
        log_sec = (by_key.get("log") or [None])[0]
        title, body = NEEDS_SECTION
        if log_sec:
            inserts.setdefault(log_sec["line"] - 1, []).extend([f"## {title}", body, ""])
        else:
            at = len(out) - 1 if out and out[-1] == "" else len(out)  # keep the trailing newline where it is
            inserts.setdefault(at, []).extend(([""] if at and out[at - 1].strip() else []) + [f"## {title}", body])
        notes.append(f"+{title}")

    final = []  # (text, original line index or None for inserted lines)
    for i, l in enumerate(out):
        final += [(x, None) for x in inserts.get(i, [])]
        final.append((l, i))
    final += [(x, None) for x in inserts.get(len(out), [])]
    new_text = "\n".join(l for l, _ in final)

    # Preservation check: drop inserted lines, strip added id prefixes, restore normalised fields
    strip = lambda l: re.sub(r"^(\s*[-*]\s+\[[ xX]\]\s+)AC\d+: ", r"\1", l) if bb.CHECK_RE.match(l) else l
    check = [strip(replaced.get(i, l)) for l, i in final if i is not None]
    if check != [strip(l) for l in lines]:
        return text, [f"REFUSED: preservation check failed for {tid}"], inferred
    boxes = lambda ls: [bb.CHECK_RE.match(l).group(2).lower() for l in ls if bb.CHECK_RE.match(l)]
    if boxes([l for l, _ in final]) != boxes(lines):
        return text, [f"REFUSED: checkbox states changed for {tid}"], inferred
    return new_text, notes, inferred


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workspace", default=".", help="the workspace root (holds .dotcortex/)")
    ap.add_argument("--tasks", action="append", help="a task root (repeatable); default: the team's projects, else .dotcortex/tasks")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", default=True)
    g.add_argument("--write", action="store_true")
    ap.add_argument("--diff", action="store_true", help="print a unified diff per file")
    ap.add_argument("--include-archive", action="store_true")
    ap.add_argument("--assignee", help="Assignee for tickets that have neither Assignee nor Owner (an email or name)")
    ap.add_argument("ids", nargs="*")
    a = ap.parse_args()
    ws = Path(os.path.abspath(a.workspace))
    roots = bb.task_roots(ws, a.tasks)
    index = bb.TicketIndex(roots)
    items = [it for it in index.items if a.include_archive or not it["archived"]]

    backlog_closure = set()
    for project, root in roots:
        bl = root / "BACKLOG.md"
        if bl.exists():
            for line in bl.read_text(encoding="utf-8").splitlines():
                m = re.match(r"^\|\s*(\S+?)\s*\|.*closure proposed", line, re.I)
                if m:
                    k, _ = index.resolve(m.group(1), project)
                    if k:
                        backlog_closure.add(k)

    totals = {"files": 0, "changed": 0, "unchanged": 0, "refused": 0, "ids": 0, "sections": 0, "status": 0, "inferred": 0}
    for it in items:
        if a.ids and not any(i in (it["id"], it["key"]) for i in a.ids):
            continue
        p = it["path"]
        totals["files"] += 1
        new, notes, inferred = plan(p, backlog_closure, it["key"], a.assignee)
        rel = os.path.relpath(p, ws)
        if any(n.startswith("REFUSED") for n in notes):
            totals["refused"] += 1
            print(f"  {rel}: {'; '.join(notes)}")
            continue
        if new == p.read_text(encoding="utf-8"):
            totals["unchanged"] += 1
            continue
        totals["changed"] += 1
        totals["ids"] += sum(int(n.split()[0]) for n in notes if n.endswith("criterion ids"))
        totals["sections"] += sum(1 for n in notes if n.startswith("+Needs"))
        totals["status"] += sum(1 for n in notes if n.startswith("Status"))
        totals["inferred"] += len(inferred)
        extra = f"  [inferred: {'; '.join(inferred)}]" if inferred else ""
        print(f"  {rel}: {'; '.join(notes)}{extra}")
        if a.diff:
            sys.stdout.writelines(difflib.unified_diff(p.read_text(encoding="utf-8").splitlines(True), new.splitlines(True), rel, rel + " (migrated)"))
        if a.write:
            p.write_text(new, encoding="utf-8")
    mode = "WROTE" if a.write else "DRY RUN (nothing written)"
    print(f"{mode}: {totals['files']} tickets scanned, {totals['changed']} to migrate, {totals['unchanged']} already have the core, "
          f"{totals['refused']} refused; {totals['ids']} criterion ids, {totals['sections']} Needs sections added, "
          f"{totals['status']} status values normalised, {totals['inferred']} inferred values to reconcile. "
          "Prose and checkbox states preserved (verified per file).")


if __name__ == "__main__":
    main()
