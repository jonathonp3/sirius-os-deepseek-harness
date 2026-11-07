#!/usr/bin/env bash
# make-appimage.sh — build the unsigned AppImage and publish it (plus update
# metadata) to GitHub Releases via electron-builder's `publish: github`.
#
# Target repo: https://github.com/jonathonp3/sirius-os-deepseek-harness
#
# Requires:
#   - build.publish configured in package.json (provider: github, owner, repo)
#   - GH_TOKEN in the environment (repo scope) — electron-builder reads it
#   - package.json `version` bumped for each release
#
# Env overrides:
#   WORK_DIR   build directory           (default: <repo>/.build)
#   OUT        artifact output directory (default: <repo>/dist)
#   PUBLISH    "always" | "never" | "onTag" | "onTagOrDraft"  (default: always)
#              Set PUBLISH=never for local builds without a token.
#   GH_OWNER   (default: jonathonp3)
#   GH_REPO    (default: sirius-os-deepseek-harness)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.build}"
OUT="${OUT:-$REPO_ROOT/dist}"
# PUBLISH="${PUBLISH:-always}"
PUBLISH="${PUBLISH:-never}"

GH_OWNER="${GH_OWNER:-jonathonp3}"
GH_REPO="${GH_REPO:-sirius-os-deepseek-harness}"

APP_DIR="$WORK_DIR/deepseek-harness/apps/desktop"

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
if [ ! -d "$APP_DIR" ]; then
  echo "error: app directory not found: $APP_DIR" >&2
  echo "       run 'make build' first" >&2
  exit 1
fi

if [ "$PUBLISH" != "never" ] && [ -z "${GH_TOKEN:-}" ]; then
  echo "error: PUBLISH=$PUBLISH but GH_TOKEN is not set" >&2
  echo "       export GH_TOKEN=<personal access token with repo scope>" >&2
  echo "       or run with PUBLISH=never for a local build" >&2
  exit 1
fi

cd "$APP_DIR"

# ---------------------------------------------------------------------------
# Build + publish
# ---------------------------------------------------------------------------
echo "==> package linux-x64 (unsigned AppImage)"
echo "    repo:    https://github.com/${GH_OWNER}/${GH_REPO}"
echo "    publish: $PUBLISH"

PUBLISH_ARGS=()
if [ "$PUBLISH" != "never" ]; then
  PUBLISH_ARGS=( -- "--publish" "$PUBLISH" )
fi

DSH_DESKTOP_APP_ID=com.deepseek.harness \
DSH_DESKTOP_TARGET_PLATFORM=linux \
DSH_DESKTOP_TARGET_ARCH=x64 \
  pnpm run package:linux:x64:unsigned "${PUBLISH_ARGS[@]}"

# ---------------------------------------------------------------------------
# Collect artifacts into dist/
# ---------------------------------------------------------------------------
echo "==> collecting artifacts into $OUT"
mkdir -p "$OUT"

ARTIFACT_DIR=".desktop-build/targets/linux-x64/unsigned-artifacts"
if [ ! -d "$ARTIFACT_DIR" ]; then
  echo "error: artifact directory not found: $ARTIFACT_DIR" >&2
  exit 1
fi

shopt -s nullglob

appimages=( "$ARTIFACT_DIR"/*.AppImage )
if [ ${#appimages[@]} -eq 0 ]; then
  echo "error: no .AppImage produced in $ARTIFACT_DIR" >&2
  exit 1
fi
cp -a "${appimages[@]}" "$OUT/"

# Update metadata — electron-updater on Linux reads latest-linux.yml
for f in latest-linux.yml latest-linux.yaml; do
  if [ -f "$ARTIFACT_DIR/$f" ]; then
    cp -a "$ARTIFACT_DIR/$f" "$OUT/"
  fi
done

blockmaps=( "$ARTIFACT_DIR"/*.blockmap )
if [ ${#blockmaps[@]} -gt 0 ]; then
  cp -a "${blockmaps[@]}" "$OUT/"
fi

shopt -u nullglob

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo "==> AppImage ready in $OUT"
ls -lh "$OUT"/*.AppImage 2>/dev/null || true

if [ -f "$OUT/latest-linux.yml" ]; then
  echo "==> update metadata present: $OUT/latest-linux.yml"
else
  echo "warning: latest-linux.yml was not produced — auto-update will not work" >&2
  echo "         check that build.publish is set in package.json and PUBLISH != never" >&2
fi

if [ "$PUBLISH" != "never" ]; then
  echo "==> published to https://github.com/${GH_OWNER}/${GH_REPO}/releases"
  echo "    Reminder: GitHub uploads land as a DRAFT release unless CI is on a tag."
  echo "    Publish the release so electron-updater can see it."
fi
