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

### The two pin files

Two files track which upstream commit is being built and which one the
patches were authored against. They start identical and diverge only during
a re-pin.

| File | Meaning | When it changes |
|---|---|---|
| `PIN` | The upstream commit to build. `build-linux.sh` reads it to check out the commit before applying patches. | Whenever I decide to move to a new upstream commit. |
| `PIN_BASELINE` | The upstream commit the patches in `source-patches/` were generated against. `check-drift.sh` reads it to determine which baseline to compare against. | — |


---

### Why two?

Each `.patch file` is a diff between `PIN_BASELINE` and the desired
post-patch state. If PIN moves forward, the upstream files may have
changed in ways that overlap your patch hunks. `check-drift.sh` compares
`PIN_BASELINE` (the tree your patches assume) against `PIN` (the tree you
want to build) and reports, per file:

- `clean` — upstream unchanged; patch applies as-is

- `UPSTREAM CHANGED` — upstream modified the file; patch may or may not still apply

- `CONFLICT` — a hunk collides with upstream's change; manual resolution needed

When `PIN == PIN_BASELINE`, there is nothing to check. When they diverge,
check-drift.sh tells you exactly which patches need attention.

After a `re-pin` is validated (patches applied, build succeeded, conflicts
resolved), set PIN_BASELINE to PIN so the next re-pin compares against
the new correct baseline.

## Building locally

Requires Fedora (or a Fedora container), make, sudo for installing
build dependencies, and rpmbuild for the RPM.

```bash
# 1. Install host build dependencies (git, nodejs, gcc, gtk3, alsa-lib, rpm-build, …)
make toolchain

# 2. Build everything: clone at PIN, apply patches, produce tarball + AppImage + SRPM
make all
```

---

Artifacts are placed in `dist/`.

| Target | What it does |
|---|---|
| `make toolchain` | Installs host build dependencies via `dnf` (requires `sudo`). |
| `make build` | Clones upstream at `PIN`, applies `source-patches/`, and produces `linux-unpacked/`. |
| `make tarball` | Packages the build output into a `.tar.xz` file in `dist/`. |
| `make appimage` | Builds the AppImage. Set `PUBLISH=always` and `GH_TOKEN` to upload it to GitHub Releases. |
| `make srpm` | Builds a source RPM for COPR submission in `dist/`. |
| `make all` | Runs `build`, `tarball`, `appimage`, and `srpm`. This is the default target. |
| `make check-pin` | Fails if `PIN` is empty. It is a dependency of `build` and `repin`. |
| `make clean` | Removes `.build/` and `dist/`. |
| `make repin` | Runs `check-drift.sh`, builds with the new `PIN`, and updates `PIN_BASELINE` on success. |


## Re-pinning upstream

```bash
# 1. Set the new upstream commit
echo <new-commit-hash> > PIN

# 2. Check which patches drift against the new baseline
make repin                  # full local validation
```

`make repin` runs `check-drift.sh`, which:

- Clones PIN_BASELINE (if not cached in .build/) into `.build/baseline-<pin12>/`

- Clones `PIN` into `.build/baseline-<pin12>/`

- Dry-runs each `.patch` against the `PIN` clone

- Reports per-file: `clean`, `UPSTREAM CHANGED` (patch applies cleanly), or `CONFLICT`

If any patch conflicts, repin stops so you can resolve it:

```bash
# Edit the affected file in .build/baseline-<new-pin>/<path> to merge markers
# Then regenerate its .patch:
diff -u --label "a/<path>" --label "b/<path>" \
  .build/baseline-<old-pin12>/<path> \
  .build/baseline-<new-pin12>/<path> > source-patches/<path>.patch

# Re-run
make repin
```

Once all patches apply cleanly and the build succeeds, repin writes the
new `PIN` value into `PIN_BASELINE`:

```bash
# Review what changed
git diff source-patches/ PIN_BASELINE

# Commit the re-pin
git add PIN PIN_BASELINE source-patches/
git commit -m "repin to $(cat PIN)"
```

---

## Patch format

Patches are stored as unified diffs (`.patch files`) rather than full
file copies. Each `.patch` is a `diff -u` between the upstream file at
`PIN_BASELINE` and the desired post-patch content.

Binary files (currently only `icon-linux.png)` cannot be represented as
text diffs and are stored as full copies in source-patches/.
`linux-build-patch.sh `handles both forms: `.patch` files via `patch -p1`,
non-`.patch` files via `cp`.

---

## Creating a new patch

For a new file that upstream doesn't ship (or a binary), keep it as a full
copy under `source-patches/apps/....` For a text file upstream does ship,
create a .patch against the current baseline:

```bash
diff -u --label "a/apps/<path>" --label "b/apps/<path>" \
  .build/baseline-$(cat PIN_BASELINE | cut -c1-12)/apps/<path> \
  <your-modified-file> > source-patches/apps/<path>.patch
```

Then verify it applies:

```bash
cd .build/baseline-$(cat PIN | cut -c1-12)
patch -p1 --dry-run < ~/sirius-os-deepseek-harness/source-patches/apps/<path>.patch
```

---


## CI

Two GitHub Actions workflows run when a version tag (`v*`) is pushed or when manually triggered:

- `.github/workflows/release.yml` builds the AppImage on Ubuntu and publishes it to the GitHub Release for that tag.
- `.github/workflows/copr.yml` builds the SRPM in a Fedora container and submits it to COPR. The SRPM is also attached to the GitHub Release.

The version in `source-patches/apps/desktop/package.json` must match the tag, without the leading `v` (for example, tag `v0.2.2-alpha.3` matches version `0.2.2-alpha.3`). Both workflows verify this on tag pushes.


## Layout

```text
.
├── Makefile
├── PIN                     # upstream commit to build
├── PIN_BASELINE            # upstream commit the patches were authored against
├── README.md
├── dist/                   # build artifacts — gitignored
├── packaging/              # RPM spec, desktop entry, icon, appdata
├── scripts/
│   ├── toolchain.sh        # installs host build dependencies
│   ├── build-linux.sh      # clone + patch + build
│   ├── linux-build-patch.sh# apply .patch files and copy full files
│   ├── convert-patches.sh  # one-time conversion from full copies to .patch
│   ├── check-drift.sh      # per-file drift report on a new PIN
│   ├── reconcile-patches.sh# apply patches during repin
│   ├── make-tarball.sh
│   ├── make-appimage.sh
│   └── build-srpm.sh
└── source-patches/         # .patch files + full copies for binaries
```

## Notes

- `make build` and `make repin` stop early if PIN is empty.
- make `repin` uses `check-drift.sh` to report which patches need attention;
it does not overwrite patches automatically.
- `dist/` and `.build/` are gitignored.
- `.build/baseline-<pin12>/` directories accumulate with each re-pin. I prune the
old ones after a successful re-pin:

```
ls -d .build/baseline-* | sort | head -n -1 | xargs -r rm -rf
```

(keeps only the most recent baseline)

The AppImage is unsigned. RPMs built by COPR are also unsigned; COPR
signing applies only when a package is promoted to a Fedora repository.


## License

Upstream DeepSeek Harness is MIT-licensed. The packaging files in
this repository follow the same license.









