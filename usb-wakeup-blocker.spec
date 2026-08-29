Name:           usb-wakeup-blocker
Version:        1.1.2
Release:        1%{?dist}
Summary:        Control which USB devices may wake the system from sleep

License:        MIT
URL:            https://github.com/nogunix/usb-wakeup-blocker
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  systemd-rpm-macros
Requires:       usbutils
Requires:       systemd

%description
usb-wakeup-blocker disables USB remote wakeup for the devices you choose, so
that a nudged mouse or a stray USB signal no longer brings the machine out of
sleep. By default it blocks only mice; keyboards and every other device keep
their ability to wake the system.

A systemd unit applies the policy at boot and a udev rule applies it to devices
plugged in while the system is running.

%prep
%autosetup

# The command is installed without the .sh suffix, so point the unit and the
# udev rule at the real name rather than at the compatibility symlink.
sed -i 's|/usr/bin/%{name}\.sh|%{_bindir}/%{name}|' \
    systemd/%{name}.service udev/99-%{name}.rules

%build
# Nothing to compile: the payload is a shell script.

%install
install -Dpm 0755 bin/%{name}.sh %{buildroot}%{_bindir}/%{name}
# Kept so that anything referring to the old name still works.
ln -s %{name} %{buildroot}%{_bindir}/%{name}.sh

install -Dpm 0644 etc/%{name}.conf %{buildroot}%{_sysconfdir}/%{name}.conf
install -Dpm 0644 udev/99-%{name}.rules %{buildroot}%{_udevrulesdir}/99-%{name}.rules
install -Dpm 0644 systemd/%{name}.service %{buildroot}%{_unitdir}/%{name}.service
install -Dpm 0644 man/%{name}.1 %{buildroot}%{_mandir}/man1/%{name}.1
# Man page redirect for the compatibility symlink.
echo '.so man1/%{name}.1' > %{buildroot}%{_mandir}/man1/%{name}.sh.1
install -Dpm 0644 completions/bash/%{name} %{buildroot}%{_datadir}/bash-completion/completions/%{name}
install -Dpm 0644 completions/zsh/_%{name} %{buildroot}%{_datadir}/zsh/site-functions/_%{name}

%check
# The bats suite lives in git submodules that the release tarball does not
# carry, so check what the tarball does contain: the script parses and its
# usage path runs without touching any device.
bash -n bin/%{name}.sh
SKIP_ROOT_CHECK=1 bash bin/%{name}.sh -h > /dev/null

%post
%systemd_post %{name}.service
udevadm control --reload-rules && udevadm trigger --subsystem-match=usb || :

%preun
%systemd_preun %{name}.service

%postun
%systemd_postun_with_restart %{name}.service
udevadm control --reload-rules || :

%files
%license LICENSE
%doc README.md CHANGELOG.md
%{_bindir}/%{name}
%{_bindir}/%{name}.sh
%config(noreplace) %{_sysconfdir}/%{name}.conf
%{_udevrulesdir}/99-%{name}.rules
%{_unitdir}/%{name}.service
%{_mandir}/man1/%{name}.1*
%{_mandir}/man1/%{name}.sh.1*
%{_datadir}/bash-completion/completions/%{name}
%{_datadir}/zsh/site-functions/_%{name}

%changelog
* Sun Aug 30 2026 Nogunix <nogunix@gmail.com> - 1.1.2-1
- Install the command as usb-wakeup-blocker, with usb-wakeup-blocker.sh kept
  as a compatibility symlink
- Ship a man page
- Package the license with %%license and add a %%check section
- Use a Source0 URL that yields a versioned tarball name

* Sat Aug 29 2026 Nogunix <nogunix@gmail.com> - 1.1.1-1
- Fix helper binary path resolution for Homebrew installs on Apple Silicon

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
