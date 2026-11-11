%global debug_package %{nil}
%undefine __brp_mangle_shebangs

# Replaced at SRPM build time by scripts/build-srpm.sh
%global _dsh_version @DSH_VERSION@
%define _dsh_rpm_version %(echo %{_dsh_version} | tr '-' '.')

Name:           sirius-os-deepseek-harness
Version:        %{_dsh_rpm_version}
Release:        4%{?dist}
Summary:        Agent harness workspace
License:        MIT
URL:            https://github.com/jonathonp3/sirius-os-deepseek-harness
BuildArch:      x86_64
# The payload is self-contained: bundled libraries (libc.musl,
# libonnxruntime, libjpeg, libpng, libtiff, liblzma, libgfortran,
# libquadmath) ship inside /usr/libexec/deepseek-harness/ and are
# not available as Fedora packages. Disable auto-requires/provides
# so elfdeps does not record them as package Requires, and declare
# the real system deps explicitly.
AutoReqProv:    no
Requires:       glibc >= 2.39
Requires:       gtk3
Requires:       nss
Requires:       nspr
Requires:       libX11
Requires:       libXcomposite
Requires:       libXdamage
Requires:       libXext
Requires:       libXfixes
Requires:       libXrandr
Requires:       libxcb
Requires:       libxkbcommon
Requires:       pango
Requires:       cairo
Requires:       alsa-lib
Requires:       libdrm
Requires:       mesa-libgbm
Requires:       atk
Requires:       at-spi2-atk
Requires:       cups-libs
Requires:       expat
Requires:       dbus-libs
Requires:       systemd-libs
BuildRequires:  patchelf

Source0:        deepseek-harness-%{_dsh_version}-linux-x64.tar.xz
Source1:        org.jonathonp3.deepseek-harness.desktop
Source2:        deepseek-harness.png
Source3:        org.jonathonp3.deepseek-harness.appdata.xml
Source4:        dsh

%description
DeepSeek Harness workspace, packaged for Fedora.

The app is self-contained: Electron, the dsh runtime, Node, pnpm, Python,
and the WASM engines (sharp, LibreOffice) are all bundled in the payload
at /usr/libexec/deepseek-harness/. No system services, no state in /var/,
no first-boot provisioning.

%prep
%setup -q -c -T

%build
# Nothing to build; the tarball is the payload.

%install
# 1. Extract the tarball's linux-unpacked/ into /usr/libexec/deepseek-harness/
mkdir -p %{buildroot}%{_libexecdir}/deepseek-harness
tar -xJf %{SOURCE0} --strip-components=1 \
    -C %{buildroot}%{_libexecdir}/deepseek-harness/

# 2. Strip invalid RPATHs from pre-built upstream binaries.
find %{buildroot}%{_libexecdir}/deepseek-harness -type f \( -name '*.so*' -o -name '*.node' \) \
  -exec patchelf --remove-rpath {} \; 2>/dev/null || :

# 3. Symlink the binary into /usr/bin/
mkdir -p %{buildroot}%{_bindir}
ln -s ../libexec/deepseek-harness/deepseek-harness \
      %{buildroot}%{_bindir}/deepseek-harness

# 4. Desktop entry, icon, and appdata
install -Dpm0644 %{SOURCE1} \
    %{buildroot}%{_datadir}/applications/org.jonathonp3.deepseek-harness.desktop
install -Dpm0644 %{SOURCE2} \
    %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/deepseek-harness.png
install -Dpm0644 %{SOURCE3} \
    %{buildroot}%{_datadir}/metainfo/org.jonathonp3.deepseek-harness.appdata.xml

# 5. CLI launcher (upstream's is macOS-only and 0644; we ship our own)
install -Dpm0755 %{SOURCE4} %{buildroot}%{_bindir}/dsh


%post
update-desktop-database -q %{_datadir}/applications 2>/dev/null || :
gtk-update-icon-cache -q %{_datadir}/icons/hicolor 2>/dev/null || :
appstreamcli refresh-cache --force 2>/dev/null || :

%postun
update-desktop-database -q %{_datadir}/applications 2>/dev/null || :
gtk-update-icon-cache -q %{_datadir}/icons/hicolor 2>/dev/null || :
appstreamcli refresh-cache --force 2>/dev/null || :

%files
%{_libexecdir}/deepseek-harness/
%{_bindir}/deepseek-harness
%{_bindir}/dsh
%{_datadir}/applications/org.jonathonp3.deepseek-harness.desktop
%{_datadir}/icons/hicolor/512x512/apps/deepseek-harness.png
%{_datadir}/metainfo/org.jonathonp3.deepseek-harness.appdata.xml

%changelog
* Wed Nov 11 2026 Jonathon P <jonathon@sirius-os> - %{version}-4
- Resize icon to 512x512 to match the hicolor/512x512/apps install
  path (was 1104x1104, which violates the icon theme spec).
- Update appdata release version to 0.2.2-rc.1.
- Correct the -2 changelog note: dsh headless works (the bundle is in
  the asar); only dsh tui is unavailable, because its profile template
  ships with the npm @deepseek-ai/dsh package, not the desktop tarball.


* Tue Nov 10 2026 Jonathon P <jonathon@sirius-os> - %{version}-3
- Add AutoReqProv: no and explicit runtime Requires. Without the
  exclusion macros, RPM's elfdeps recorded bundled payload sonames
  (libc.musl, libonnxruntime, libjpeg, libpng, libtiff, liblzma,
  libgfortran, libquadmath) as package Requires, making the package
  uninstallable on Fedora. Declare the real system deps explicitly.

* Tue Nov 10 2026 Jonathon P <jonathon@sirius-os> - %{version}-2
- Add Linux CLI launcher at /usr/bin/dsh (upstream's is a macOS
  artifact: mode 0644, execs ../MacOS/DeepSeek Harness). New launcher
  resolves the app root via symlink and execs the desktop host CLI
  with ELECTRON_RUN_AS_NODE=1.
- Note: dsh tui is unavailable — its profile template ships in the
  npm @deepseek-ai/dsh package, not the desktop tarball. dsh headless
  works (the bundle is present; it reads DEEPSEEK_API_KEY from env).

* Fri Nov 06 2026 Jonathon P <jonathon@sirius-os> - %{version}-1
- Initial package. Self-contained payload at /usr/libexec/deepseek-harness/,
  symlink at /usr/bin/deepseek-harness, reverse-DNS desktop entry,
  appdata for software centers.
- No systemd units, no first-boot provisioning, no /var state.
