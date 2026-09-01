#!/usr/bin/env bash
# Forbidden-token scan for shipped/source assets.
# Usage: scripts/check-debrand.sh <dir> [<dir>...]
# Scans only the given directories (never the whole repo — fixtures and
# gitignored user config may legitimately contain these tokens).
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "usage: $0 <dir> [<dir>...]" >&2
  exit 2
fi

FORBIDDEN=(
  'TCGTrack' 'tcgtrack'
  'card-tracker'
  'TheCardGuild'
  'TCG-[0-9]'
  'Brenden' 'brenden'
  'Opus 4\.8' 'model: opus' 'claude-fable' 'gpt-5'
  'rndev\b' 'rnprod\b' 'rnapi\b' 'tcgrails' 'dotcgrails'
  '/Users/[a-z]'
  'marketing-site'
  'Gluestack' 'TCGPlayer' 'tcgplayer'
)

fail=0
for pattern in "${FORBIDDEN[@]}"; do
  if hits=$(grep -rniE "$pattern" "$@" --include='*.md' --include='*.yaml' --include='*.yml' --include='*.json' 2>/dev/null); then
    echo "FORBIDDEN TOKEN: $pattern"
    echo "$hits" | head -10
    fail=1
  fi
done

if [ $fail -eq 0 ]; then
  echo "de-brand check passed: $*"
fi
exit $fail
