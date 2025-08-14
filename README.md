# usb-wakeup-blocker

Prevent your Linux PC from waking up unexpectedly — with precise control over which USB devices are allowed to do so.

[![CI](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml/badge.svg)](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)

---

## Why you might need this
Have you ever closed your laptop lid or put your PC to sleep, only for it to wake up instantly because you nudged your mouse — or due to a random USB signal?

**usb-wakeup-blocker** gives you **full control** over which USB devices can wake your system from sleep.
By default:
- Blocks **only mice** from waking the system.
- Keyboards and other devices remain unaffected.

---

## Quick Start (default: block only mice)

```bash
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker
sudo ./install.sh
sudo systemctl enable --now usb-wakeup-blocker.service
```

You're done ✅ — your mouse can no longer wake the system, but your keyboard still works as before.

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

Edit the `ARGS` variable to pass options to the script when started by systemd.

**Example: Block both mice and keyboards, but whitelist a specific keyboard**
```ini
ARGS='-c -w "My USB Keyboard"'
```
You can find device names by running:
```bash
  sudo /usr/local/bin/usb-wakeup-blocker.sh -v
```


Restart the service to apply:
```bash
sudo systemctl restart usb-wakeup-blocker.service
```

---

## Uninstallation

```bash
sudo ./uninstall.sh
```

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
