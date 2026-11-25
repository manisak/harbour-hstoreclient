Name:       harbour-hstoreclient
Summary:    Harpoon Store client for SailfishOS
Version:    0.3.5
Release:    1
Group:      Applications/Internet
License:    MIT
URL:        https://harpoon-store.manisak.com
Source0:    %{name}-%{version}.tar.bz2
BuildArch:  noarch

Requires:   libsailfishapp-launcher
Requires:   sailfishsilica-qt5
# BuildRequires are intentionally omitted — this spec is built on a plain
# Ubuntu runner with rpmbuild (no SailfishOS SDK), so desktop-file-utils
# is installed via apt and called directly, not through rpmbuild dep checks.

%description
Harpoon Store client: browse the community app index at
https://harpoon-store.manisak.com — view developer profiles,
contributors, screenshots and comments — and install apps with a
single tap: this client opens Harpoon pre-filled with the app's
repository URL.

Pure-QML Sailfish Silica app launched via `sailfish-qml`.

%prep
%setup -q

%build
# nothing to compile — pure QML

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_datadir}/%{name}/qml
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/86x86/apps
cp qml/%{name}.qml %{buildroot}%{_datadir}/%{name}/qml/
cp %{name}.desktop %{buildroot}%{_datadir}/applications/
cp icons/86x86/%{name}.png %{buildroot}%{_datadir}/icons/hicolor/86x86/apps/
desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/applications/%{name}.desktop

%files
%defattr(-,root,root,-)
%{_datadir}/%{name}/qml/%{name}.qml
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/86x86/apps/%{name}.png

%changelog
* Wed Nov 25 2026 manisak <manisak@users.noreply.github.com> 0.3.0-1
- Full Silica redesign: Theme colours, SearchField, PullDownMenu,
  BackgroundItem list rows, hero headers with app icon, install CTA,
  developer profile page, contributors chips, screenshot carousel,
  comments, more-from-developer list, about overlay.
- Switch to pure-QML sailfish-qml launcher (drops C++ binary).
- Adds API integration with new endpoints /api/app/:id.json and
  /api/developer/:username.json.

* Tue Nov 24 2026 manisak <manisak@users.noreply.github.com> 0.2.0-1
- First release
