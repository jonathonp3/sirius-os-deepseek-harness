#!/usr/bin/env bash
# build-srpm.sh — build a source RPM for COPR submission.
#
# Requires: `make build` has produced linux-unpacked/ under .build/.
# Output:   dist/sirius-os-deepseek-harness-<version>-<release>.<dist>.src.rpm
#
# The spec's Source0 is a bare filename, so rpmbuild -bs finds it in
# ~/rpmbuild/SOURCES/ and embeds it in the SRPM. COPR extracts it there.
#
# The spec is templated: @DSH_VERSION@ is replaced with the version read
# from apps/desktop/package.json, so no external --define is needed at
# build time — COPR can rebuild the SRPM without knowing our macros.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.build}"
OUT="${OUT:-$REPO_ROOT/dist}"

DESKTOP_JSON="$WORK_DIR/deepseek-harness/apps/desktop/package.json"
VERSION="$(grep -oP '"version":\s*"\K[^"]+' "$DESKTOP_JSON" | head -1)"
echo "==> version: $VERSION"

ARTIFACT_DIR="$WORK_DIR/deepseek-harness/apps/desktop/.desktop-build/targets/linux-x64/unsigned-artifacts"
if [ ! -d "$ARTIFACT_DIR/linux-unpacked" ]; then
  echo "error: $ARTIFACT_DIR/linux-unpacked not found; run 'make build' first" >&2
  exit 1
fi

rpmdev-setuptree 2>/dev/null || mkdir -p ~/rpmbuild/{SOURCES,SPECS,RPMS,SRPMS,BUILD,BUILDROOT}

echo "==> Source0 tarball"
TARBALL="$HOME/rpmbuild/SOURCES/deepseek-harness-${VERSION}-linux-x64.tar.xz"
tar -C "$ARTIFACT_DIR" -cJf "$TARBALL" linux-unpacked
ls -lh "$TARBALL"

echo "==> source files"
cp "$REPO_ROOT/packaging/org.jonathonp3.deepseek-harness.desktop" \
   "$REPO_ROOT/packaging/deepseek-harness.png" \
   "$REPO_ROOT/packaging/org.jonathonp3.deepseek-harness.appdata.xml" \
   "$REPO_ROOT/packaging/dsh" \
   "$HOME/rpmbuild/SOURCES/"

echo "==> template spec"
SPEC_SRC="$REPO_ROOT/packaging/sirius-os-deepseek-harness.spec"
SPEC_DST="$HOME/rpmbuild/SPECS/sirius-os-deepseek-harness.spec"
sed "s|@DSH_VERSION@|${VERSION}|g" "$SPEC_SRC" > "$SPEC_DST"
if grep -q '@DSH_VERSION@' "$SPEC_DST"; then
  echo "error: @DSH_VERSION@ placeholder still present in generated spec" >&2
  exit 1
fi

echo "==> rpmbuild -bs"
MARKER="$HOME/rpmbuild/SRPMS/.last-build-$$"
touch "$MARKER"
cd "$HOME/rpmbuild/SPECS"
rpmbuild -bs "$SPEC_DST"

echo "==> copy SRPM to $OUT"
mkdir -p "$OUT"
# Copy exactly the SRPM(s) this run produced, not stale ones from earlier releases.
found=0
while IFS= read -r srpm; do
  cp -v "$srpm" "$OUT/"
  found=$((found + 1))
done < <(find "$HOME/rpmbuild/SRPMS" -maxdepth 1 -name 'sirius-os-deepseek-harness-*.src.rpm' -newer "$MARKER")
rm -f "$MARKER"

if [ "$found" -eq 0 ]; then
  echo "error: rpmbuild -bs did not produce a new .src.rpm" >&2
  exit 1
fi

ls -lh "$OUT"/*.src.rpm
