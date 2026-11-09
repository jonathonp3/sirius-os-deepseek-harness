#!/usr/bin/env bash
# reconcile-patches.sh — apply .patch files to the fresh clone at PIN.
#
# Assumes `make build` (or equivalent) has already cloned upstream into
# .build/deepseek-harness at the pin in PIN. Runs after checkout, before
# the build. On conflict, leaves the file with conflict markers and exits
# non-zero so you can resolve and regenerate.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.build}"
CLONE="$WORK_DIR/deepseek-harness"
PIN="$(cat "$REPO_ROOT/PIN" 2>/dev/null || echo '')"

[[ -n "$PIN" ]] || { echo "error: PIN is empty" >&2; exit 1; }
[[ -d "$CLONE" ]] || { echo "error: $CLONE not found; run 'make build' first" >&2; exit 1; }

cd "$CLONE"

echo "==> reconcile: patches against $PIN"
applied=0
conflict=0
skipped=0

while IFS= read -r patch; do
  rel="${patch#"$REPO_ROOT"/source-patches/}"
  rel="${rel%.patch}"

  echo "--- $rel"

  if patch -p1 --forward --merge --silent < "$patch"; then
    echo "    applied"
    applied=$((applied + 1))
  elif [ $? -eq 1 ]; then
    # patch exits 1 when hunks are rejected (conflicts), 2 on errors
    echo "    CONFLICT — file left with merge markers at $CLONE/$rel"
    conflict=$((conflict + 1))
  else
    echo "    SKIPPED (already applied, or not a text patch)"
    skipped=$((skipped + 1))
  fi
done < <(find "$REPO_ROOT/source-patches" -name '*.patch' | sort)

echo ""
echo "==> summary: $applied applied, $skipped skipped, $conflict conflicted"

if [ $conflict -gt 0 ]; then
  cat >&2 <<EOF

Resolve conflicts, then regenerate the affected patches:

  # in $CLONE, edit the file(s) to resolve <<<<<<< / ======= / >>>>>>>
  # then for each conflicted file:
  diff -u --label "a/<rel>" --label "b/<rel>" \\
    "$WORK_DIR/baseline-$(cat "$REPO_ROOT/PIN_BASELINE" | cut -c1-12)/<rel>" \\
    "$CLONE/<rel>" > "$REPO_ROOT/source-patches/<rel>.patch"

Once all patches are regenerated:
  echo "$PIN" > $REPO_ROOT/PIN_BASELINE
  git add source-patches/ PIN_BASELINE
  git commit -m "repin to \$(cat $REPO_ROOT/PIN)"
EOF
  exit 1
fi

echo ""
echo "==> all patches applied. Update PIN_BASELINE when you've verified the build:"
echo "    echo '$PIN' > $REPO_ROOT/PIN_BASELINE"
