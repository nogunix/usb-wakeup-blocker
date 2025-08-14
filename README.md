# usb-wakeup-blocker

[![CI](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml/badge.svg)](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)

[English](./README.md) | [日本語](./README.ja.md)

A script and systemd service to precisely control which USB devices can wake your computer from sleep.

## Overview 

On most Linux systems, many USB devices are allowed to wake the system from sleep by default. This can be frustrating when a sensitive mouse or a brief USB power fluctuation wakes your machine unintentionally.

This project solves the problem by implementing a **whitelist-based system**. Instead of trying to guess which devices to disable, you explicitly define which devices are **allowed** to wake the system. All other devices are automatically disabled.

### Default Behavior

By default, without any configuration, the service will only prevent **mice** from waking the system. All other devices, including keyboards, will function as they did before. This provides a sensible default for the most common use case: preventing accidental wakeups from a sensitive mouse.

## Features

- **Whitelist Control**: Explicitly define which devices can wake the system.
- **USB Wake Management Only**: Controls USB peripherals (mice, keyboards, etc.).
- **Configuration File**: All settings are managed in a simple configuration file (`/etc/usb-wakeup-blocker.conf`).
- **Systemd Integration**: Runs as a `systemd` service to apply settings automatically on boot.
- **Diagnostics**: Includes verbose (`-v`) and dry-run (`-d`) modes for easy troubleshooting.

## Requirements

- A Linux system using `systemd`.
- `lsusb` command (usually provided by the `usbutils` package).

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker

# 2. Run the installation script
# The install script requires administrator privileges to copy files and manage the service.
sudo ./install.sh
```

The script will:
1.  Copy the main script to `/usr/local/bin/`.
2.  Copy the systemd service file to `/etc/systemd/system/`.
3.  Copy a default configuration file to `/etc/usb-wakeup-blocker.conf` (if one doesn't already exist).
4.  Reload the systemd daemon.

**Note**: The service is **not** enabled or started automatically. You must do this manually after configuration.

## Simple Usage: No Configuration File Editing

For most users, you do **not** need to edit the configuration file.
Just install and start the service:

```bash
sudo systemctl enable --now usb-wakeup-blocker.service
```

**Default behavior:**
- Only mice will be blocked from waking the system.
- Keyboards will continue to work as usual.

If you want to change which devices are blocked or allowed, you can edit `/etc/usb-wakeup-blocker.conf` manually.

## Configuration

Configuration is managed by editing the `ARGS` variable in `/etc/usb-wakeup-blocker.conf`. This variable holds the command-line arguments passed to the script when the service starts.

### Mode Selection

The script provides modes to control which types of devices are blocked from waking the system. You can set the mode by including one of the following flags in the `ARGS` variable in `/etc/usb-wakeup-blocker.conf`.

*   **`-m` (default)**: Blocks only mice from waking the system.
*   **`-c`**: Blocks both mice and keyboards from waking the system.
*   **`-a`**: Blocks all USB devices from waking the system.

**Example:**
```ini
# /etc/usb-wakeup-blocker.conf
# Set the mode to block both mice and keyboards.
ARGS='-c'
```

### Step 1: Find Your Device Names

First, use the `-v` (verbose) flag to identify the names of your devices.

```bash
sudo /usr/local/bin/usb-wakeup-blocker.sh -v
```

From the output, note the `Product` name for any USB device you wish to whitelist.

**Example Output:**
```
$ sudo /usr/local/bin/usb-wakeup-blocker.sh -v
--- USB Wakeup Blocker ---
Mode: mouse
Dry Run: false
--------------------------
Device: 1-2.2           | Product: USB Receiver              | Mouse: true  | Keyboard: true  | Action: ignore
Device: 1-2.3           | Product: REALFORCE HYBRID JP FULL  | Mouse: false | Keyboard: true  | Action: ignore
Device: 1-2.4           | Product: 2.4G Keyboard             | Mouse: true  | Keyboard: true  | Action: ignore
Device: 3-3             | Product: ELAN:Fingerprint          | Mouse: false | Keyboard: false | Action: ignore
Device: 3-4             | Product: (unknown product)         | Mouse: false | Keyboard: false | Action: ignore
--------------------------
Done.
```

### Step 2: Edit the Configuration File

Next, open the configuration file to add your devices to the whitelist.

```bash
sudo nano /etc/usb-wakeup-blocker.conf
```

Update the `ARGS` variable as shown in the examples below.

#### Whitelist Syntax

*   **For USB devices**: Use `-w "Product Name"`.
*   If a device name contains spaces, you **must** enclose it in double quotes (`"`).
*   To whitelist multiple devices, simply add more `-w` flags.

#### Configuration Examples

**Example 1: Whitelist a specific USB Keyboard**
```ini
# /etc/usb-wakeup-blocker.conf
ARGS='-w "REALFORCE HYBRID JP FULL"'
```

**Example 2: Whitelist a Keyboard and Mouse**
```ini
# /etc/usb-wakeup-blocker.conf
ARGS='-c -w "2.4G Keyboard"'
```

### Step 3: Restart the Service

After saving the configuration file, restart the `systemd` service to apply your changes.

```bash
sudo systemctl restart usb-wakeup-blocker.service
```

Your new settings are now active.

## Uninstallation

```bash
# The uninstall script requires administrator privileges.
sudo ./uninstall.sh
```

This will stop and disable the service, and remove all files created during installation, including the configuration file.
A reboot is recommended to fully reset any changes made to the wakeup settings.

## Troubleshooting

### Checking the Service

```bash
systemctl status usb-wakeup-blocker.service
journalctl -u usb-wakeup-blocker.service
```

### Understanding the Verbose (`-v`) Output

When you run the script with the `-v` flag, it provides detailed information about each device it inspects.

- **Device**: Internal system ID for the USB device.
- **Product**: Human-readable product name.
- **Mouse / Keyboard**: Whether the device identifies as a mouse or keyboard.
- **Action**: Whether the device is disabled, enabled (whitelisted), or ignored.

## Development & Testing

Run the test suite:
```bash
./test/run-tests.sh
```

Run ShellCheck:
```bash
shellcheck bin/usb-wakeup-blocker.sh
```

## License

MIT License - see the [LICENSE](LICENSE) file for details.