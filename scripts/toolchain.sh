#!/usr/bin/env bash
# toolchain.sh — install host build dependencies for the DeepSeek harness pipeline.
#
# Supported:
#   - Fedora / RHEL / CentOS Stream   (dnf)
#   - Ubuntu / Debian                 (apt)
#
# Works on local workstations and GitHub Actions runners (ubuntu-latest,
# fedora containers). Safe to re-run.

set -euo pipefail

# ---------------------------------------------------------------------------
# Detect package manager
# ---------------------------------------------------------------------------
if command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v apt-get >/dev/null 2>&1; then
  PM="apt"
else
  echo "error: unsupported distro (need dnf or apt-get)" >&2
  exit 1
fi

# Use sudo only when not already root (GitHub Fedora containers run as root).
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "error: not root and sudo not available" >&2
    exit 1
  fi
fi

echo "==> Detected package manager: $PM"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
if [ "$PM" = "dnf" ]; then
  $SUDO dnf install -y \
    git \
    gcc gcc-c++ make \
    python3 \
    nss nspr \
    gtk3 libX11 libXcomposite libXdamage libXext libXfixes libXrandr \
    libxcb libxkbcommon pango cairo \
    alsa-lib libdrm mesa-libgbm \
    fuse fuse-libs \
    rpm-build rpmdevtools \
    patchelf \
    appstream
else
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -y
  $SUDO apt-get install -y --no-install-recommends \
    git \
    curl ca-certificates gnupg lsb-release \
    build-essential \
    python3 python3-pip \
    libnss3 libnspr4 \
    libgtk-3-0 \
    libx11-6 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 \
    libxcb1 libxkbcommon0 libpango-1.0-0 libcairo2 \
    libasound2t64 \
    libdrm2 libgbm1 \
    fuse3 libfuse2 \
    rpm devscripts rpm2cpio \
    patchelf \
    appstream

  # Node.js LTS via Nodesource, only if node isn't already installed.
  # GitHub's ubuntu-latest already ships Node, so this is usually a no-op there.
  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO -E bash -
    $SUDO apt-get install -y nodejs
  fi
fi

# ---------------------------------------------------------------------------
# pnpm — required by build-linux.sh (pnpm install --frozen-lockfile)
#
# The CI workflows install pnpm separately (pnpm/action-setup on the
# release runner, `npm install -g pnpm` in the Fedora container). This
# installs it for local `make toolchain`, which otherwise leaves a fresh
# host unable to run `make build`.
# ---------------------------------------------------------------------------
if ! command -v pnpm >/dev/null 2>&1; then
  echo "==> Installing pnpm 11.28.5"
  if command -v corepack >/dev/null 2>&1; then
    $SUDO corepack enable
    $SUDO corepack prepare pnpm@11.28.5 --activate
  elif command -v npm >/dev/null 2>&1; then
    $SUDO npm install -g pnpm@11.28.5
  else
    echo "==> pnpm not installed and neither corepack nor npm available; skipping (CI installs pnpm separately)" >&2
  fi
else
  echo "==> pnpm already installed: $(pnpm --version)"
fi

echo "==> Environment set up ($PM)"
