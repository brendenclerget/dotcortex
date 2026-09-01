#!/usr/bin/env bash
# Deterministic asset renderer.
#
# Renders every file under --source into --dest, substituting {{TOKEN}} values
# from the project config, and replaces the config's managed_files map with an
# exact manifest of this render: per file, the SHA-256 of the rendered bytes,
# the base version, and a repository-relative source path (so an updater can
# `git checkout <base_version> -- <source>` to reconstruct the merge base).
#
# Guarantees:
# - Atomic-by-validation: all rendering happens in memory first; with --strict,
#   nothing on disk (dest OR config) is touched if any token is unresolved.
# - Convergent: files recorded in the previous manifest that no longer exist in
#   the source are deleted from dest; managed_files is replaced, not merged.
# - Deterministic: sorted traversal, sorted manifest keys — same inputs produce
#   byte-identical dest trees and config files.
# - Byte-preserving: substitution never adds/strips trailing newlines; files
#   that are not valid UTF-8 are copied verbatim with no substitution.
#
# Usage:
#   bin/render.sh --source <asset-dir> --dest <layer-dir> --config <config.json>
#                 [--base-version <tag>] [--strict]
set -euo pipefail

SOURCE="" DEST="" CONFIG="" BASE_VERSION="" STRICT=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)       SOURCE="${2:?}"; shift ;;
    --dest)         DEST="${2:?}"; shift ;;
    --config)       CONFIG="${2:?}"; shift ;;
    --base-version) BASE_VERSION="${2:?}"; shift ;;
    --strict)       STRICT=1 ;;
    *) echo "render.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -d "$SOURCE" ] || { echo "render.sh: source not found: $SOURCE" >&2; exit 2; }
[ -f "$CONFIG" ] || { echo "render.sh: config not found: $CONFIG" >&2; exit 2; }
[ -n "$DEST" ]   || { echo "render.sh: --dest is required" >&2; exit 2; }

if [ -z "$BASE_VERSION" ]; then
  if BASE_VERSION="$(git -C "$SOURCE" describe --tags --exact-match 2>/dev/null)"; then
    :
  elif sha="$(git -C "$SOURCE" rev-parse --short HEAD 2>/dev/null)"; then
    BASE_VERSION="untagged-$sha"
  else
    BASE_VERSION="unversioned"
  fi
fi

# Repository-relative prefix for source identity (empty if not in a git repo).
SOURCE_ABS="$(cd "$SOURCE" && pwd -P)"
if repo_root="$(git -C "$SOURCE" rev-parse --show-toplevel 2>/dev/null)"; then
  SOURCE_PREFIX="${SOURCE_ABS#"$repo_root"}"
  SOURCE_PREFIX="${SOURCE_PREFIX#/}"
else
  SOURCE_PREFIX=""
fi

SOURCE="$SOURCE_ABS" DEST="$DEST" CONFIG="$CONFIG" BASE_VERSION="$BASE_VERSION" \
STRICT="$STRICT" SOURCE_PREFIX="$SOURCE_PREFIX" \
python3 - <<'PYEOF'
import hashlib, json, os, re, sys

source = os.environ["SOURCE"]
dest = os.environ["DEST"]
config_path = os.environ["CONFIG"]
base_version = os.environ["BASE_VERSION"]
strict = os.environ["STRICT"] == "1"
source_prefix = os.environ["SOURCE_PREFIX"]

with open(config_path) as f:
    config = json.load(f)
cfg = config.get("config", config)
review = cfg.get("review", {})

def join_list(v):
    return ", ".join(v) if isinstance(v, list) else v

TOKEN_VALUES = {
    "TICKET_PREFIX": cfg.get("prefix"),
    "TASKS_DIR": cfg.get("tasks_dir"),
    "PROJECT_NAME": cfg.get("project_name"),
    "COMPONENT_REPOS": join_list(cfg.get("component_repos")),
    "REVIEWER_CLI": review.get("reviewer_cli"),
    "REVIEWER_MODEL": review.get("reviewer_model"),
    "COORDINATOR_CLI": review.get("coordinator_cli"),
    "COORDINATOR_MODEL": review.get("coordinator_model"),
}
TOKEN_VALUES = {k: v for k, v in TOKEN_VALUES.items() if v is not None}
token_re = re.compile(r"\{\{([A-Z0-9_]+)\}\}")

# ---- Pass 1: render everything in memory; nothing on disk is touched yet ----
outputs = {}      # rel -> rendered bytes
unresolved = {}   # rel -> [tokens]
for root, dirs, files in os.walk(source):
    dirs[:] = sorted(d for d in dirs if d != ".git")
    for name in sorted(files):
        src_path = os.path.join(root, name)
        rel = os.path.relpath(src_path, source)
        with open(src_path, "rb") as f:
            raw = f.read()
        try:
            text = raw.decode("utf-8")
            missing = sorted({t for t in token_re.findall(text) if t not in TOKEN_VALUES})
            if missing:
                unresolved[rel] = missing
            out = token_re.sub(
                lambda m: TOKEN_VALUES.get(m.group(1), m.group(0)), text
            ).encode("utf-8")
        except UnicodeDecodeError:
            out = raw  # non-UTF8: copy verbatim
        outputs[rel] = out

if unresolved:
    for rel in sorted(unresolved):
        print(f"render.sh: UNRESOLVED tokens in {rel}: {', '.join(unresolved[rel])}",
              file=sys.stderr)
    if strict:
        print("render.sh: --strict: aborting before writing anything.", file=sys.stderr)
        sys.exit(1)

# ---- Pass 2: write dest, remove stale files, replace manifest ----
new_manifest = {}
for rel in sorted(outputs):
    out_path = os.path.join(dest, rel)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(outputs[rel])
    new_manifest[rel] = {
        "sha256": hashlib.sha256(outputs[rel]).hexdigest(),
        "base_version": base_version,
        "source": os.path.join(source_prefix, rel) if source_prefix else rel,
    }

# Stale cleanup. managed_files keys are data from a mutable config file —
# treat them as untrusted: never delete outside dest, and never delete a file
# the user has modified since we rendered it.
old_manifest = config.get("managed_files", {})
stale = sorted(set(old_manifest) - set(new_manifest))
dest_abs = os.path.abspath(dest)
removed = 0
dest_real = os.path.realpath(dest_abs)
for rel in stale:
    norm = os.path.normpath(rel)
    candidate = os.path.abspath(os.path.join(dest_abs, norm))
    # Lexical containment first…
    if os.path.isabs(rel) or not (candidate == dest_abs or
                                  candidate.startswith(dest_abs + os.sep)):
        print(f"render.sh: REFUSING stale manifest entry escaping dest: {rel}",
              file=sys.stderr)
        continue
    # …then physical: a symlinked directory beneath dest must not smuggle the
    # deletion outside. The candidate's PARENT must resolve inside dest.
    parent_real = os.path.realpath(os.path.dirname(candidate))
    if not (parent_real == dest_real or parent_real.startswith(dest_real + os.sep)):
        print(f"render.sh: REFUSING stale entry whose real path escapes dest: {rel}",
              file=sys.stderr)
        continue
    # An alias key (e.g. "sub/../a.md") must never delete a currently managed file.
    if norm in new_manifest:
        print(f"render.sh: REFUSING stale alias of a managed file: {rel} -> {norm}",
              file=sys.stderr)
        continue
    if os.path.isfile(candidate):
        with open(candidate, "rb") as f:
            current_hash = hashlib.sha256(f.read()).hexdigest()
        recorded = old_manifest.get(rel, {}).get("sha256")
        if current_hash != recorded:
            print(f"render.sh: CONFLICT — stale file was modified after rendering, "
                  f"left in place (now unmanaged): {norm}", file=sys.stderr)
            continue
        os.remove(candidate)
        removed += 1
        d = os.path.dirname(candidate)
        while d != dest_abs and os.path.isdir(d) and not os.listdir(d):
            os.rmdir(d)
            d = os.path.dirname(d)
        print(f"render.sh: removed stale rendered file: {norm}")

config["managed_files"] = new_manifest
with open(config_path, "w") as f:
    json.dump(config, f, indent=2, sort_keys=False)
    f.write("\n")

print(f"render.sh: rendered {len(new_manifest)} files -> {dest} "
      f"(base_version {base_version}, {removed} stale removed)")
PYEOF
