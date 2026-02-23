#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASCOT_DIR="$ROOT_DIR/img/mascot"
OUT_FILE="$ROOT_DIR/js/mascot-files.js"

if [[ ! -d "$MASCOT_DIR" ]]; then
  echo "Mascot directory not found: $MASCOT_DIR" >&2
  exit 1
fi

mapfile -t files < <(find "$MASCOT_DIR" -maxdepth 1 -type f -name '*.png' -printf '%f\n' | sort -V)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No mascot PNG files found in $MASCOT_DIR" >&2
  exit 1
fi

{
  echo "window.MASCOT_FILES = ["
  for file in "${files[@]}"; do
    echo "  '$file',"
  done
  echo "];"
  echo "window.MASCOT_COUNT = window.MASCOT_FILES.length;"
} > "$OUT_FILE"

echo "Updated $OUT_FILE with ${#files[@]} mascot entries."
