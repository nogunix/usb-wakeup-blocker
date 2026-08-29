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

OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
    # ===== macOS =====
    LAUNCHD_PLIST="/Library/LaunchDaemons/com.usb-wakeup-blocker.plist"

    if launchctl list com.usb-wakeup-blocker >/dev/null 2>&1; then
        ${SUDO} launchctl unload -w "$LAUNCHD_PLIST" || true
    fi
    ${SUDO} rm -f "$LAUNCHD_PLIST"
    ${SUDO} rm -f /usr/local/bin/usb-wakeup-blocker.sh
    ${SUDO} rm -f /usr/local/bin/usb-wakeup-helper
    ${SUDO} rm -f /usr/local/etc/usb-wakeup-blocker.conf
    ${SUDO} rm -f /usr/local/share/bash-completion/completions/usb-wakeup-blocker
    ${SUDO} rm -f /usr/local/share/zsh/site-functions/_usb-wakeup-blocker
else
    # ===== Linux =====
    BIN="/usr/bin/usb-wakeup-blocker.sh"
    SERVICE="/usr/lib/systemd/system/usb-wakeup-blocker.service"
    UDEV_RULES="/etc/udev/rules.d/99-usb-wakeup-blocker.rules"
    CONFIG_FILE="/etc/usb-wakeup-blocker.conf"
    BASH_COMPLETION="/usr/share/bash-completion/completions/usb-wakeup-blocker"
    ZSH_COMPLETION="/usr/share/zsh/site-functions/_usb-wakeup-blocker"

    if command -v systemctl >/dev/null 2>&1; then
        ${SUDO} systemctl disable --now usb-wakeup-blocker.service || true
    fi
    ${SUDO} rm -f "$SERVICE"
    ${SUDO} rm -f "/etc/systemd/system/usb-wakeup-blocker.service" || true

    if command -v systemctl >/dev/null 2>&1; then
        ${SUDO} systemctl daemon-reload || true
    fi

    ${SUDO} rm -f "$UDEV_RULES"
    if command -v udevadm >/dev/null 2>&1; then
        ${SUDO} udevadm control --reload-rules || true
    fi

    ${SUDO} rm -f "$BIN"
    ${SUDO} rm -f "/usr/local/bin/usb-wakeup-blocker.sh" || true
    ${SUDO} rm -f "$CONFIG_FILE"
    ${SUDO} rm -f "$BASH_COMPLETION"
    ${SUDO} rm -f "$ZSH_COMPLETION"
fi

echo "Uninstalled."
echo "A reboot is recommended to fully revert changes to wakeup settings."
