#!/usr/bin/env bash
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<'EOF'
usb-wakeup-blocker uninstall script

Usage: ./uninstall.sh [--help|-h]

Removes installed usb-wakeup-blocker service, script, and configuration file.
Requires root privileges (sudo is used if not run as root).
EOF
    exit 0
fi
if [[ $EUID -ne 0 ]]; then SUDO=sudo; else SUDO=; fi
set -euo pipefail

BIN="/usr/bin/usb-wakeup-blocker.sh"
SERVICE="/usr/lib/systemd/system/usb-wakeup-blocker.service"
CONFIG_FILE="/etc/usb-wakeup-blocker.conf"

${SUDO} systemctl disable --now usb-wakeup-blocker.service || true
${SUDO} rm -f "$SERVICE"
${SUDO} systemctl daemon-reload

${SUDO} rm -f "$BIN"
${SUDO} rm -f "$CONFIG_FILE"

echo "Uninstalled."
echo "A reboot is recommended to fully revert changes to wakeup settings."

