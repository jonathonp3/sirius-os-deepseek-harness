# Next Build Checklist — `sirius-os-deepseek-harness`

Reusable runbook for the next Fedora build/release. Written to be usable **without this conversation's context**.
Last updated: **2026-11-20** (after 0.2.2-rc.5 / Release 7; docs + COPR Fedora-version step).

---

## 0. Context you need if everything is lost

| Thing | Value |
|---|---|
| GitHub repo (source of truth) | `git@github.com:jonathonp3/sirius-os-deepseek-harness.git` — https://github.com/jonathonp3/sirius-os-deepseek-harness |
| Local checkout (workstation `Wolf-359`) | `/var/home/jonathon/sirius-os-deepseek-harness` |
| VM | `Workstation-deepseek`, UUID `504356c1-7fdd-4648-b18a-98a3cc5ec092`, IP `192.168.100.48`, user `jonathon`, hostname `workstation-vm`, Fedora 45 |
| VM pipeline (plain copy — **not a git repo**) | `/home/jonathon/pipeline` |
| Upstream | `https://github.com/deepseek-ai/deepseek-harness` |
| COPR project | https://copr.fedorainfracloud.org/coprs/jonathonp3/sirius-os/ |
| GitHub auth | `gh` is logged in as `jonathonp3` (scopes include `repo`, `workflow`); git push uses SSH key |
| SSH gotcha | Plain `ssh` fails with `Bad owner or permissions on /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf`. Use `ssh -F /dev/null jonathon@192.168.100.48` (same for `scp -F /dev/null`). Permanent fix on the workstation: `sudo chown -h root:root /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf`. |
| VM sudo | Requires a password. For automation, grant temporarily: `echo 'jonathon ALL=(ALL) NOPASSWD:ALL' \| sudo tee /etc/sudoers.d/jonathon-nopasswd`, and **remove it afterwards**: `sudo rm -f /etc/sudoers.d/jonathon-nopasswd`. |

### Version rules (memorise these)

- Upstream version `0.2.2-rc.5` → GitHub tag **`v0.2.2-rc.5`** → RPM version **`0.2.2.rc.5`** (dash → dot).
- NVR example: `sirius-os-deepseek-harness-0.2.2.rc.5-7.fc45` (`Release` is independent of the upstream version).
- `PIN` = upstream **commit to build**. `PIN_BASELINE` = commit the patches were authored against. They are equal except during a re-pin.
- **Pin policy:** pin the upstream **master-sync merge that follows the release tag**, not the tag itself. Example: tag `dsh-v0.2.2-rc.5` = `9c2670d3bc…`, pin = `2e39e70496…` (merge “sync release … to master”).
- Pin/tag/appdata versions are coupled: `PIN`'s `apps/desktop/package.json` version must equal the tag (CI enforces `v${VERSION} == tag`).
- `Release:` increments for packaging-only changes; the appdata `<release version>` changes only when the **upstream version** changes.

### Current state snapshot (2026-11-19)

| Item | Value |
|---|---|
| `main` | `a937d876e584c0130feb41d530fe19620409db48` — “ci(copr): confirm the container Fedora version” (after the docs commit `33e2513`) |
| Tag `v0.2.2-rc.5` | `0a7c147` (force-moved from `a069b4d`; release is published) |
| Tag `v0.2.2-rc.1` | `929a166` |
| `PIN` / `PIN_BASELINE` | `2e39e70496aa02986ca6a820c5d497e816b69d7e` |
| Upstream version at pin | `0.2.2-rc.5` |
| appdata | release `0.2.2-rc.5`, date `2026-11-19`, notes include “Packages now build with Node.js 24…” |
| spec | `Release: 7`, changelog through `-7` |
| VM Node | v24.18.0 (`/usr/bin/node → node-24`), npm 11.16.0, pnpm 11.28.5 (via `/usr/bin/pnpm` 10.33 wrapper) |
| Latest COPR build | `0.2.2.rc.5-7.fc45` (builds `11359299`, `11359805`, both succeeded) |
| Latest release | `v0.2.2-rc.5` published; assets: AppImage `372,730,829`, `latest-linux.yml`, SRPM `…rc.5-7…src.rpm` `262,852,069` |
| VM `dist/` | artifacts from the last local build are `0.2.2.rc.5-5` (built on Node 24, before the Release 6/7 bumps); a new build now produces `-7` |

Last relevant commits: `0a7c147` (appdata/Release 7), `5b59cc4` (Release 6), `109bae1` (toolchain nodejs24), `a069b4d` (copr gh `-R` fix), `db9b9c1` (repin rc.5).

---

## TL;DR — the seven steps

1. VM up → SSH → verify Node 24 / disk / pipeline copy.
2. Find latest successful build (GitHub + COPR + VM logs) and record its NVR/tag/commit.
3. Compare current `PIN` with upstream; decide next version; scan patch drift/relocations.
4. Update `PIN`, patches, appdata, spec/changelog, README/CI — on the workstation repo **and** mirrored to the VM.
5. Clean build on the VM (build → AppImage → SRPM → `rpmbuild --rebuild`) and check smoke tests / engine warning.
6. Commit + push + tag (new version = new tag; packaging-only = Release bump, no tag).
7. Monitor tag workflows, publish the draft release, clean stale assets, record outcome.

---

## 1. Log in to the VM and confirm the environment

- [ ] Start the VM if needed (from the workstation):

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system start 504356c1-7fdd-4648-b18a-98a3cc5ec092   # or: virsh start Workstation-deepseek
virsh -c qemu:///system domifaddr Workstation-deepseek --source lease
```

- [ ] Connect (always with `-F /dev/null` unless the ssh_config ownership was fixed):

```bash
ssh -F /dev/null jonathon@192.168.100.48
```

- [ ] Verify the machine and resources:

```bash
hostname                     # workstation-vm
cat /etc/fedora-release      # Fedora release 45
nproc                        # 2
free -h                      # ~7.6 GiB
df -h /home                  # need >= 8 GB free for a clean build
node --version               # v24.18.0
npm --version                # 11.16.0
pnpm --version               # 10.33.0 wrapper; resolves 11.28.5 from packageManager
rpm -q nodejs24 nodejs24-devel nodejs-packaging
```

- [ ] Verify the pipeline copy:

```bash
cd ~/pipeline
ls -la
cat PIN PIN_BASELINE
find source-patches -type f | wc -l     # 25 as of rc.5 (24 .patch + icon-linux.png)
find source-patches -type f | sort
ls scripts
```

- [ ] Confirm the VM is **not** a git repo (expected): `git status` → `fatal: not a git repository`.

- [ ] Compare the VM copy with GitHub (the VM keeps a few intentional local variants):

```bash
# On the workstation checkout
cd /var/home/jonathon/sirius-os-deepseek-harness
git fetch origin && git log --oneline -5 && git status --short

# Hash-compare the important trees
find source-patches packaging scripts -type f -print0 | sort -z | xargs -0 sha256sum > /tmp/local.sums
ssh -F /dev/null jonathon@192.168.100.48 'cd ~/pipeline && find source-patches packaging scripts -type f -print0 | sort -z | xargs -0 sha256sum' > /tmp/vm.sums
diff /tmp/local.sums /tmp/vm.sums
```

**Expected diffs / decisions:** the VM copy historically differs from GitHub in `Makefile`, `README.md`, `scripts/make-appimage.sh` (older local variants; the GitHub `make-appimage.sh` has the `unset GH_TOKEN` fix, GitHub `Makefile` no longer deletes `.build` at the start of `repin`). All build-critical scripts and all patches should match. Decide now: keep local variants and note them, or sync them from GitHub.

> Agent note: the workstation checkout is outside the DSH session workspace; editing/committing there needs `danger-full-access` approval. The VM writes go over SSH and are unaffected.

---

## 2. Review the pipeline and identify the latest successful build

- [ ] GitHub Actions and releases:

```bash
gh run list -R jonathonp3/sirius-os-deepseek-harness --limit 10
gh release list -R jonathonp3/sirius-os-deepseek-harness --limit 5
gh release view v0.2.2-rc.5 -R jonathonp3/sirius-os-deepseek-harness \
  --json isDraft,tagName,assets -q '"draft=\(.isDraft)", (.assets[] | "\(.name) \(.size)")'
```

- [ ] COPR latest builds:

```bash
curl -fsSL "https://copr.fedorainfracloud.org/api_3/build/list?ownername=jonathonp3&projectname=sirius-os&limit=5" \
  | python3 -c 'import json,sys; [print(b["id"], b["source_package"]["version"], b["state"]) for b in json.load(sys.stdin)["items"]]'
```

- [ ] VM last local build:

```bash
ls -lh ~/pipeline/dist
ls -lh ~/rpmbuild/RPMS/x86_64/ | tail -5
rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}\n' ~/pipeline/dist/*.src.rpm
grep -hE "CORE_RC|APPIMAGE_RC|SRPM_RC|RPMBUILD_RC" ~/pipeline/*.log | tail -20
```

- [ ] Record a baseline row somewhere (issue, notes, this file):

| NVR | Tag | Commit | Date | Node | Engine warnings | Release/asset URL |
|---|---|---|---|---|---|---|
| `0.2.2.rc.5-7.fc45` | `v0.2.2-rc.5` | `0a7c147` | 2026-11-19 | 24.18.0 | 0 | release published |

**Logs kept on the VM:** `~/pipeline/node24-build-2026-11-19.log` (Node 24 clean build), `build-2026-11-19.log`, `repin-build-2026-11-19.log`, `rc5-pack-2026-11-19.log`, `rc5-rpmbuild-2026-11-19.log`, `rpm-rebuild-2026-11-19.log`.

---

## 3. Compare the pin with the version planned for the next release

- [ ] List upstream releases and master:

```bash
git ls-remote --tags https://github.com/deepseek-ai/deepseek-harness.git | tail -25
git ls-remote https://github.com/deepseek-ai/deepseek-harness.git HEAD refs/heads/master
```

- [ ] In the VM clone, inspect candidates:

```bash
cd ~/pipeline/.build/deepseek-harness
git fetch --tags origin
git log -1 --format='%H %ci %s' <CANDIDATE_SHA>
git describe --tags <CANDIDATE_SHA>
git show <CANDIDATE_SHA>:apps/desktop/package.json | grep '"version"'
git show <CANDIDATE_SHA>:package.json | grep -A3 '"engines"'
```

**Decision — what to pin:**

1. Identify the newest upstream release tag (`dsh-vX.Y.Z…`).
2. Find the **master-sync merge** after it (`git log --oneline -5 origin/master`, look for “sync release … to master”). That merge is the pin (this matches the existing convention).
3. Confirm `apps/desktop/package.json` version at that commit.
4. If `engines.node` changed (e.g. `>=26.9`), plan the Node bump too (see §4/§8).

- [ ] Quick patch-impact scan (no clones, uses the existing clone):

```bash
cd ~/pipeline
OLD=$(cat PIN_BASELINE); NEW=<CANDIDATE_SHA>
cd .build/deepseek-harness && git checkout "$NEW"
cd ~/pipeline
./scripts/linux-build-patch.sh --check .build/deepseek-harness
```

This dry-runs every patch; it reports `clean`/`CONFLICT` but cannot tell you that an upstream file was **deleted** (a create-style or delete-style patch still reports “clean” in some cases) — do the per-file check below.

- [ ] Per-file upstream impact (catches deleted or relocated patch targets):

```bash
cd ~/pipeline/.build/deepseek-harness
for f in $(cd ~/pipeline/source-patches && find . -name '*.patch' \
           | sed 's|^\./||; s|\.patch$||' | sort); do
  n=$(git diff --numstat "$OLD" "$NEW" -- "$f")
  echo "$f ${n:-unchanged}"
done
```

Interpretation:
- `unchanged` → patch should apply as-is.
- `N+ M-` → upstream changed the file; regenerate/merge.
- `0+ N-` → **file deleted upstream**; drop the patch or retarget its intent to the replacement module (find it with `git grep <symbol> "$NEW"`).
- A moved module shows `unchanged` at the old path **and** a new file elsewhere — search for the imported package/symbol at `$NEW`.

- [ ] Optional full drift report (clones baseline + new into `.build/baseline-<pin12>/`, needs ~6–8 GB):

```bash
cd ~/pipeline
echo "$NEW" > PIN
echo "$OLD" > PIN_BASELINE
./scripts/check-drift.sh
```

- [ ] Produce the change list before editing:

```text
[ ] PIN / PIN_BASELINE
[ ] Patches to move/drop/regenerate (list them)
[ ] appdata release entry (version/date/notes)
[ ] spec Release + changelog
[ ] README / docs updates
[ ] CI node-version + toolchain nodejs<major> (if engine changed)
[ ] New tag name: v<upstream version>
```

---

## 4. Update the pipeline spec, appdata, documentation and patches

**Where to edit:** the workstation git checkout `/var/home/jonathon/sirius-os-deepseek-harness` is the source of truth. Edit there, then mirror to the VM. (Editing on the VM directly works for tests but leaves GitHub behind.)

### 4.1 Pin files

```bash
cd /var/home/jonathon/sirius-os-deepseek-harness
printf '%s\n' "<NEW_PIN>" > PIN
printf '%s\n' "<OLD_PIN>" > PIN_BASELINE     # temporary until the repin is validated
```

Set both to `<NEW_PIN>` only after a successful build; commit them together with the patches.

### 4.2 Patches

Paths mirror the upstream tree. For a relocated module:

```bash
OLD_PATH=apps/desktop/scripts/foo.ts          # old patch location
NEW_PATH=apps/desktop-publisher/src/foo.ts    # new upstream location

git rm "source-patches/$OLD_PATH.patch"
mkdir -p "source-patches/$(dirname "$NEW_PATH")"
diff -u --label "a/$NEW_PATH" --label "b/$NEW_PATH" \
  <(git -C .build/deepseek-harness show "<NEW_PIN>:$NEW_PATH") \
  ".build/deepseek-harness/$NEW_PATH" > "source-patches/$NEW_PATH.patch"
```

For a deleted upstream file: remove the patch (and its documentation note). For a simple changed file: apply with merge markers in the clone (`patch -p1 --merge`), resolve, then regenerate the patch the same way. Verify with:

```bash
./scripts/linux-build-patch.sh --check .build/deepseek-harness   # after checkout at NEW_PIN
```

### 4.3 appdata — `packaging/org.jonathonp3.deepseek-harness.appdata.xml`

- [ ] Add **one** `<release version="<UPSTREAM_VERSION>" date="<YYYY-MM-DD>">` at the top of `<releases>`; describe the re-pin and any packaging/toolchain changes (Node version, patch moves/drops).
- [ ] Never add a second `<release>` with the same version — AppStream releases are keyed by version. For packaging-only changes, extend the existing entry's notes instead.
- [ ] Validate:

```bash
appstreamcli validate --no-net packaging/org.jonathonp3.deepseek-harness.appdata.xml
```

### 4.4 spec — `packaging/sirius-os-deepseek-harness.spec`

- [ ] `Release:` → increment (new upstream version may continue the sequence; current is `7`).
- [ ] Add a `%changelog` entry at the top, format `* Thu Nov 19 2026 Name <email> - %{version}-<release>`, with bullets for the re-pin, patch moves/drops, appdata update and any Node change.
- [ ] Do not touch `Version:` — it is `%{_dsh_rpm_version}` derived from `@DSH_VERSION@`, replaced at SRPM build time.
- [ ] Validate (on the VM, which has `rpmspec`):

```bash
sed 's|@DSH_VERSION@|<UPSTREAM_VERSION>|g' packaging/sirius-os-deepseek-harness.spec > /tmp/t.spec
rpmspec -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' /tmp/t.spec
```

### 4.5 Documentation

- [ ] `README.md`: tag/version examples, re-pin notes, any change to patch locations or toolchain requirements.
- [ ] `scripts/toolchain.sh`: if the Node major changed, update the package names **and the explanatory comment**. Keep the comment **outside** the backslash-continued `dnf install` line — a `#` comment inside a continuation terminates the command (the following line would execute as a new command).
- [ ] `.github/workflows/release.yml`: `node-version:` for the AppImage job (currently `24`).
- [ ] `.github/workflows/copr.yml`: uses the container's Node via `toolchain.sh`; no node pin there.
- [ ] Remember the **two places**: the workstation repo and the VM copy. README/Makefile on the VM intentionally differ; decide whether to sync them.

### 4.6 Mirror to the VM (exact destination paths!)

```bash
cd /var/home/jonathon/sirius-os-deepseek-harness
for f in PIN PIN_BASELINE \
         packaging/sirius-os-deepseek-harness.spec \
         packaging/org.jonathonp3.deepseek-harness.appdata.xml \
         scripts/toolchain.sh \
         .github/workflows/release.yml; do
  [ -f "$f" ] && scp -F /dev/null "$f" "jonathon@192.168.100.48:/home/jonathon/pipeline/$f"
done
# patches: copy the whole tree (preserves structure)
scp -F /dev/null -r source-patches jonathon@192.168.100.48:/home/jonathon/pipeline/
```

**Gotcha:** `scp file1 file2 host:~/pipeline/` puts *both* files in `~/pipeline/`, not in their subdirectories. Always give the full destination path per file.

- [ ] Verify the mirror:

```bash
ssh -F /dev/null jonathon@192.168.100.48 \
  'cd ~/pipeline && grep -m1 "^Release:" packaging/sirius-os-deepseek-harness.spec && cat PIN PIN_BASELINE && find source-patches -type f | wc -l'
```

---

## 5. Review and test the changes on the VM

- [ ] Clean build (this deletes `.build/` and `dist/`; takes ~26 min on 2 vCPU; needs ~8 GB free):

```bash
cd ~/pipeline
LOG=~/pipeline/next-build-$(date +%Y-%m-%d).log
EXIT=~/pipeline/next-build.exit
{
  echo "START $(date -Is) node=$(node --version) npm=$(npm --version) pin=$(cat PIN)"
  make clean
  make build;    echo "CORE_RC=$?"
  make appimage; echo "APPIMAGE_RC=$?"
  make srpm;     echo "SRPM_RC=$?"
  rpmbuild --rebuild dist/*.src.rpm; echo "RPMBUILD_RC=$?"
  echo "END $(date -Is)"
} 2>&1 | tee "$LOG"
# run it detached for long builds:  setsid nohup bash -c '...' </dev/null >/dev/null 2>&1 &
```

Note: `make appimage` re-packages the payload; `make srpm` re-creates its own Source0 tarball (the separate `make tarball` target is optional).

- [ ] Acceptance checks:

```bash
# 1. Patches applied
grep -E "done: .* applied, .* failed" "$LOG"

# 2. Engine warning must be absent
grep -c "Unsupported engine" "$LOG"          # expected: 0

# 3. Smoke suite
grep -E "office versions|document round trips|CLI offline plugin|dsh web: http|DOCX, XLSX, PPTX" "$LOG"

# 4. Appdata
appstreamcli validate --no-net packaging/org.jonathonp3.deepseek-harness.appdata.xml

# 5. Spec / NVR
sed 's|@DSH_VERSION@|'"$(grep -oP '\"version\":\s*\"\K[^\"]+' .build/deepseek-harness/apps/desktop/package.json | head -1)"'|g' \
  packaging/sirius-os-deepseek-harness.spec > /tmp/t.spec
rpmspec -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' /tmp/t.spec

# 6. SRPM + binary RPM
rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}\n' dist/*.src.rpm
rpm -qpl ~/rpmbuild/RPMS/x86_64/*.x86_64.rpm | grep -E '^/usr/(bin|share)'
rpm2cpio dist/*.src.rpm | cpio -i --to-stdout ./org.jonathonp3.deepseek-harness.appdata.xml 2>/dev/null | grep -m1 'release version'

# 7. AppImage version (extract, no FUSE needed)
TMP=$(mktemp -d); (cd "$TMP" && ~/pipeline/dist/*.AppImage --appimage-extract >/dev/null 2>&1)
grep -a -o -m1 '"version": *"[^"]*"' "$TMP/squashfs-root/resources/app.asar"; rm -rf "$TMP"
```

- [ ] Record: CORE_RC, APPIMAGE_RC, SRPM_RC, RPMBUILD_RC, NVR, Node version, engine-warning count, smoke result, timings, disk used.

**Expected artifact sizes (rc.5, Fedora 45):** AppImage ~356 MB, SRPM ~250 MB, binary RPM ~259 MB, tarball ~284 MB. Payload ~1.4 GB.

---

## 6. Commit and push to GitHub (including the tag)

- [ ] Review the diff; never stage the untracked `deepseek-harness.png`:

```bash
cd /var/home/jonathon/sirius-os-deepseek-harness
git status --short
git diff          # PIN, patches, appdata, spec, docs, CI
git diff --check
```

- [ ] Commit (split logical changes; example for a re-pin):

```bash
git add PIN PIN_BASELINE source-patches packaging README.md .github scripts
git commit -m "repin to <NEW_PIN> (<VERSION>)" -m "- PIN/PIN_BASELINE -> <NEW_PIN>
- move/regenerate/drop patches: <details>
- appdata/spec: <VERSION>, Release <N>
- docs/CI: <details>"
```

- [ ] Push (the SSH config workaround is also needed for git):

```bash
GIT_SSH_COMMAND="ssh -F /dev/null" git push origin main
```

- [ ] Tag **only** for a real release, and only after CI passes locally/VM; tag must be `v${VERSION}` (CI verifies against `apps/desktop/package.json` at `PIN`):

```bash
git tag v<VERSION>
git push origin v<VERSION>
```

- [ ] **Toolchain/packaging-only change (no upstream version change):** bump `Release:` and push `main`; do **not** create a tag. Rebuild COPR with `gh workflow run copr.yml --ref main`.
- [ ] **Never create a tag like `v0.2.2-rc.5-7`** — the CI version check requires `v<package.json version>` exactly.
- [ ] If you must move an existing tag (e.g. it points at an older commit): `git tag -f v<VERSION> <sha> && git push -f origin v<VERSION>`. Caveats: rewrites the published tag, re-triggers both workflows, creates duplicate COPR builds, and the AppImage will **not** re-upload to an already-published release (see §8).

---

## 7. Run the build and monitor it

### 7.1 Trigger

- Tag push (`v*`) → `Release` (AppImage) **and** `COPR SRPM` run automatically.
- COPR-only / no tag → `gh workflow run copr.yml -R jonathonp3/sirius-os-deepseek-harness --ref main`.

### 7.2 Monitor

```bash
gh run list -R jonathonp3/sirius-os-deepseek-harness --limit 5
gh run watch <RUN_ID> -R jonathonp3/sirius-os-deepseek-harness --exit-status
gh run view <RUN_ID> -R jonathonp3/sirius-os-deepseek-harness --log > /tmp/run.log

grep -c "Unsupported engine" /tmp/run.log            # 0
grep -c "nodejs24" /tmp/run.log                      # > 0
grep -o "sirius-os-deepseek-harness-[^ ]*\.src\.rpm" /tmp/run.log | sort -u
grep -E "Process completed with exit code|##\[error\]" /tmp/run.log | head
```

If `gh run view --log` fails with a read-only cache (agent sandbox), set `XDG_CACHE_HOME` to a writable dir.

COPR:

```bash
curl -fsSL "https://copr.fedorainfracloud.org/api_3/build/list?ownername=jonathonp3&projectname=sirius-os&limit=3" \
  | python3 -c 'import json,sys; [print(b["id"], b["source_package"]["version"], b["state"]) for b in json.load(sys.stdin)["items"]]'
```

### 7.3 Release handling

- `release.yml` → electron-builder creates/updates a **draft** release and uploads the AppImage + `latest-linux.yml` (only with `PUBLISH=always`, i.e. in CI).
- `copr.yml` (tag only) → submits the SRPM to COPR and uploads it to the release (creates a draft if missing).
- Publish the draft (if it is not already published):

```bash
gh release edit v<VERSION> -R jonathonp3/sirius-os-deepseek-harness \
  --draft=false --title "v<VERSION>" --notes "- Re-pin to <sha> (<version>)
- <patch moves/drops>
- SRPM: <NVR> (also on COPR)"
```

- Verify:

```bash
gh release view v<VERSION> -R jonathonp3/sirius-os-deepseek-harness \
  --json isDraft,assets -q '"draft=\(.isDraft)", (.assets[] | "\(.name) \(.size)")'
gh release download v<VERSION> -R jonathonp3/sirius-os-deepseek-harness -p latest-linux.yml -O -
```

- Clean stale assets (each NVR creates a new SRPM filename; old ones stay):

```bash
gh release delete-asset v<VERSION> <old>.src.rpm -R jonathonp3/sirius-os-deepseek-harness --yes
```

- [ ] Record outcome (write it next to the baseline table): run URLs, COPR build IDs, release URL, asset list, engine-warning count, smoke result, and follow-ups (e.g. AppImage not re-uploaded, duplicate COPR builds, VM/pipeline drift).

---

## 8. Gotchas, decisions and failure modes

1. **SSH config ownership** — always `ssh -F /dev/null` / `scp -F /dev/null`, or fix `/etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf` ownership on the workstation.
2. **VM sudo** — password required; temporary `NOPASSWD` file is the automation-friendly path; remove it when done (it lives at `/etc/sudoers.d/jonathon-nopasswd`, mode `440`).
3. **Node package split (Fedora)** — `nodejs<major>` meta, `nodejs<major>-bin` owns `/usr/bin/node` via alternatives, `nodejs<major>-npm`/`-npm-bin` own `/usr/bin/npm`, `-devel` for headers. Swap with `--allowerasing` because `<old>-npm-bin` requires `<old>-bin` exactly:
   `sudo dnf swap nodejs22-bin nodejs24-bin --allowerasing -y; sudo dnf install -y nodejs24-devel; sudo dnf remove -y nodejs22 nodejs22-devel nodejs22-docs nodejs22-full-i18n nodejs22-libs nodejs22-npm`.
   Removing `nodejs22-devel` also removes its devel deps (`openssl-devel`, `zlib-ng-compat-devel`, `libuv-devel`, `brotli-devel`, `nodejs-packaging`, `nodejs-corepack`); installing `nodejs<major>-devel` restores them except `corepack` (not needed; pnpm is a global npm install).
4. **Pin policy** — pin the master-sync merge, not the `dsh-v*` tag. Verify the version in `apps/desktop/package.json` and the `engines.node` requirement.
5. **Patch relocations/deletions** — upstream moved `apps/desktop/scripts/desktop-*publisher*` modules to `apps/desktop-publisher/src/` during rc.5. Use `git grep` at the new pin to find replacements; move the patch, regenerate with `diff -u --label a/… --label b/…`.
6. **Comment placement in `toolchain.sh`** — never put a `#` comment inside the backslash-continued `dnf install` argument list; it terminates the logical line and the next line runs as a command. Put comments above the command (already fixed for nodejs24).
7. **appdata** — one release entry per version; validate with `appstreamcli`; packaging-only changes extend existing notes and bump `Release`, they do not add a duplicate version.
8. **spec** — `Version` is templated (`@DSH_VERSION@`); `Release` is the only manual version bump. Changelog date format `%a %b %d %Y` (e.g. `Thu Nov 19 2026`).
9. **Tag must match app version** — CI fails if tag ≠ `v` + `apps/desktop/package.json` version.
10. **electron-builder is draft-only** — publishing to an already-published release is skipped:
    `existing type not compatible with publishing type … existingType=release publishingType=draft`.
    To refresh a published release's AppImage: set it to draft, re-run the tag build, publish again — or upload manually with `gh release upload <tag> <file> --clobber`. The AppImage only contains the app payload, so if the commits since the last tag touched only packaging/toolchain/spec/docs, the existing AppImage is still valid.
11. **Tag re-runs duplicate COPR builds** — COPR accepts the same NVR twice; expect two build IDs. The workflow's upload uses `--clobber`, which only replaces same-named assets; old NVR SRPMs accumulate and must be deleted explicitly.
12. **`gh` inside the Fedora container** cannot resolve the repo from the container working directory — `copr.yml` passes `-R "${GITHUB_REPOSITORY}"` to `gh release view/create/upload`. Keep it.
13. **`scp` with multiple files** flattens them into the target directory; always specify full destination paths per file.
14. **VM pipeline is not git** — GitHub is the source of truth. Keep `PIN`, `source-patches/`, `packaging/`, `scripts/` mirrored. The VM's `Makefile`, `README.md`, `scripts/make-appimage.sh` are local variants; decide whether to sync them.
15. **`deepseek-harness.png`** is untracked in the workstation checkout; do not `git add -A`.
16. **RPM/AppImage locally** — `latest-linux.yml` is only produced with `PUBLISH=always` (CI). Local `PUBLISH=never` produces the AppImage without update metadata.
17. **Disk/time** — clean build ~26 min on 2 vCPU; `make clean` frees `.build` (~6 GB) and `dist` (~1.4 GB); keep ≥ 8 GB free.
18. **`make tarball` is optional** — `build-srpm.sh` creates its own `Source0` tarball. `make repin` on the VM's Makefile deletes the clone before rebuilding; the GitHub Makefile relies on `build-linux.sh` resetting it.
19. **AppImage smoke tests** run during packaging (`desktop runtime: … passed`, `dsh web: http://…`); treat their absence as a failure even if the build exits 0.
20. **Keep logs** — they are the only evidence of the RC values and smoke results for the next baseline.

---

## Appendix A — File map

```text
/var/home/jonathon/sirius-os-deepseek-harness/     # workstation git checkout (source of truth)
├── PIN, PIN_BASELINE
├── Makefile
├── README.md
├── packaging/
│   ├── sirius-os-deepseek-harness.spec
│   ├── org.jonathonp3.deepseek-harness.appdata.xml
│   ├── org.jonathonp3.deepseek-harness.desktop
│   ├── deepseek-harness.png
│   └── dsh
├── scripts/
│   ├── toolchain.sh, build-linux.sh, linux-build-patch.sh
│   ├── check-drift.sh, reconcile-patches.sh, convert-patches.sh
│   └── make-tarball.sh, make-appimage.sh, build-srpm.sh
├── source-patches/                                 # mirrors upstream paths
└── .github/workflows/{release.yml,copr.yml}

/home/jonathon/pipeline/                            # VM working copy (not git)
├── .build/deepseek-harness/                        # upstream clone at PIN (recreated by make build)
├── dist/                                           # linux-unpacked, tarball, AppImage, SRPM
├── packaging/, scripts/, source-patches/, PIN, PIN_BASELINE
└── *.log                                           # build logs

/home/jonathon/rpmbuild/RPMS/x86_64/                # binary RPM from rpmbuild --rebuild
```

## Appendix B — Useful one-liners

```bash
# Upstream → pin version
git -C ~/pipeline/.build/deepseek-harness show <PIN>:apps/desktop/package.json | grep '"version"'

# Current tag target
git -C /var/home/jonathon/sirius-os-deepseek-harness rev-parse v0.2.2-rc.5

# COPR latest
curl -fsSL "https://copr.fedorainfracloud.org/api_3/build/list?ownername=jonathonp3&projectname=sirius-os&limit=3" | python3 -m json.tool | head -40

# Release assets
gh release view <tag> -R jonathonp3/sirius-os-deepseek-harness --json assets

# Check a built SRPM's embedded appdata/spec
rpm2cpio dist/*.src.rpm | cpio -i --to-stdout ./org.jonathonp3.deepseek-harness.appdata.xml | grep -m1 'release version'
rpm2cpio dist/*.src.rpm | cpio -i --to-stdout ./sirius-os-deepseek-harness.spec | grep -m1 '^Release:'
```

## Appendix C — Changelog/appdata wording template

```text
- Re-pin to upstream <sha> (<version>).
- <Move/drop/regenerate> the <module> patches for upstream's relocation/removal.
- Update appdata release version to <version>.
- <Node/toolchain change, e.g. build with Node.js 24 (nodejs24); upstream requires >= 24.9.>
- <CI/docs updates.>
```

---

### Definition of done

- [ ] `PIN`/`PIN_BASELINE` point at the intended upstream commit and all patches apply.
- [ ] appdata + spec + README/CI updated in **both** the GitHub checkout and the VM copy.
- [ ] VM clean build: CORE/APPIMAGE/SRPM/RPMBUILD all `0`; engine warning count `0`; smoke suite passed.
- [ ] Commit(s) pushed; tag pushed only for a version release; no stray untracked files committed.
- [ ] Both tag workflows green; release published (or intentionally left draft); assets correct; stale SRPMs removed.
- [ ] Outcome recorded (NVR, tag, commit, run URLs, COPR build IDs, follow-ups).

---

### Maintenance

After each build, refresh **§0 Current state snapshot** (commit, tag target, PIN, version/Release, NVR, COPR build IDs, release assets) and add any new gotcha to §8. Keep a copy of this file on the VM (`~/pipeline/NEXT-BUILD-CHECKLIST.md`) and in the repo (`docs/NEXT-BUILD.md`) so the next run does not depend on chat history.

