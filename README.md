# sirius-os-deepseek-harness

Packaging pipeline for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
on Fedora. Produces a self-contained **RPM** (hosted on
[Fedora COPR](https://copr.fedorainfracloud.org/coprs/jonathonp3/sirius-os/))
and an **AppImage** (hosted on
[GitHub Releases](https://github.com/jonathonp3/sirius-os-deepseek-harness/releases)).

---


## Install

### Atomic systems (Silverblue, Kinoite, Bazzite, Aurora, …)

```bash
sudo curl -Lo /etc/yum.repos.d/_copr_jonathonp3-sirius-os.repo \
  "https://copr.fedorainfracloud.org/coprs/jonathonp3/sirius-os/repo/fedora-$(rpm -E %fedora)/jonathonp3-sirius-os-fedora-$(rpm -E %fedora).repo"

rpm-ostree install sirius-os-deepseek-harness
systemctl reboot
```

## Workstation (Fedora)

```bash
sudo dnf copr enable jonathonp3/sirius-os
sudo dnf install sirius-os-deepseek-harness
```

## AppImage (any distro)

Download the latest .AppImage from
GitHub Releases,
```bash
chmod +x it, and run it. No installation, no root.
```
Launch from the application menu, or:

```bash
deepseek-harness
```

---


## What this project is

This repository is a downstream packaging pipeline for upstream DeepSeek Harness. It does not vendor the upstream source. Instead, it:

1. Clones upstream at the commit recorded in `PIN`.
2. Applies a curated set of patches from `source-patches/`.
3. Builds the desktop Electron app and packages it as:
   - An RPM with a self-contained payload in `/usr/libexec/deepseek-harness/`
   - An AppImage containing the same payload in a single runnable file
4. Publishes the RPM to COPR and the AppImage to GitHub Releases through CI when a version tag is pushed.

Each release is rebuilt from the pinned upstream commit and the patch set. There is no compiled-once, shipped-forever binary, so the relationship to upstream remains explicit and reproducible.


---


## Why a fork?

Upstream DeepSeek Harness is an Electron app distributed as signed binaries for macOS and Windows, while Linux support is still at an early stage. Running it on Fedora—especially Fedora Atomic/Silverblue—requires changes that upstream does not currently provide.

This fork adds:

- **Linux packaging:** Adds an unsigned Linux x64 build target and produces RPM and AppImage packages.
- **Atomic-host installability:** Fedora Atomic installs software onto its immutable root filesystem rather than from tarballs. The RPM places the app payload in `/usr/libexec/` and includes a desktop entry, icon, and appdata, allowing installation with `rpm-ostree` and adding the app to the desktop menu.
- **Fedora-native updates:** AppImage users receive updates through `electron-updater` and the GitHub Releases feed. RPM users receive updates through `rpm-ostree upgrade` or `dnf upgrade` via COPR.
- **Linux fixes:** `source-patches/` contains the minimal changes needed to build and run on Linux, including update-feed wiring and package-target fixes. The patches are kept small, reviewed, and reapplied against each new pin.

The goal is to stay close to upstream, carrying only the changes needed to make the app installable, updatable, and well integrated with Fedora—especially Fedora Atomic.

The goal is not to diverge from upstream. It is to track upstream
closely and carry only what is required to make the app installable,
updatable, and well-integrated on Fedora — Atomic in particular.

### Reproducibility

Every released artifact is produced from:

- the upstream commit recorded in **PIN**
- the patch set in **source-patches/**
- the packaging files in **packaging/**
- the build scripts in **scripts/**

Pin and patches are committed together, so checking out any release
tag and running the pipeline reproduces the same binaries. Upstream
moves fast, so re-pinning is a deliberate, tested step — not automatic
on every upstream commit.

---

## Building locally

Requires Fedora (or a Fedora container), make, sudo for installing
build dependencies, and rpmbuild for the RPM.

```bash
# 1. Install host build dependencies (git, nodejs, gcc, gtk3, alsa-lib, rpm-build, …)
make toolchain

# 2. Build everything: clone at PIN, apply patches, produce tarball + AppImage + SRPM
make all
```

Artifacts land in **dist/.**

| Target | What it does |
|---|---|
| `make toolchain` | Installs host build dependencies via `dnf` (requires `sudo`). |
| `make build` | Clones upstream at the commit in `PIN`, applies `source-patches/`, and produces `linux-unpacked/`. Requires a non-empty `PIN`. |
| `make tarball` | Packages the build output into a `.tar.xz` in `dist/`. |
| `make appimage` | Builds the AppImage. Set `PUBLISH=always` and `GH_TOKEN` to upload it to GitHub Releases. |
| `make srpm` | Builds a source RPM for COPR submission in `dist/`. |
| `make all` | Runs `build`, `tarball`, `appimage`, and `srpm` in that order. This is the default target. |
| `make check-pin` | Fails if `PIN` is empty. A dependency of `build` and `repin`. |
| `make clean` | Removes `.build/` and `dist/`. |
| `make repin` | Re-pins to the commit in `PIN`, rebuilds, and refreshes `source-patches/`. Review `git diff source-patches/` afterward. |


## Re-pinning upstream

```bash
# edit PIN to a new upstream commit
make repin
git diff source-patches/    # review what upstream changed; fix patch drift if any
make all                    # full local validation
```

## CI

Two GitHub Actions workflows run when a version tag (`v*`) is pushed or when manually triggered:

- `.github/workflows/release.yml` builds the AppImage on Ubuntu and publishes it to the GitHub Release for that tag.
- `.github/workflows/copr.yml` builds the SRPM in a Fedora container and submits it to COPR. The SRPM is also attached to the GitHub Release.

The version in `source-patches/apps/desktop/package.json` must match the tag, without the leading `v` (for example, tag `v0.2.2-alpha.3` matches version `0.2.2-alpha.3`). Both workflows verify this on tag pushes.


## Layout

```text.
├── Makefile
├── PIN                     # pinned upstream commit
├── README.md
├── dist/                   # build artifacts (tarball, AppImage, SRPM) — gitignored
├── packaging/              # RPM spec, desktop entry, icon, appdata
├── scripts/
│   ├── toolchain.sh        # installs host build dependencies
│   ├── build-linux.sh      # clone + patch + build
│   ├── linux-build-patch.sh# copy source-patches/ into the clone
│   ├── make-tarball.sh
│   ├── make-appimage.sh
│   └── build-srpm.sh
└── source-patches/         # patches applied on top of the pinned upstream commit
```

## Notes

- `make build` and `make repin` stop early if `PIN` is empty.
- `make repin` overwrites `source-patches/` with files from the fresh clone. Review `git diff source-patches/` before committing.
- `dist/` and `.build/` are gitignored.
- The AppImage is unsigned. RPMs built by COPR are also unsigned; COPR signing applies only when a package is promoted to a Fedora repository.


## License

Upstream DeepSeek Harness is MIT-licensed. The packaging files in
this repository follow the same license.









