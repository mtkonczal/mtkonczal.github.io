#!/usr/bin/env bash
# Pulls the Draftwatch README into _includes/draftwatch-readme.md so
# draftwatch.qmd has exactly one copy of the project text to maintain.
# Wired up as a `project: pre-render` hook in _quarto.yml, so it runs
# automatically before every `quarto render`. The output is also committed,
# so a stale-but-present copy always exists: if the fetch fails (offline,
# GitHub down, rate-limited) this warns and leaves that copy in place rather
# than failing the whole site build.
set -uo pipefail

REPO="mtkonczal/Draftwatch"
BRANCH="main"
OUT="_includes/draftwatch-readme.md"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LOCAL_README="$HOME/Documents/GitHub/Draftwatch/README.md"

source="https://github.com/${REPO}/blob/${BRANCH}/README.md"
raw=$(curl -fsSL --max-time 10 "https://raw.githubusercontent.com/${REPO}/${BRANCH}/README.md")
if [ $? -ne 0 ] || [ -z "$raw" ]; then
  # Offline / rate-limited: fall back to the local Draftwatch checkout,
  # which is fresher than whatever was last synced. Failing that, keep
  # the committed copy rather than breaking the whole site build.
  if [ -r "$LOCAL_README" ]; then
    echo "warning: could not reach GitHub — using local checkout instead" >&2
    raw=$(cat "$LOCAL_README")
    source="$LOCAL_README"
  else
    echo "warning: could not fetch README from github.com/${REPO} — keeping existing ${OUT}" >&2
    exit 0
  fi
fi

# Drop the README's own "# Draftwatch" H1 (the page already has a title)
# and any blank lines left at the top.
printf '%s\n' "$raw" | tail -n +2 | sed '/./,$!d' > "$OUT"

echo "Synced ${OUT} from ${source}"
