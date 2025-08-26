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

## Logging and Recovery

### Execution Logs and Granularity

*   **Standard Output/Error**: The script logs its operations, warnings, and errors to standard output and standard error. When run as a `systemd` service, these logs are captured by the systemd journal. You can view them using `journalctl -u usb-wakeup-blocker.service`.
*   **Verbose Mode (`-v`)**: For detailed insights into device detection and intended actions, run the script with the `-v` flag. This provides a tabular summary of all detected USB devices, their types (mouse/keyboard), product/vendor names, and the action (enable/disable/ignore) that would be applied.

### Dry Run Example

To see exactly what changes the script *would* make without actually applying them, use the `-d` (dry-run) flag. Combine it with `-v` for a detailed report.

Example: `sudo /usr/bin/usb-wakeup-blocker.sh -d -v`

```
--- USB Wakeup Management ---
Mode: mouse
Dry Run: true
----------------------------------------------------------------------------------------------------------
Device          | Product (for -w)             | Vendor                       | Mouse | Keyboard | Action
----------------------------------------------------------------------------------------------------------
1-2             | USB2.1 Hub                   | Genesys Logic, Inc.          | false | false    | ignore
1-2.2           | USB Receiver                 | Logitech, Inc.               | true  | true     | ignore
1-2.3           | REALFORCE HYBRID JP FULL     | Topre Corporation            | false | true     | ignore
1-2.4           | 2.4G Keyboard                | SHARKOON Technologies GmbH   | true  | true     | ignore
2-2             | USB3.1 Hub                   | Genesys Logic, Inc.          | false | false    | ignore
3-3             | ELAN:Fingerprint             | Elan Microelectronics Corp.  | false | false    | ignore
3-4             | (unknown product)            | Intel Corp.                  | false | false    | ignore
usb1            | xHCI Host Controller         | Linux Foundation             | false | false    | ignore
usb2            | xHCI Host Controller         | Linux Foundation             | false | false    | ignore
usb3            | xHCI Host Controller         | Linux Foundation             | false | false    | ignore
usb4            | xHCI Host Controller         | Linux Foundation             | false | false    | ignore
----------------------------------------------------------------------------------------------------------
Done.
```

### Recovery on Failure

The `usb-wakeup-blocker.sh` script modifies the `power/wakeup` attribute of USB devices in the `/sys/bus/usb/devices/` directory. If you need to revert changes or restore devices to their original wakeup state, consider the following:

*   **Re-enabling all devices**: To re-enable wakeup for all USB devices, you can manually write `enabled` to their `power/wakeup` files.
    ```bash
    for i in /sys/bus/usb/devices/*/power/wakeup; do echo enabled | sudo tee $i; done
    ```
    *Note: This command will re-enable wakeup for ALL USB devices, including those you might have intentionally blocked.*
*   **Uninstalling the service**: If you wish to completely remove the `usb-wakeup-blocker` service and its configuration, use the `uninstall.sh` script. This will stop the service and remove its files, but will *not* automatically revert the `power/wakeup` states of individual devices. You may need to manually re-enable devices as described above after uninstallation.

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
