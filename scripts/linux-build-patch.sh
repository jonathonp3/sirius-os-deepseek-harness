#!/usr/bin/env bash
# linux-build-patch.sh — turn a fresh deepseek-harness clone into a Linux build target.
#
# Usage:
#   ./linux-build-patch.sh <repo-root>
#   ./linux-build-patch.sh --check <repo-root>
#
# Copies 23 source files (modified or new) from the sibling source-patches/ tree
# into the target clone. Idempotent: running twice is a no-op. --check reports
# which files differ.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PATCHES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)/source-patches"

CHECK=0
[[ "${1:-}" == "--check" ]] && { CHECK=1; shift; }
REPO_ROOT="${1:?usage: linux-build-patch.sh [--check] <repo-root>}"
cd "$REPO_ROOT"

if [[ ! -f package.json ]] || [[ ! -d apps/desktop ]]; then
  echo "error: $REPO_ROOT does not look like the deepseek-harness repo" >&2
  exit 1
fi
if [[ ! -d "$SOURCE_PATCHES_ROOT" ]]; then
  echo "error: source-patches/ not found next to scripts/ ($SOURCE_PATCHES_ROOT)" >&2
  exit 1
fi

APPLIED=0
SKIPPED=0
FAILED=0

copy_source() {
  local rel="$1"
  local src="$SOURCE_PATCHES_ROOT/apps/$rel"
  local dst="apps/$rel"
  if [[ ! -f "$src" ]]; then
    echo "  MISSING source: $src"
    FAILED=$((FAILED + 1))
    return
  fi
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    if [[ $CHECK -eq 1 ]]; then echo "  ok:   $rel"; else echo "  skip: $rel (identical)"; fi
    SKIPPED=$((SKIPPED + 1))
    return
  fi
  if [[ $CHECK -eq 1 ]]; then
    echo "  diff: $rel"
    APPLIED=$((APPLIED + 1))
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  copy: $rel"
  APPLIED=$((APPLIED + 1))
}

echo "==> $REPO_ROOT"
echo "==> source-patches: $SOURCE_PATCHES_ROOT"
echo ""

while IFS= read -r src; do
  rel="${src#"$SOURCE_PATCHES_ROOT/apps/"}"
  copy_source "$rel"
done < <(find "$SOURCE_PATCHES_ROOT/apps" -type f | sort)

echo ""
if [[ $CHECK -eq 1 ]]; then
  echo "==> check: $SKIPPED ok, $APPLIED differ, $FAILED missing source"
  [[ $FAILED -eq 0 ]] || exit 1
else
  echo "==> done: $APPLIED copied, $SKIPPED identical, $FAILED failed"
  [[ $FAILED -eq 0 ]] || exit 1
fi
