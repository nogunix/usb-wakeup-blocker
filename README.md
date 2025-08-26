[![CI](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml/badge.svg)](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)

# usb wakeup blocker

Prevent your Linux PC from waking up unexpectedly — with precise control over which USB devices are allowed to do so.

---

## Why you might need this
Have you ever closed your laptop lid or put your PC to sleep, only for it to wake up instantly because you nudged your mouse — or due to a random USB signal?

**usb-wakeup-blocker** gives you **full control** over which USB devices can wake your system from sleep.
By default:
- Blocks **only mice** from waking the system.
- Keyboards and other devices remain unaffected.

---

## Prerequisites

This project targets Linux systems that use **systemd** and requires the `usbutils` package so that `lsusb` is available. If `usbutils` isn't installed, add it, for example on Debian/Ubuntu:

```bash
sudo apt install usbutils
```

---

## Quick Start (default: block only mice)

```bash
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker
sudo ./install.sh
sudo systemctl enable --now usb-wakeup-blocker.service
```

Check that the service is running:

```bash
sudo systemctl status usb-wakeup-blocker.service
```

Example output:

```
● usb-wakeup-blocker.service - USB wakeup blocker
     Loaded: loaded (/usr/lib/systemd/system/usb-wakeup-blocker.service; enabled; preset: enabled)
     Active: active (exited) since Thu 2024-01-01 00:00:00 UTC; 1s ago
```

You're done ✅ — your mouse can no longer wake the system, but your keyboard still works as before.

---

## Installation via COPR

For Fedora, you can install `usb-wakeup-blocker` from the COPR repository:

```bash
sudo dnf copr enable nogunix/usb-wakeup-blocker
sudo dnf install usb-wakeup-blocker
```

---

## Options Overview

| Flag | Description |
|------|-------------|
| `-m` | Block only mice from waking the system *(default)* |
| `-c` | Block both mice and keyboards |
| `-a` | Block all USB devices |
| `-w "NAME"` | Whitelist a device by product name (can be repeated). Use the **Product** value shown in `-v` output |
| `-v` | Verbose output for diagnostics |
| `-d` | Dry-run mode (no changes made) |

---

## Configuration

The configuration file is located at:

```
/etc/usb-wakeup-blocker.conf
```

### Service Arguments (systemd)

Use the `ARGS` variable to pass command-line options to the script when it is
started by systemd. This controls which USB devices are blocked.

**Example: Block both mice and keyboards, but whitelist a specific keyboard**
```ini
ARGS='-c -w "My USB Keyboard"'
```
You can find device names by running:
```bash
sudo /usr/bin/usb-wakeup-blocker.sh -v
```

To verify a product name before adding it to the configuration file, run a dry
run with the desired whitelist pattern:

```bash
sudo /usr/bin/usb-wakeup-blocker.sh -d -w "My USB Keyboard"
```

The `-d` flag performs a trial run without modifying system settings, letting
you confirm that the device is interpreted correctly.

### Script Variables

These variables are read directly by the script to set its default behaviour.
Use them to define the mode and whitelist patterns. Quote multi-word whitelist
patterns so they remain intact when parsed:

```ini
MODE=combo
WHITELIST_PATTERNS='"Mouse Device" "Keyboard Device"'
```

Each entry is matched against the device's `Product` name.

Restart the service to apply:
```bash
sudo systemctl restart usb-wakeup-blocker.service
```

---

## Uninstallation

```bash
sudo ./uninstall.sh
```

Run `./uninstall.sh --help` to see available options.

Removes:
- Installed script
- systemd service file
- Configuration file

---

## Troubleshooting

### Common Issues & Solutions

| Problem | Cause | Solution |
|---------|-------|----------|
| `lsusb: command not found` | `usbutils` not installed | `sudo dnf install usbutils` (Fedora) / `sudo apt install usbutils` (Debian/Ubuntu) |
| No devices listed in verbose mode | Script run without `sudo` | Run with `sudo` |
| Settings revert after reboot | Service not enabled | `sudo systemctl enable usb-wakeup-blocker.service` |

---

## Development & Testing

For detailed contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

Run the test suite:
```bash
./test/run-tests.sh
```

Check shell script with ShellCheck:
```bash
shellcheck bin/usb-wakeup-blocker.sh
```

---

## License

MIT License - see the [LICENSE](LICENSE) file for details.
