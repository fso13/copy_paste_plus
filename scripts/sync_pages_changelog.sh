#!/usr/bin/env bash
# Copy root CHANGELOG.md into docs/ so GitHub Pages always serves the latest notes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/CHANGELOG.md"
DST="$ROOT/docs/CHANGELOG.md"

if [[ ! -f "$SRC" ]]; then
  echo "error: $SRC not found" >&2
  exit 1
fi

mkdir -p "$ROOT/docs"
cp "$SRC" "$DST"
echo "Synced $SRC → $DST"
