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
# The install script requires administrator privileges to copy files and manage the service.
sudo ./install.sh
```

The script will:
1.  Copy the main script to `/usr/local/bin/`.
2.  Copy the systemd service file to `/etc/systemd/system/`.
3.  Copy a default configuration file to `/etc/usb-wakeup-blocker.conf` (if one doesn't already exist).
4.  Reload the systemd daemon.

**Note**: The service is **not** enabled or started automatically. You must do this manually after configuration.

## Configuration

After installation, all configuration is done by editing `/etc/usb-wakeup-blocker.conf`.

1.  **Find your device names**: Run the script in verbose mode to see all available USB and ACPI devices.
    ```bash
    sudo /usr/local/bin/usb-wakeup-blocker.sh -v
    ```
    Look for the `Product` name of the USB keyboard you want to enable, and the `ACPI Device` name for internal devices (e.g., `GPP3`, `LID`).

2.  **Edit the configuration file**:
    ```bash
    sudo nano /etc/usb-wakeup-blocker.conf
    ```

3.  **Update the `ARGS` variable**: Add your desired devices using the `-w` (for USB) and `-p` (for ACPI) flags.
    ```ini
    # Example: Allow a specific USB keyboard and the PC lid to wake the system.
    ARGS='-w "My USB Keyboard" -p "LID"'
    ```

4.  **Restart the service** to apply your changes:
    ```bash
    sudo systemctl restart usb-wakeup-blocker.service
    ```

If you are setting up the service for the first time, use the following command to enable it (so it starts on boot) and start it immediately:
```bash
sudo systemctl enable --now usb-wakeup-blocker.service
```

## Uninstallation

```bash
# The uninstall script requires administrator privileges.
sudo ./uninstall.sh
```

This will stop and disable the service, and remove all files created during installation, including the configuration file.

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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
