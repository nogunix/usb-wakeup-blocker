Name:           usb-wakeup-blocker
Version:        1.1.0
Release:        1%{?dist}
Summary:        A script and systemd service to precisely control which devices can wake a Linux system from sleep.
License:        MIT
URL:            https://github.com/nogunix/usb-wakeup-blocker
Source0:        https://github.com/nogunix/usb-wakeup-blocker/archive/refs/tags/v%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  systemd-rpm-macros
Requires:       usbutils
Requires:       systemd

%description
A script and systemd service to precisely control which devices can wake a Linux system from sleep.

%prep
%setup -q

%build
# Since it's a shell script, compilation is not necessary.

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 bin/usb-wakeup-blocker.sh %{buildroot}%{_bindir}/usb-wakeup-blocker.sh

mkdir -p %{buildroot}%{_sysconfdir}
install -m 0644 etc/usb-wakeup-blocker.conf %{buildroot}%{_sysconfdir}/usb-wakeup-blocker.conf

mkdir -p %{buildroot}%{_udevrulesdir}
install -m 0644 udev/99-usb-wakeup-blocker.rules %{buildroot}%{_udevrulesdir}/99-usb-wakeup-blocker.rules

mkdir -p %{buildroot}%{_unitdir}
install -m 0644 systemd/usb-wakeup-blocker.service %{buildroot}%{_unitdir}/usb-wakeup-blocker.service

mkdir -p %{buildroot}%{_datadir}/bash-completion/completions
install -m 0644 completions/bash/usb-wakeup-blocker %{buildroot}%{_datadir}/bash-completion/completions/usb-wakeup-blocker

mkdir -p %{buildroot}%{_datadir}/zsh/site-functions
install -m 0644 completions/zsh/_usb-wakeup-blocker %{buildroot}%{_datadir}/zsh/site-functions/_usb-wakeup-blocker

%post
%systemd_post usb-wakeup-blocker.service
udevadm control --reload-rules && udevadm trigger --subsystem-match=usb || :

%preun
%systemd_preun usb-wakeup-blocker.service

%postun
%systemd_postun_with_restart usb-wakeup-blocker.service
udevadm control --reload-rules || :

%files
%doc README.md LICENSE
%{_bindir}/usb-wakeup-blocker.sh
%config(noreplace) %{_sysconfdir}/usb-wakeup-blocker.conf
%{_udevrulesdir}/99-usb-wakeup-blocker.rules
%{_unitdir}/usb-wakeup-blocker.service
%{_datadir}/bash-completion/completions/usb-wakeup-blocker
%{_datadir}/zsh/site-functions/_usb-wakeup-blocker

%changelog
* Sun May 10 2026 Nogunix <nogunix@gmail.com> - 1.1.0-1
- Add udev rule for hotplug support
- Use sysfs for faster device detection
- Add -p/--path and -l/--list options
- Improve test coverage and isolation

* Wed Apr 29 2026 Nogunix <nogunix@gmail.com> - 1.0.3-1
- Support Fedora 44
- Improve spec file for Fedora standards
- Add systemd scriptlets and proper dependencies
- Use standard macros for directories
