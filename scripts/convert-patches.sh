#!/usr/bin/env bash
# convert-patches.sh — convert source-patches/ from full file copies to
# unified diffs (.patch) against the upstream commit in PIN.
#
# Run once when migrating to diff-based patches. After this, `make repin`
# and reconcile-patches.sh work against .patch files.
#
# Preserves the full-copy files by renaming to *.orig so you can compare
# during transition. Delete them when satisfied.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.build}"
PIN="$(cat "$REPO_ROOT/PIN" 2>/dev/null || echo '')"
UPSTREAM="${UPSTREAM:-https://github.com/deepseek-ai/deepseek-harness.git}"

[[ -n "$PIN" ]] || { echo "error: PIN is empty" >&2; exit 1; }

BASELINE="$WORK_DIR/baseline-${PIN:0:12}"
if [ ! -d "$BASELINE" ]; then
  echo "==> cloning upstream at $PIN into $BASELINE"
  git clone "$UPSTREAM" "$BASELINE"
  ( cd "$BASELINE" && git checkout "$PIN" )
else
  echo "==> reusing $BASELINE"
  ( cd "$BASELINE" && git fetch origin && git checkout "$PIN" )
fi

cd "$REPO_ROOT"

echo "==> converting full copies to .patch files"
converted=0
skipped=0

while IFS= read -r patched; do
  rel="${patched#source-patches/}"

  # Skip files already in .patch form
  case "$rel" in
    *.patch) skipped=$((skipped + 1)); continue ;;
    *.orig)  skipped=$((skipped + 1)); continue ;;
  esac

  upstream="$BASELINE/$rel"
  out="source-patches/${rel}.patch"

  if [ ! -f "$upstream" ]; then
    echo "  NEW: $rel (no upstream baseline)"
    {
      echo "--- /dev/null"
      echo "+++ b/$rel"
      diff -u /dev/null "$patched" | tail -n +3
    } > "$out" || true
  else
    if cmp -s "$upstream" "$patched"; then
      echo "  IDENTICAL: $rel (patch would be empty; removing)"
      rm -f "$patched"
      skipped=$((skipped + 1))
      continue
    fi
    diff -u --label "a/$rel" --label "b/$rel" "$upstream" "$patched" > "$out" || true
  fi

  # Preserve the full copy for reference during transition
  mv "$patched" "${patched}.orig"
  echo "  wrote: $out"
  converted=$((converted + 1))
done < <(find source-patches -type f | sort)

echo ""
echo "==> done: $converted converted, $skipped skipped"
echo "    review source-patches/*.patch"
echo "    when satisfied: git rm \$(find source-patches -name '*.orig')"
echo "    and: git add source-patches/"
