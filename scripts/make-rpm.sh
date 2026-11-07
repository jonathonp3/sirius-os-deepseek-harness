#!/usr/bin/env bash
# make-rpm.sh — build the RPM from dist/linux-unpacked/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.build}"
OUT="${OUT:-$REPO_ROOT/dist}"
VERSION="$(grep -oP '"version":\s*"\K[^"]+' "$WORK_DIR/deepseek-harness/apps/desktop/package.json")"

echo "==> version: $VERSION"
echo "==> rpmbuild tree"
rpmdev-setuptree 2>/dev/null || mkdir -p ~/rpmbuild/{SOURCES,SPECS,RPMS,SRPMS,BUILD,BUILDROOT}

echo "==> Source0"
TARBALL="$HOME/rpmbuild/SOURCES/deepseek-harness-${VERSION}-linux-x64.tar.xz"
tar -C "$WORK_DIR/deepseek-harness/apps/desktop/.desktop-build/targets/linux-x64/unsigned-artifacts" \
    -cJf "$TARBALL" linux-unpacked
ls -lh "$TARBALL"

echo "==> SPF sources"
cp "$REPO_ROOT/packaging/org.jonathonp3.deepseek-harness.desktop" \
   "$REPO_ROOT/packaging/deepseek-harness.png" \
   "$REPO_ROOT/packaging/org.jonathonp3.deepseek-harness.appdata.xml" \
   "$HOME/rpmbuild/SOURCES/"

echo "==> spec"
cp "$REPO_ROOT/packaging/sirius-os-deepseek-harness.spec" "$HOME/rpmbuild/SPECS/"

echo "==> rpmbuild"
cd "$HOME/rpmbuild/SPECS"
rpmbuild -bb --define "_dsh_version $VERSION" sirius-os-deepseek-harness.spec

echo "==> copy RPM to $OUT"
mkdir -p "$OUT"
cp ~/rpmbuild/RPMS/x86_64/sirius-os-deepseek-harness-*.rpm "$OUT/"
ls -lh "$OUT"/*.rpm
