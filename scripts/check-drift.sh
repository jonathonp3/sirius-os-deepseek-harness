#!/usr/bin/env bash
# check-drift.sh — report which patches need attention when moving from
# PIN_BASELINE (the pin the patches were authored against) to PIN (the
# pin you're moving to).
#
# For each .patch:
#   - if upstream file is unchanged between the two pins → patch applies as-is
#   - if upstream file changed → three-way merge attempt; conflict markers
#     appear in the file if the patch hunks collide with upstream's changes
#
# Exit code: 0 if all patches are clean or apply cleanly, 1 if any conflict.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.build}"
OLD_PIN="$(cat "$REPO_ROOT/PIN_BASELINE" 2>/dev/null || echo '')"
NEW_PIN="$(cat "$REPO_ROOT/PIN" 2>/dev/null || echo '')"
UPSTREAM="${UPSTREAM:-https://github.com/deepseek-ai/deepseek-harness.git}"

[[ -n "$OLD_PIN" ]] || { echo "error: PIN_BASELINE is empty; see convert-patches.sh" >&2; exit 1; }
[[ -n "$NEW_PIN" ]] || { echo "error: PIN is empty" >&2; exit 1; }

if [ "$OLD_PIN" = "$NEW_PIN" ]; then
  echo "==> PIN_BASELINE == PIN ($OLD_PIN); nothing to check"
  exit 0
fi

OLD_DIR="$WORK_DIR/baseline-${OLD_PIN:0:12}"
NEW_DIR="$WORK_DIR/baseline-${NEW_PIN:0:12}"

for pair in "old:$OLD_DIR:$OLD_PIN" "new:$NEW_DIR:$NEW_PIN"; do
  IFS=':' read -r label dir pin <<< "$pair"
  if [ ! -d "$dir" ]; then
    echo "==> cloning upstream at $pin into $dir"
    git clone "$UPSTREAM" "$dir"
  fi
  ( cd "$dir" && git fetch origin >/dev/null 2>&1 && git checkout "$pin" >/dev/null 2>&1 ) \
    || { echo "error: cannot checkout $pin in $dir" >&2; exit 1; }
done

cd "$REPO_ROOT"

echo ""
echo "==> checking patches against $NEW_PIN (baseline: $OLD_PIN)"
echo ""

clean=0
changed=0
conflict=0

while IFS= read -r patch; do
  rel="${patch#source-patches/}"
  rel="${rel%.patch}"

  old="$OLD_DIR/$rel"
  new="$NEW_DIR/$rel"

  if [ ! -f "$new" ]; then
    echo "  NEW UPSTREAM FILE MISSING: $rel"
    echo "    (file existed at $OLD_PIN, absent at $NEW_PIN — patch may be obsolete)"
    changed=$((changed + 1))
    continue
  fi

  if [ -f "$old" ] && cmp -s "$old" "$new"; then
    echo "  clean: $rel (upstream unchanged)"
    clean=$((clean + 1))
    continue
  fi

  echo "  UPSTREAM CHANGED: $rel"
  changed=$((changed + 1))

  # Attempt a dry-run apply so we can classify before touching files
  if ( cd "$NEW_DIR" && patch -p1 --forward --dry-run --silent < "$REPO_ROOT/$patch" ); then
    echo "    patch applies cleanly (no conflict markers)"
  else
    echo "    CONFLICT — resolve in $NEW_DIR/$rel"
    conflict=$((conflict + 1))
  fi
done < <(find "$REPO_ROOT/source-patches" -name '*.patch' | sort)

echo ""
echo "==> summary: $clean clean, $changed upstream-changed, $conflict conflicted"
[[ $conflict -eq 0 ]] || exit 1
