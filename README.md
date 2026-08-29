[![CI](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml/badge.svg)](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/nogunix/usb-wakeup-blocker/branch/main/graph/badge.svg)](https://codecov.io/gh/nogunix/usb-wakeup-blocker)
[![GitHub release](https://img.shields.io/github/v/release/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/releases/latest)
[![Homebrew](https://img.shields.io/badge/homebrew-nogunix%2Ftap-orange)](https://github.com/nogunix/homebrew-tap)
[![COPR](https://img.shields.io/badge/copr-nogunix%2Fusb--wakeup--blocker-blue)](https://copr.fedorainfracloud.org/coprs/nogunix/usb-wakeup-blocker/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey)](https://github.com/nogunix/usb-wakeup-blocker)
[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)
[![GitHub stars](https://img.shields.io/github/stars/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/stargazers)

# usb wakeup blocker

Prevent your Linux or macOS machine from waking up unexpectedly — with precise control over which USB devices are allowed to do so.


## Why you might need this
Have you ever closed your laptop lid or put your PC to sleep, only for it to wake up instantly because you nudged your mouse — or due to a random USB signal?

**usb-wakeup-blocker** gives you **full control** over which USB devices can wake your system from sleep.
By default:
- Blocks **only mice** from waking the system.
- Keyboards and other devices remain unaffected.


## Prerequisites

### Linux

| Requirement | Required? | Notes |
|-------------|-----------|-------|
| **systemd** | Yes | This project targets Linux systems that use systemd. |
| **bash** 4.2 or later | Yes | The script re-execs itself with bash if started by another shell. |
| **`usbutils`** (`lsusb`) | Optional (recommended) | Device detection reads sysfs first. `lsusb -v` is used only as a fallback to classify mice/keyboards and to fill in missing product/vendor names. |

Installing `usbutils`:

| Distribution family | Package manager | Command |
|---------------------|-----------------|---------|
| Fedora / RHEL / CentOS Stream | `dnf` | `sudo dnf install usbutils` |
| Debian / Ubuntu | `apt` | `sudo apt install usbutils` |

**CI tested on:** Fedora 43 · Fedora 44 · Ubuntu 24.04 · Ubuntu 26.04
(every push runs the unit tests and an install/uninstall check against real
systemd on each of them). Other systemd-based distributions should work, but
are not covered by CI.

### macOS

Requires **bash 4+** (macOS ships with bash 3.2) and **Xcode Command Line Tools** (for compiling the IOKit helper). If you install via Homebrew, bash is handled automatically.

```bash
brew install bash                       # Homebrew install handles this
xcode-select --install                  # if not already installed
```

Device detection uses `ioreg` (built-in) instead of `lsusb`. The service runs as a persistent daemon via **launchd**, receiving sleep notifications and disabling USB remote wakeup before each sleep.


## Installation

Pick the method that matches your platform:

| Platform | Recommended method |
|----------|--------------------|
| Fedora | [A. COPR package (`dnf`)](#a-fedora-copr-package-dnf) — installs and updates through `dnf` |
| Debian / Ubuntu (`apt`) and any other systemd distribution | [B. From source (`install.sh`)](#b-from-source-any-systemd-distribution) — no `apt` package is provided |
| macOS | [C. Homebrew](#c-macos-homebrew) — recommended |
| macOS (manual) | [D. From source (`install.sh`)](#d-macos-from-source) |

### A. Fedora: COPR package (`dnf`)

```bash
sudo dnf copr enable nogunix/usb-wakeup-blocker
sudo dnf install usb-wakeup-blocker
sudo systemctl enable --now usb-wakeup-blocker.service
```

Updates then come with the rest of the system via `sudo dnf upgrade`.

### B. From source (any systemd distribution)

This is the path for Debian/Ubuntu (`apt`) users, since no `.deb` package is published. It is also fine on Fedora if you prefer to track `main` instead of the COPR build.

```bash
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker
sudo ./install.sh
sudo systemctl enable --now usb-wakeup-blocker.service
```

`install.sh` copies the script, the systemd unit, the udev rule, the default configuration file, and the bash/zsh completions into `/usr`. To update, `git pull` and re-run `sudo ./install.sh`; your existing `/etc/usb-wakeup-blocker.conf` is left untouched.

Verify the installation (the default behaviour blocks only mice):

```bash
sudo systemctl status usb-wakeup-blocker.service
```

### C. macOS: Homebrew

```bash
brew tap nogunix/tap
brew install usb-wakeup-blocker
sudo brew services start usb-wakeup-blocker
```

Updates then come with `brew upgrade usb-wakeup-blocker`.

### D. macOS (from source)

```bash
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker
sudo ./install.sh
sudo launchctl load -w /Library/LaunchDaemons/com.usb-wakeup-blocker.plist
```

The install script compiles the IOKit helper and places everything under `/usr/local`. The daemon runs persistently via launchd, intercepting sleep events to disable USB remote wakeup on target devices.


## Options Overview

| Flag | Description |
|------|-------------|
| `-m` | Block only mice from waking the system *(default)* |
| `-c` | Block both mice and keyboards |
| `-a` | Block all USB devices |
| `-w "NAME"` | Whitelist a device by product name (can be repeated). Use the **Product** value shown in `-v`/`-l` output |
| `-v` | Verbose output for diagnostics |
| `-d` | Dry-run mode (no changes made) |
| `-l`, `--list` | List the current wakeup status of all USB devices. Shorthand for `-v -d`, so it never changes anything |
| `-p`, `--path PATH` | Act on a single device instead of every USB device, given as its sysfs path (e.g. `/sys/bus/usb/devices/1-1`). This is what the udev rule uses to handle hot-plugged devices |
| `--daemon` | (macOS only) Run as a persistent daemon that disables USB remote wakeup before each sleep |
| `-h`, `--help` | Show usage |

Examples:

```bash
# Show what would happen, without touching anything
sudo usb-wakeup-blocker.sh -l

# Apply the current policy to one device that was just plugged in
sudo usb-wakeup-blocker.sh -p /sys/bus/usb/devices/1-2.3
```


## Configuration

The configuration file is located at:

- **Linux**: `/etc/usb-wakeup-blocker.conf`
- **macOS**: `/usr/local/etc/usb-wakeup-blocker.conf`

### Service Arguments (systemd)

Use the `ARGS` variable to pass command-line options to the script when it is
started by systemd. This controls which USB devices are blocked.

**Example: Block both mice and keyboards, but whitelist a specific keyboard**
```ini
ARGS='-c -w "My USB Keyboard"'
```
You can find device names by running:
```bash
# Linux
sudo /usr/bin/usb-wakeup-blocker.sh -v
# macOS
sudo /usr/local/bin/usb-wakeup-blocker.sh -v
```

To verify a product name before adding it to the configuration file, run a dry
run with the desired whitelist pattern:

```bash
sudo usb-wakeup-blocker.sh -d -w "My USB Keyboard"
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


## Logging and Recovery

### Execution Logs and Granularity

*   **Standard Output/Error**: The script logs its operations, warnings, and errors to standard output and standard error. When run as a `systemd` service, these logs are captured by the systemd journal. You can view them using `journalctl -u usb-wakeup-blocker.service`.
*   **Verbose Mode (`-v`)**: For detailed insights into device detection and intended actions, run the script with the `-v` flag. This provides a tabular summary of all detected USB devices, their types (mouse/keyboard), product/vendor names, and the action (enable/disable/ignore) that would be applied.

### Dry Run Example

To see exactly what changes the script *would* make without actually applying them, use the `-d` (dry-run) flag. Combine it with `-v` for a detailed report.

Example (Linux): `sudo /usr/bin/usb-wakeup-blocker.sh -d -v`

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

The script modifies USB device wakeup settings. If you need to revert changes:

*   **Linux — Re-enabling all devices**: Write `enabled` to each device's `power/wakeup` file:
    ```bash
    for i in /sys/bus/usb/devices/*/power/wakeup; do echo enabled | sudo tee $i; done
    ```
*   **macOS — Re-enabling all devices**: Remove the wakeup overrides by rebooting. The IOKit overrides are not persistent across reboots unless the launchd daemon is loaded.
*   **Uninstalling the service**: Use the `uninstall.sh` script. This will stop the service and remove its files, but will *not* automatically revert wakeup states on Linux. A reboot is recommended.


## Uninstallation

Use the counterpart of the installation method you chose.

### A. Installed from COPR (`dnf`)

```bash
sudo dnf remove usb-wakeup-blocker
sudo dnf copr disable nogunix/usb-wakeup-blocker
```

### B. Installed from source (`install.sh`)

```bash
sudo ./uninstall.sh
```

Run `./uninstall.sh --help` to see available options.

On **Linux**, removes: script, systemd service, udev rules, and configuration file.

On **macOS**, removes: script, IOKit helper, launchd daemon, and configuration file.

### C. Installed from Homebrew

```bash
sudo brew services stop usb-wakeup-blocker
brew uninstall usb-wakeup-blocker
brew untap nogunix/tap    # optional
```

Neither method reverts the `power/wakeup` state of devices that were already
changed — see [Recovery on Failure](#recovery-on-failure).


## Troubleshooting

### Common Issues & Solutions

| Problem | Platform | Cause | Solution |
|---------|----------|-------|----------|
| `lsusb: command not found` | Linux | `usbutils` not installed (optional, but improves device detection) | Fedora: `sudo dnf install usbutils` / Debian/Ubuntu: `sudo apt install usbutils` |
| `bash 4+ is required` | macOS | System bash is 3.2 | `brew install bash` |
| `C compiler (cc) not found` | macOS | Xcode CLI tools missing | `xcode-select --install` |
| No devices listed in verbose mode | Both | Script run without `sudo` | Run with `sudo` |
| Settings revert after reboot | Linux | Service not enabled | `sudo systemctl enable usb-wakeup-blocker.service` |
| Settings revert after reboot | macOS | Daemon not loaded | `sudo launchctl load -w /Library/LaunchDaemons/com.usb-wakeup-blocker.plist` |


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


## License

MIT License - see the [LICENSE](LICENSE) file for details.


This is my personal project. It is created and maintained in my personal capacity, and has no relation to my employer's business or confidential information.