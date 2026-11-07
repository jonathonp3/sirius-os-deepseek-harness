# pipeline

Build pipeline for the DeepSeek harness: clone upstream at a pinned commit, apply
source patches, then produce tarball, AppImage, and RPM artifacts.

## Prerequisites

- Fedora (the `libraries` target uses `dnf`)
- `make`
- `sudo` access (for installing build dependencies)

## Quick start

```bash
# 1. Install build dependencies (git, nodejs, gcc, gtk3, alsa-lib, rpm-build, ...)
make toolchain
```
# 2. Build everything: build + tarball + appimage + rpm
```bash
make
```
Make targets

Target	What it does

| Make target | What it does |
|---|---|
| `make toolchain | Installs host build dependencies via `dnf` (requires `sudo`). |
| `make build` | Clones upstream at the commit in `PIN`, applies `source-patches/`, and produces `linux-unpacked/`. Requires a non-empty `PIN`. |
| `make tarball` | Packages the build output into a `.tar.gz` in `dist/`. |
| `make appimage` | Wraps the build output into an AppImage in `dist/`. |
| `make rpm` | Builds an RPM from the build output in `dist/`. |
| `make all` | Runs `build`, `tarball`, `appimage`, and `rpm` in that order. This is the default target. |
| `make check-pin` | Fails if `PIN` is empty. Used as a dependency of `build` and `repin`. |
| `make clean` | Removes `.build/` and `dist/`. |
| `make repin` | Re-pins to the commit in `PIN`, rebuilds, and refreshes `source-patches/` from the new build output. |

Typical workflows
First-time setup
```bash

make libraries
make
```
Incremental rebuild after changing patches
```bash

make build
make tarball appimage rpm
```
Updating the pinned upstream commit
```bash

# edit PIN to the new commit hash
make repin
git diff source-patches/    # review what the upstream change touched
```
Clean rebuild
```bash

make clean
make
```
Layout
```text

.
├── Makefile
├── PIN                     # pinned upstream commit
├── README.md
├── dist/                   # build artifacts (tarball, AppImage, RPM)
├── packaging/              # RPM spec and packaging files
├── scripts/
│   ├── toolchain.sh        # installs host build dependencies
│   ├── build-linux.sh      # clone + patch + build
│   ├── make-tarball.sh
│   ├── make-appimage.sh
│   └── make-rpm.sh
└── source-patches/         # patches applied on top of upstream
```
Notes

    make build and make repin abort early if PIN is empty.

    make repin overwrites source-patches/ with the files from the fresh build,
    so review git diff source-patches/ before committing.

    Artifacts land in dist/.

```text


A couple of small things to check against your actual repo:

- I listed `scripts/libraries.sh` and `PIN` per what you've shown; adjust if the filenames differ.
- If `dist/` or `.build/` are gitignored, you might add a line noting that — I left it out since I can't see your `.gitignore`.
- If you want badges or a license section, tell me and I'll add them.
```

