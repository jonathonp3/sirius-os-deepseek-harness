%global debug_package %{nil}
%undefine __brp_mangle_shebangs
%global __requires_exclude_from ^/usr/libexec/deepseek-harness/
%global __provides_exclude_from ^/usr/libexec/deepseek-harness/

# Replaced at SRPM build time by scripts/build-srpm.sh
%global _dsh_version @DSH_VERSION@
%define _dsh_rpm_version %(echo %{_dsh_version} | tr '-' '.')

Name:           sirius-os-deepseek-harness
Version:        %{_dsh_rpm_version}
Release:        1%{?dist}
Summary:        Agent harness workspace
License:        MIT
URL:            https://github.com/jonathonp3/sirius-os-deepseek-harness
BuildArch:      x86_64
Requires:       glibc >= 2.39
BuildRequires:  patchelf

Source0:        deepseek-harness-%{_dsh_version}-linux-x64.tar.xz
Source1:        org.jonathonp3.deepseek-harness.desktop
Source2:        deepseek-harness.png
Source3:        org.jonathonp3.deepseek-harness.appdata.xml

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
%{_datadir}/applications/org.jonathonp3.deepseek-harness.desktop
%{_datadir}/icons/hicolor/512x512/apps/deepseek-harness.png
%{_datadir}/metainfo/org.jonathonp3.deepseek-harness.appdata.xml

%changelog
* Fri Nov 06 2026 Jonathon P <jonathon@sirius-os> - %{version}-1
- Initial package. Self-contained payload at /usr/libexec/deepseek-harness/,
  symlink at /usr/bin/deepseek-harness, reverse-DNS desktop entry,
  appdata for software centers.
- No systemd units, no first-boot provisioning, no /var state.
