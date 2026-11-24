%if 0%{?__position_plugin_template_priority:0}
%error Build fails under SailfishOS
%endif

Name:       harbour-hstoreclient
Summary:    Harpoon Store client for SailfishOS
Version:    0.2.0
Release:    1
Group:      Applications/Internet
License:    MIT
URL:        https://harpoon-store.manisak.com
Source0:    %{name}-%{version}.tar.bz2
Requires:   libsailfishapp >= 0.0.10
BuildRequires: pkgconfig(sailfishapp) >= 1.0.2
BuildRequires: pkgconfig(Qt5Core)
BuildRequires: pkgconfig(Qt5Qml)
BuildRequires: pkgconfig(Qt5Quick)
BuildRequires: desktop-file-utils

%{!?qtc_qmake:%define qtc_qmake %qmake}
%{!?qtc_make:%define qtc_make make}
%{?qtc_builddir:%define _builddir %qtc_builddir}

%description
Harpoon Store client: browse the community app list at
https://harpoon-store.manisak.com and install apps with a single
tap: this client opens Harpoon pre-filled with the app's repository URL.

%prep
%setup -q

%build
%qtc_qmake5

%qtc_make%{?_smp_mflags: %{?_smp_mflags}}

%install
rm -rf %{buildroot}
%qmake5_install

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}/qml/*.qml
%{_datadir}/%{name}/qml/pages/*.qml
%{_datadir}/%{name}/translations/*.qm
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/86x86/apps/%{name}.png

%changelog
* Tue Nov 24 2026 manisak <manisak@users.noreply.github.com> 0.2.0-1
- First release
