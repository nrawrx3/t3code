# Built by build.sh, which passes every t3_* macro. Wraps the unpacked Electron app the way
# packaging/aur wraps the AppImage.

%global debug_package %{nil}
%global _build_id_links none
# Ship Electron's prebuilt binaries untouched: no stripping, shebang mangling, or rpath checks.
%global __os_install_post %{nil}
# Bundled libraries (libffmpeg, node addons) are private to the app; keep them out of dnf's solver.
%global __provides_exclude_from ^/opt/t3code/.*$
%global __requires_exclude_from ^/opt/t3code/.*$

Name:           t3code
Version:        %{t3_version}
Release:        %{t3_release}%{?dist}
Summary:        Desktop GUI for coding agents
License:        MIT
URL:            %{t3_url}
ExclusiveArch:  x86_64

Requires:       alsa-lib
Requires:       at-spi2-core
Requires:       gtk3
Requires:       hicolor-icon-theme
Requires:       libnotify
Requires:       libsecret
Requires:       libuuid
Requires:       libXScrnSaver
Requires:       libXtst
Requires:       mesa-libgbm
Requires:       nss
Requires:       xdg-utils

%description
T3 Code desktop, built locally from commit %{t3_commit}.

%install
install -d %{buildroot}/opt/t3code
cp -a %{t3_app}/. %{buildroot}/opt/t3code/
chmod -R u=rwX,go=rX %{buildroot}/opt/t3code
chmod 4755 %{buildroot}/opt/t3code/chrome-sandbox

install -d %{buildroot}%{_bindir}
ln -s /opt/t3code/t3code %{buildroot}%{_bindir}/t3code

install -d %{buildroot}%{_datadir}/icons/hicolor
cp -a %{t3_icons}/. %{buildroot}%{_datadir}/icons/hicolor/

install -Dm644 %{t3_root}/packaging/rpm/t3code.desktop %{buildroot}%{_datadir}/applications/t3code.desktop
install -Dm644 %{t3_root}/apps/desktop/resources/linux/com.t3tools.t3code.metainfo.xml \
  %{buildroot}%{_metainfodir}/com.t3tools.t3code.metainfo.xml
install -Dm644 %{t3_root}/LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%files
/opt/t3code/
%{_bindir}/t3code
%{_datadir}/applications/t3code.desktop
%{_datadir}/icons/hicolor/*/apps/t3code.png
%{_metainfodir}/com.t3tools.t3code.metainfo.xml
%{_datadir}/licenses/%{name}/
