#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then SUDO=sudo; else SUDO=; fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: sudo $0"
    echo "Installs the usb-wakeup-blocker script and systemd service."
    exit 0
fi

set -euo pipefail

PREFIX="/usr"
BIN="$PREFIX/bin/usb-wakeup-blocker.sh"
CONFIG_DIR="/etc"
CONFIG_FILE="$CONFIG_DIR/usb-wakeup-blocker.conf"
SERVICE="$PREFIX/lib/systemd/system/usb-wakeup-blocker.service"

SOURCE_BIN="bin/usb-wakeup-blocker.sh"
SOURCE_CONFIG="etc/usb-wakeup-blocker.conf"
SOURCE_SERVICE="systemd/usb-wakeup-blocker.service"

for f in "$SOURCE_BIN" "$SOURCE_CONFIG" "$SOURCE_SERVICE"; do
    if [ ! -f "$f" ]; then
        echo "Error: Source file not found: $f" >&2
        exit 1
    fi
done

${SUDO} install -Dm755 "$SOURCE_BIN" "$BIN"
${SUDO} install -d "$CONFIG_DIR"
# Install config file only if it doesn't exist to preserve user changes.
# Using a test condition for better portability instead of the non-standard -n flag.
if [ ! -f "$CONFIG_FILE" ]; then
    ${SUDO} install -m644 "$SOURCE_CONFIG" "$CONFIG_FILE"
fi
${SUDO} install -Dm644 "$SOURCE_SERVICE" "$SERVICE"

${SUDO} systemctl daemon-reload

echo "Installed successfully."
echo "Configuration file template created at '/etc/usb-wakeup-blocker.conf'."
echo "Please edit it to your needs, then enable and start the service with:"
echo "  sudo systemctl enable --now usb-wakeup-blocker.service"
