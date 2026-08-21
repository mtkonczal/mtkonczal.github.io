#!/usr/bin/env bash
# Rebuilds typst/resume_brief.pdf from its .typ source and copies it into
# files/, so `quarto render` always ships the current version — no separate
# "remember to sync the PDF" step. Wired up as a `project: pre-render` hook
# in _quarto.yml, alongside sync-draftwatch-readme.sh.
# If typst isn't on PATH (or the compile fails), warn and leave the last
# synced copy in files/ in place rather than failing the whole site build.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SRC_DIR="typst"
PDF="resume_brief.pdf"
OUT="files/${PDF}"

if ! command -v typst >/dev/null 2>&1; then
  echo "warning: typst not found on PATH — keeping existing ${OUT}" >&2
  exit 0
fi

if ! (cd "$SRC_DIR" && typst compile --font-path fonts "resume_brief.typ"); then
  echo "warning: typst compile failed — keeping existing ${OUT}" >&2
  exit 0
fi

cp "${SRC_DIR}/${PDF}" "$OUT"
echo "Synced ${OUT} from ${SRC_DIR}/resume_brief.typ"
