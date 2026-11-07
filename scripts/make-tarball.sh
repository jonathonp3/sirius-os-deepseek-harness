#!/usr/bin/env bash
# make-tarball.sh — package dist/linux-unpacked/ into a .tar.xz.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$REPO_ROOT/dist/linux-unpacked}"
VERSION="$(grep -oP '"version":\s*"\K[^"]+' "$REPO_ROOT/.build/deepseek-harness/apps/desktop/package.json")"
OUT="${2:-$REPO_ROOT/dist/deepseek-harness-${VERSION}-linux-x64.tar.xz}"

[[ -d "$SRC" ]] || { echo "error: $SRC not found; run build-linux.sh first" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
echo "==> $OUT"
tar -C "$(dirname "$SRC")" -cJf "$OUT" "$(basename "$SRC")"
ls -lh "$OUT"
