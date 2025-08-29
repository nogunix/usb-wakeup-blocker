Name:           usb-wakeup-blocker
Version:        1.0.1
Release:        1%{?dist}
Summary:        A script and systemd service to precisely control which devices can wake a Linux system from sleep.
License:        MIT
URL:            https://github.com/nogunix/usb-wakeup-blocker
Source0:        https://github.com/nogunix/usb-wakeup-blocker/archive/refs/tags/v%{version}.tar.gz
BuildArch:      noarch

%description
A script and systemd service to precisely control which devices can wake a Linux system from sleep.

%prep
%setup -q

%build
# Since it's a shell script, compilation is not necessary.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 bin/usb-wakeup-blocker.sh %{buildroot}/usr/bin/usb-wakeup-blocker.sh

mkdir -p %{buildroot}/etc
install -m 0644 etc/usb-wakeup-blocker.conf %{buildroot}/etc/usb-wakeup-blocker.conf

mkdir -p %{buildroot}/usr/lib/systemd/system
install -m 0644 systemd/usb-wakeup-blocker.service %{buildroot}/usr/lib/systemd/system/usb-wakeup-blocker.service

%files
%doc README.md LICENSE
/usr/bin/usb-wakeup-blocker.sh
%config(noreplace) /etc/usb-wakeup-blocker.conf
/usr/lib/systemd/system/usb-wakeup-blocker.service

%changelog
* Tue Aug 26 2025 Nogunix <nogunix@gmail.com> - 1.0.1-1
- Update version to 1.0.1
* Mon Aug 25 2025 Nogunix <nogunix@gmail.com> - 1.0.0-1
- Initial package
