#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then SUDO=sudo; else SUDO=; fi
set -euo pipefail

BIN="/usr/local/bin/usb-wakeup-blocker.sh"
SERVICE="/etc/systemd/system/usb-wakeup-blocker.service"
CONFIG_FILE="/etc/usb-wakeup-blocker.conf"

${SUDO} systemctl disable --now usb-wakeup-blocker.service || true
${SUDO} rm -f "$SERVICE"
${SUDO} systemctl daemon-reload

${SUDO} rm -f "$BIN"
${SUDO} rm -f "$CONFIG_FILE"

echo "Uninstalled."
echo "A reboot is recommended to fully revert changes to wakeup settings."

