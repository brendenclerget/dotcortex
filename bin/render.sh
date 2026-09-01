#!/usr/bin/env bash
# Deterministic asset renderer.
#
# Copies every file under --source into --dest, substituting {{TOKEN}} values
# taken from the project config, and records a manifest entry per rendered file
# (SHA-256 of the rendered output, the base version it came from, and the
# source-relative path) into the config's managed_files map.
#
# Byte-preserving: substitution never adds or strips trailing newlines; files
# that are not valid UTF-8 are copied verbatim with no substitution.
#
# Usage:
#   bin/render.sh --source <asset-dir> --dest <layer-dir> --config <config.json>
#                 [--base-version <tag>] [--strict]
#
#   --base-version  defaults to `git describe --tags --exact-match` of the
#                   source checkout, else "untagged-<shortsha>".
#   --strict        fail (exit 1) if any {{TOKEN}} in a source file has no
#                   value in config; default is to leave it intact and warn.
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

SOURCE="$SOURCE" DEST="$DEST" CONFIG="$CONFIG" BASE_VERSION="$BASE_VERSION" STRICT="$STRICT" \
python3 - <<'PYEOF'
import hashlib, json, os, re, sys

source = os.environ["SOURCE"]
dest = os.environ["DEST"]
config_path = os.environ["CONFIG"]
base_version = os.environ["BASE_VERSION"]
strict = os.environ["STRICT"] == "1"

with open(config_path) as f:
    config = json.load(f)
cfg = config.get("config", config)

def join_list(v):
    return ", ".join(v) if isinstance(v, list) else v

TOKEN_VALUES = {
    "TICKET_PREFIX": cfg.get("prefix"),
    "TASKS_DIR": cfg.get("tasks_dir"),
    "PROJECT_NAME": cfg.get("project_name"),
    "COMPONENT_REPOS": join_list(cfg.get("component_repos")),
}
TOKEN_VALUES = {k: v for k, v in TOKEN_VALUES.items() if v is not None}

token_re = re.compile(r"\{\{([A-Z0-9_]+)\}\}")
manifest = config.setdefault("managed_files", {})
unresolved = {}
rendered = 0

for root, dirs, files in os.walk(source):
    dirs[:] = [d for d in dirs if d != ".git"]
    for name in sorted(files):
        src_path = os.path.join(root, name)
        rel = os.path.relpath(src_path, source)
        out_path = os.path.join(dest, rel)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)

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

        with open(out_path, "wb") as f:
            f.write(out)
        manifest[rel] = {
            "sha256": hashlib.sha256(out).hexdigest(),
            "base_version": base_version,
            "source": rel,
        }
        rendered += 1

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"render.sh: rendered {rendered} files -> {dest} (base_version {base_version})")
if unresolved:
    for rel, tokens in unresolved.items():
        print(f"render.sh: UNRESOLVED tokens in {rel}: {', '.join(tokens)}", file=sys.stderr)
    if strict:
        sys.exit(1)
PYEOF
