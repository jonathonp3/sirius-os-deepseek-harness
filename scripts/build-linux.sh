#!/usr/bin/env bash
# build-linux.sh — clone upstream at the pin, apply source-patches, build linux-unpacked/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN="${PIN:-$(cat "$REPO_ROOT/PIN" 2>/dev/null || echo '')}"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.build}"
OUT="${OUT:-$REPO_ROOT/dist}"
UPSTREAM="${UPSTREAM:-https://github.com/deepseek-ai/deepseek-harness.git}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pin) PIN="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --work) WORK_DIR="$2"; shift 2 ;;
    *) echo "error: unknown argument $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PIN" ]] || { echo "error: no PIN; write a commit hash to $REPO_ROOT/PIN" >&2; exit 1; }

echo "==> pin:  $PIN"
echo "==> work: $WORK_DIR"
echo "==> out:  $OUT"

mkdir -p "$WORK_DIR" "$OUT"
cd "$WORK_DIR"

if [[ ! -d deepseek-harness ]]; then
  echo "==> cloning $UPSTREAM"
  git clone "$UPSTREAM" deepseek-harness
fi
cd deepseek-harness

echo "==> reset working tree before checkout"
git checkout -- . 2>/dev/null || true
git clean -fd -- apps/ 2>/dev/null || true

echo "==> checkout $PIN"
git fetch origin
git checkout "$PIN"

echo "==> apply source-patches"
"$REPO_ROOT/scripts/linux-build-patch.sh" .

echo "==> pnpm install"
pnpm install --frozen-lockfile

echo "==> build:artifacts"
pnpm -w run build:artifacts

echo "==> desktop build"
cd apps/desktop
pnpm run build

echo "==> package linux-x64 (dir)"
DSH_DESKTOP_APP_ID=com.deepseek.harness \
DSH_DESKTOP_TARGET_PLATFORM=linux \
DSH_DESKTOP_TARGET_ARCH=x64 \
  pnpm run package:linux:x64:dir

echo "==> copy linux-unpacked to $OUT"
cp -a .desktop-build/targets/linux-x64/unsigned-artifacts/linux-unpacked "$OUT/"
echo "==> done: $OUT/linux-unpacked"
