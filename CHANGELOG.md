# Changelog

## v1.0.3
- Support Fedora 44.
- Modernized RPM spec file with proper dependencies and systemd macros.

## v1.0.2
- Added packaged bash and zsh completions so the RPM ships shell completions out of the box.

## v1.0.1
- Updated version to 1.0.1
- Aligned installation paths of `usb-wakeup-blocker.sh` and `usb-wakeup-blocker.service` with RPM packaging standards:
    - `usb-wakeup-blocker.sh`: from `/usr/local/bin/usb-wakeup-blocker.sh` to `/usr/bin/usb-wakeup-blocker.sh`
    - `usb-wakeup-blocker.service`: from `/etc/systemd/system/usb-wakeup-blocker.service` to `/usr/lib/systemd/system/usb-wakeup-blocker.service`

## v1.0.0
- Initial release
- RPM packaging for easy installation via Copr.
