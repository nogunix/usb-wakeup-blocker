[![CI](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml/badge.svg)](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/nogunix/usb-wakeup-blocker/branch/main/graph/badge.svg)](https://codecov.io/gh/nogunix/usb-wakeup-blocker)
[![GitHub release](https://img.shields.io/github/v/release/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/releases/latest)
[![COPR](https://img.shields.io/badge/copr-nogunix%2Fusb--wakeup--blocker-blue)](https://copr.fedorainfracloud.org/coprs/nogunix/usb-wakeup-blocker/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)](https://github.com/nogunix/usb-wakeup-blocker)
[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)
[![GitHub stars](https://img.shields.io/github/stars/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/stargazers)

# usb wakeup blocker

Prevent your Linux machine from waking up unexpectedly — with precise control over which USB devices are allowed to do so.


## Why you might need this
Have you ever closed your laptop lid or put your PC to sleep, only for it to wake up instantly because you nudged your mouse — or due to a random USB signal?

**usb-wakeup-blocker** gives you **full control** over which USB devices can wake your system from sleep.
By default:
- Blocks **only mice** from waking the system.
- Keyboards and other devices remain unaffected.


## Quick start

Find your platform, run the three commands, done. The default policy blocks
**only mice** — keyboards and everything else keep their ability to wake the
machine.

| Your system | Install with | Jump to |
|-------------|--------------|---------|
| **Fedora** / **RHEL** / **CentOS Stream** / Rocky / AlmaLinux | `dnf` (COPR package) | [dnf](#fedora-rhel-centos-stream-dnf) |
| **macOS** | `brew` (Homebrew tap) | [macOS](#macos-homebrew) |
| Debian / Ubuntu / Arch / any other systemd distro | `install.sh` from source | [Other Linux](#other-linux-from-source) |
| macOS, without Homebrew | `install.sh` from source | [macOS from source](#macos-from-source) |

### Fedora, RHEL, CentOS Stream (`dnf`)

The [COPR repository](https://copr.fedorainfracloud.org/coprs/nogunix/usb-wakeup-blocker/)
carries builds for **Fedora 43/44** and for **EL 9 / EL 10** — the latter covers
RHEL, CentOS Stream, Rocky Linux and AlmaLinux. Every one of them is built for
both `x86_64` and `aarch64`.

```bash
sudo dnf copr enable nogunix/usb-wakeup-blocker
sudo dnf install usb-wakeup-blocker
sudo systemctl enable --now usb-wakeup-blocker.service
```

Check that it worked (this only reads, it never changes anything):

```bash
sudo usb-wakeup-blocker.sh -l
```

Updates arrive with the rest of the system via `sudo dnf upgrade`.
Everything the package needs (`systemd`, `usbutils`) is pulled in as a
dependency, and on RHEL-family systems all of it lives in BaseOS — **EPEL is
not required**.

On a minimal RHEL install `dnf copr` may be missing; add the plugin first with
`sudo dnf install dnf-plugins-core`.

### macOS (Homebrew)

```bash
brew tap nogunix/tap
brew install usb-wakeup-blocker
sudo brew services start usb-wakeup-blocker
```

Check that it worked:

```bash
sudo usb-wakeup-blocker.sh -l
```

Updates come with `brew upgrade usb-wakeup-blocker`.
Homebrew installs the required bash 4+ for you; the service then runs as a
persistent **launchd** daemon that disables USB remote wakeup before each sleep.

### Other Linux (from source)

This is the path for Debian/Ubuntu and every other systemd distribution — no
`.deb` package is published. It also works on Fedora if you would rather track
`main` than the COPR build.

Requirements: **systemd**, **bash 4.2+**, and optionally `usbutils` for better
device names (`sudo apt install usbutils`).

```bash
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker
sudo ./install.sh
sudo systemctl enable --now usb-wakeup-blocker.service
```

Check that it worked:

```bash
sudo usb-wakeup-blocker.sh -l
```

`install.sh` copies the script, the systemd unit, the udev rule, the default
configuration file, and the bash/zsh completions into `/usr`. To update,
`git pull` and re-run `sudo ./install.sh`; your existing
`/etc/usb-wakeup-blocker.conf` is left untouched.

### macOS (from source)

Requirements: **bash 4+** (macOS ships 3.2) and the **Xcode Command Line
Tools**, used to compile the IOKit helper.

```bash
brew install bash
xcode-select --install                  # if not already installed

git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker
sudo ./install.sh
sudo launchctl load -w /Library/LaunchDaemons/com.usb-wakeup-blocker.plist
```

The install script compiles the IOKit helper and places everything under
`/usr/local`.


## Requirements in detail

Skip this if you installed via `dnf` or `brew` — those handle it for you.

| Requirement | Required? | Notes |
|-------------|-----------|-------|
| **systemd** | Yes | This project targets Linux systems that use systemd. |
| **bash** 4.2 or later | Yes | The script re-execs itself with bash if started by another shell. |
| **`usbutils`** (`lsusb`) | Optional (recommended) | Device detection reads sysfs first. `lsusb -v` is used only as a fallback to classify mice/keyboards and to fill in missing product/vendor names. |

Installing `usbutils`: `sudo dnf install usbutils` (Fedora / RHEL / CentOS
Stream) or `sudo apt install usbutils` (Debian / Ubuntu).

**CI tested on:** Fedora 43 · Fedora 44 · CentOS Stream 9 · CentOS Stream 10 ·
Ubuntu 24.04 · Ubuntu 26.04. Every push runs the unit tests on all of them, an
install/uninstall check against real systemd on Fedora and Ubuntu, and an RPM
build plus package install check on Fedora and CentOS Stream. Other
systemd-based distributions should work, but are not covered by CI.



## Installation

Pick the method that matches your distribution:

| Distribution | Recommended method |
|--------------|--------------------|
| Fedora | [A. COPR package (`dnf`)](#a-fedora-copr-package-dnf) — installs and updates through `dnf` |
| Debian / Ubuntu (`apt`) and any other systemd distribution | [B. From source (`install.sh`)](#b-from-source-any-systemd-distribution) — no `apt` package is provided |

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
| `-h`, `--help` | Show usage |

Examples:

```bash
# Show what would happen, without touching anything
sudo usb-wakeup-blocker.sh -l

# Apply the current policy to one device that was just plugged in
sudo usb-wakeup-blocker.sh -p /sys/bus/usb/devices/1-2.3
```


## Configuration

The configuration file is located at `/etc/usb-wakeup-blocker.conf`.

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

The script modifies USB device wakeup settings. If you need to revert changes:

*   **Re-enabling all devices**: Write `enabled` to each device's `power/wakeup` file:
    ```bash
    for i in /sys/bus/usb/devices/*/power/wakeup; do echo enabled | sudo tee $i; done
    ```
*   **Uninstalling the service**: Use the `uninstall.sh` script. This will stop the service and remove its files, but will *not* automatically revert wakeup states. A reboot is recommended.


## Uninstallation

Use the counterpart of the installation method you chose.

### Installed with `dnf` (Fedora / RHEL / CentOS Stream — COPR)

```bash
sudo dnf remove usb-wakeup-blocker
sudo dnf copr disable nogunix/usb-wakeup-blocker
```

### Installed with `brew` (macOS)

```bash
sudo brew services stop usb-wakeup-blocker
brew uninstall usb-wakeup-blocker
brew untap nogunix/tap    # optional
```

### Installed from source (`install.sh`)

```bash
sudo ./uninstall.sh
```

Run `./uninstall.sh --help` to see available options.

Removes: script, systemd service, udev rules, and configuration file.

Neither method reverts the `power/wakeup` state of devices that were already
changed — see [Recovery on Failure](#recovery-on-failure).


## Troubleshooting

### Common Issues & Solutions

| Problem | Cause | Solution |
|---------|-------|----------|
| `lsusb: command not found` | `usbutils` not installed (optional, but improves device detection) | Fedora: `sudo dnf install usbutils` / Debian/Ubuntu: `sudo apt install usbutils` |
| No devices listed in verbose mode | Script run without `sudo` | Run with `sudo` |
| Settings revert after reboot | Service not enabled | `sudo systemctl enable usb-wakeup-blocker.service` |


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
