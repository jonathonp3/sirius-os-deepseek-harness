#!/usr/bin/env bash
# check-drift.sh — report which patches need attention when moving from
# PIN_BASELINE (the pin the patches were authored against) to PIN (the
# pin you're moving to).
#
# For each .patch:
#   - upstream file unchanged between the two pins  -> clean
#   - upstream file changed, patch dry-runs cleanly -> UPSTREAM CHANGED (ok)
#   - upstream file changed, patch dry-run fails    -> CONFLICT
#   - create-from-empty patch, dry-runs cleanly     -> clean (new file)
#   - file existed at old pin, absent at new pin    -> UPSTREAM FILE MISSING
#
# This script only dry-runs patches. It does not write conflict markers;
# use reconcile-patches.sh (or build-linux.sh) to apply them with --merge.
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
missing=0

while IFS= read -r patch; do
  rel="${patch#"$REPO_ROOT/"}"
  rel="${rel#source-patches/}"
  rel="${rel%.patch}"

  old="$OLD_DIR/$rel"
  new="$NEW_DIR/$rel"

  old_exists=0; [ -f "$old" ] && old_exists=1
  new_exists=0; [ -f "$new" ] && new_exists=1

  # Patch applies cleanly to the new tree?
  if ( cd "$NEW_DIR" && patch -p1 --forward --dry-run --silent < "$patch" >/dev/null 2>&1 ); then
    applies=1
  else
    applies=0
  fi

  if [ "$new_exists" = 0 ] && [ "$old_exists" = 1 ]; then
    echo "  UPSTREAM FILE MISSING: $rel"
    echo "    (existed at $OLD_PIN, absent at $NEW_PIN — patch may be obsolete)"
    missing=$((missing + 1))
  elif [ "$new_exists" = 0 ] && [ "$old_exists" = 0 ]; then
    # Create-from-empty patch; upstream never had this file.
    if [ "$applies" = 1 ]; then
      echo "  clean: $rel (create-new, applies)"
      clean=$((clean + 1))
    else
      echo "  CONFLICT: $rel (create-new, dry-run failed)"
      conflict=$((conflict + 1))
    fi
  elif [ "$old_exists" = 1 ] && cmp -s "$old" "$new"; then
    echo "  clean: $rel (upstream unchanged)"
    clean=$((clean + 1))
  else
    echo "  UPSTREAM CHANGED: $rel"
    changed=$((changed + 1))
    if [ "$applies" = 1 ]; then
      echo "    patch applies cleanly (no conflict markers needed)"
    else
      echo "    CONFLICT — resolve in $NEW_DIR/$rel"
      conflict=$((conflict + 1))
    fi
  fi
done < <(find "$REPO_ROOT/source-patches" -name '*.patch' | sort)

echo ""
echo "==> summary: $clean clean, $changed upstream-changed, $conflict conflicted, $missing missing"
[[ $conflict -eq 0 && $missing -eq 0 ]] || exit 1
