#!/usr/bin/env bash
set -euo pipefail

BIN="/usr/local/bin/usb-wakeup-blocker.sh"
SERVICE="/etc/systemd/system/usb-wakeup-blocker.service"
CONFIG_FILE="/etc/usb-wakeup-blocker.conf"

sudo systemctl disable --now usb-wakeup-blocker.service || true
sudo rm -f "$SERVICE"
sudo systemctl daemon-reload

sudo rm -f "$BIN"
sudo rm -f "$CONFIG_FILE"

echo "Uninstalled."
