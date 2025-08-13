# usb-wakeup-blocker

[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)


[English](./README.md) | [日本語](./README.ja.md)

A script and systemd service to precisely control which USB and ACPI devices can wake your computer from sleep.

## Overview 

On most Linux systems, many devices are allowed to wake the system from sleep by default. This can be frustrating when a sensitive mouse or a brief USB power fluctuation wakes your machine unintentionally.

This project solves the problem by implementing a **whitelist-based system**. Instead of trying to guess which devices to disable, you explicitly define which devices are **allowed** to wake the system. All other devices are automatically disabled.

### Default Behavior

By default, without any configuration, the service will only prevent **mice** from waking the system. All other devices, including keyboards, PC lids, and power buttons, will function as they did before. This provides a sensible default for the most common use case: preventing accidental wakeups from a sensitive mouse.

## Features

- **Whitelist Control**: Explicitly define which devices can wake the system.
- **Manages Both USB and ACPI**: Controls not only USB peripherals (mice, keyboards) but also internal ACPI devices (like internal keyboards, power buttons, and lids).
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
- Keyboards, lid switches, and power buttons will continue to work as usual.

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

*   **To see USB devices:**
```bash
sudo /usr/local/bin/usb-wakeup-blocker.sh -v
```

From the output, note the `Product` name for any USB device or the `ACPI Device` name for any ACPI device you wish to whitelist.

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
```
$ sudo /usr/local/bin/usb-wakeup-blocker.sh -v -w "2.4G Keyboard"
--- USB Wakeup Blocker ---
Mode: mouse
Whitelist Patterns: 2.4G Keyboard
Dry Run: false
--------------------------
Device: 1-2.2           | Product: USB Receiver              | Mouse: true  | Keyboard: true  | Action: ignore
Device: 1-2.3           | Product: REALFORCE HYBRID JP FULL  | Mouse: false | Keyboard: true  | Action: ignore
Device: 1-2.4           | Product: 2.4G Keyboard             | Mouse: true  | Keyboard: true  | Action: enable (whitelisted)
Device: 3-3             | Product: ELAN:Fingerprint          | Mouse: false | Keyboard: false | Action: ignore
Device: 3-4             | Product: (unknown product)         | Mouse: false | Keyboard: false | Action: ignore
--------------------------
Done.
```

**Example: Testing ACPI Device Whitelist**

```
$ sudo /usr/local/bin/usb-wakeup-blocker.sh -v -p "LID"
--- USB Wakeup Blocker ---
Mode: mouse
ACPI Whitelist Patterns: LID
Dry Run: false
--------------------------
Device: 1-2.2           | Product: USB Receiver              | Mouse: true  | Keyboard: true  | Action: ignore
Device: 1-2.3           | Product: REALFORCE HYBRID JP FULL  | Mouse: false | Keyboard: true  | Action: ignore
Device: 1-2.4           | Product: 2.4G Keyboard             | Mouse: true  | Keyboard: true  | Action: disable
Device: 3-3             | Product: ELAN:Fingerprint          | Mouse: false | Keyboard: false | Action: ignore
Device: 3-4             | Product: (unknown product)         | Mouse: false | Keyboard: false | Action: ignore
--------------------------
Done.

--- ACPI Wakeup Management ---
------------------------------
ACPI Device: GPP3       | Current: disabled | Desired: disabled | Action: No change needed
ACPI Device: GPP4       | Current: disabled | Desired: disabled | Action: No change needed
ACPI Device: GPP5       | Current: disabled | Desired: disabled | Action: No change needed
ACPI Device: XHC0       | Current: disabled | Desired: disabled | Action: No change needed
ACPI Device: XHC1       | Current: disabled | Desired: disabled | Action: No change needed
ACPI Device: GP19       | Current: disabled | Desired: disabled | Action: No change needed
ACPI Device: LID        | Current: enabled  | Desired: enabled  | Action: No change needed
ACPI Device: SLPB       | Current: disabled | Desired: disabled | Action: No change needed

```
In this example, the USB keyboard's product name is `REALFORCE HYBRID JP FULL` and the laptop lid is `LID`.

### Step 2: Edit the Configuration File

Next, open the configuration file to add your devices to the whitelist.

```bash
sudo nano /etc/usb-wakeup-blocker.conf
```

Update the `ARGS` variable as shown in the examples below.

#### Whitelist Syntax

*   **For USB devices**: Use `-w "Product Name"`.
*   **For ACPI devices**: Use `-p "Device Name"`.
*   If a device name contains spaces, you **must** enclose it in double quotes (`"`).
*   To whitelist multiple devices, simply add more `-w` or `-p` flags.

#### Configuration Examples

**Example 1: Whitelist a specific USB Keyboard**
```ini
# /etc/usb-wakeup-blocker.conf
# Allow a USB device with the product name "REALFORCE HYBRID JP FULL" to wake the system.
ARGS='-w "REALFORCE HYBRID JP FULL"'
```
> **Tip**: The script uses partial matching. You could also use a shorter, unique part of the name, like `ARGS='-w "REALFORCE"'`.

**Example 2: Whitelist a Keyboard and the PC Lid**
```ini
# /etc/usb-wakeup-blocker.conf
# Set mode to block mice and keyboards (-c), but explicitly allow a specific
# USB keyboard and the laptop lid (LID) to wake the system.
ARGS='-c -w "2.4G Keyboard" -p "LID"'
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

*   **Check service status**:
    ```bash
    systemctl status usb-wakeup-blocker.service
    ```
*   **View logs**:
    ```bash
    journalctl -u usb-wakeup-blocker.service
    ```

### Understanding the Verbose (`-v`) Output

When you run the script with the `-v` flag, it provides detailed information about each device it inspects. This is useful for debugging and for finding the correct device names for your configuration file.

```
$ sudo /usr/local/bin/usb-wakeup-blocker.sh -v -c -w "REALFORCE" -p "LID"
--- USB Wakeup Blocker ---
Mode: combo
Whitelist Patterns: REALFORCE
ACPI Whitelist Patterns: LID
Dry Run: false
--------------------------
Device: 1-2.2           | Product: USB Receiver              | Mouse: true  | Keyboard: true  | Action: disable
Device: 1-2.3           | Product: REALFORCE HYBRID JP FULL  | Mouse: false | Keyboard: true  | Action: enable (whitelisted)
--------------------------
Done.

--- ACPI Wakeup Management ---
------------------------------
ACPI Device: LID        | Current: enabled  | Desired: enabled  | Action: ignore
ACPI Device: GPP3       | Current: enabled  | Desired: disabled | Action: disable
```

Here's a breakdown of the columns:

**For USB Devices:**

*   **`Device`**: The internal system ID for the USB device (e.g., `1-2.2`).
*   **`Product`**: The human-readable product name. This is the name you should use with the `-w` flag in your configuration file.
*   **`Mouse` / `Keyboard`**: `true` if the device identifies as a mouse or keyboard.
*   **`Action`**: The action taken by the script:
    *   `disable`: The device matched the blocking criteria (e.g., it's a mouse/keyboard in `combo` mode) and its wakeup capability was disabled.
    *   `enable (whitelisted)`: The device was found in the USB whitelist and its wakeup capability was enabled.
    *   `ignore`: No change was made. This usually means the device's wakeup state was already correct.

**For ACPI Devices:**

*   **`ACPI Device`**: The name of the ACPI device (e.g., `LID`). Use this with the `-p` flag.
*   **`Current`**: The current wakeup state (`enabled` or `disabled`).
*   **`Desired`**: The desired state based on your whitelist. Whitelisted devices should be `enabled`, others `disabled`.
*   **`Action`**:
    *   `Toggling state`: The current state did not match the desired state, so the script changed it.
    *   `No change needed`: The device is already in the desired state.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.