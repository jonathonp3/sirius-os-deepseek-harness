#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PATCHES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)/source-patches"

CHECK=0
[[ "${1:-}" == "--check" ]] && { CHECK=1; shift; }
CLONE="${1:?usage: linux-build-patch.sh [--check] <clone-root>}"
cd "$CLONE"

if [[ ! -f package.json ]] || [[ ! -d apps/desktop ]]; then
  echo "error: $CLONE does not look like the deepseek-harness repo" >&2
  exit 1
fi

echo "==> $CLONE"

copy_ok=0; copy_new=0; copy_diff=0; patch_clean=0; patch_conflict=0; patch_applied=0; patch_failed=0

while IFS= read -r full; do
  rel="${full#"$SOURCE_PATCHES_ROOT/"}"
  if [[ $CHECK -eq 1 ]]; then
    if [[ ! -f "$rel" ]]; then echo "  copy-new:  $rel"; copy_new=$((copy_new+1))
    elif cmp -s "$full" "$rel"; then echo "  copy-ok:   $rel"; copy_ok=$((copy_ok+1))
    else echo "  copy-diff: $rel"; copy_diff=$((copy_diff+1)); fi
  else
    mkdir -p "$(dirname "$rel")"; cp "$full" "$rel"; echo "  copy: $rel"
  fi
done < <(find "$SOURCE_PATCHES_ROOT" -type f ! -name '*.patch' ! -name '*.orig' | sort)

while IFS= read -r patch; do
  rel="${patch#"$SOURCE_PATCHES_ROOT/"}"; rel="${rel%.patch}"
  if [[ $CHECK -eq 1 ]]; then
    if patch -p1 --forward --dry-run --silent < "$patch" >/dev/null 2>&1; then
      echo "  clean:     $rel"; patch_clean=$((patch_clean+1))
    else
      echo "  CONFLICT:  $rel"; patch_conflict=$((patch_conflict+1))
    fi
  else
    if patch -p1 --forward --silent < "$patch" >/dev/null 2>&1; then
      echo "  apply: $rel"; patch_applied=$((patch_applied+1))
    else
      echo "  FAILED: $rel"; patch_failed=$((patch_failed+1))
    fi
  fi
done < <(find "$SOURCE_PATCHES_ROOT" -name '*.patch' | sort)

if [[ $CHECK -eq 1 ]]; then
  echo "==> check: $copy_ok copy-ok, $copy_new copy-new, $copy_diff copy-diff, $patch_clean clean, $patch_conflict conflict"
  [[ $copy_diff -eq 0 && $patch_conflict -eq 0 ]] || exit 1
else
  echo "==> done: $patch_applied applied, $patch_failed failed"
  [[ $patch_failed -eq 0 ]] || exit 1
fi
