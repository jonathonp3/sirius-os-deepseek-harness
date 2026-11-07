#!/usr/bin/env bash
# build-srpm.sh — build a source RPM for COPR submission.
#
# Requires: `make build` has produced linux-unpacked/ under .build/.
# Output:   dist/sirius-os-deepseek-harness-<version>-1.src.rpm
#
# The spec's Source0 is a bare filename, so rpmbuild -bs finds it in
# ~/rpmbuild/SOURCES/ and embeds it in the SRPM. COPR extracts it there.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.build}"
OUT="${OUT:-$REPO_ROOT/dist}"

DESKTOP_JSON="$WORK_DIR/deepseek-harness/apps/desktop/package.json"
VERSION="$(grep -oP '"version":\s*"\K[^"]+' "$DESKTOP_JSON")"
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
   "$HOME/rpmbuild/SOURCES/"
cp "$REPO_ROOT/packaging/sirius-os-deepseek-harness.spec" "$HOME/rpmbuild/SPECS/"

echo "==> rpmbuild -bs"
cd "$HOME/rpmbuild/SPECS"
rpmbuild -bs --define "_dsh_version $VERSION" sirius-os-deepseek-harness.spec

echo "==> copy SRPM to $OUT"
mkdir -p "$OUT"
cp ~/rpmbuild/SRPMS/sirius-os-deepseek-harness-*.src.rpm "$OUT/"
ls -lh "$OUT"/*.src.rpm
