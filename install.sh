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
UDEV_RULES_TARGET="$CONFIG_DIR/udev/rules.d/99-usb-wakeup-blocker.rules"
BASH_COMPLETION_TARGET="$PREFIX/share/bash-completion/completions/usb-wakeup-blocker"
ZSH_COMPLETION_TARGET="$PREFIX/share/zsh/site-functions/_usb-wakeup-blocker"

SOURCE_BIN="bin/usb-wakeup-blocker.sh"
SOURCE_CONFIG="etc/usb-wakeup-blocker.conf"
SOURCE_SERVICE="systemd/usb-wakeup-blocker.service"
SOURCE_UDEV_RULES="udev/99-usb-wakeup-blocker.rules"
SOURCE_BASH_COMPLETION="completions/bash/usb-wakeup-blocker"
SOURCE_ZSH_COMPLETION="completions/zsh/_usb-wakeup-blocker"

for f in "$SOURCE_BIN" "$SOURCE_CONFIG" "$SOURCE_SERVICE" "$SOURCE_UDEV_RULES" "$SOURCE_BASH_COMPLETION" "$SOURCE_ZSH_COMPLETION"; do
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
${SUDO} install -Dm644 "$SOURCE_UDEV_RULES" "$UDEV_RULES_TARGET"
${SUDO} install -Dm644 "$SOURCE_BASH_COMPLETION" "$BASH_COMPLETION_TARGET"
${SUDO} install -Dm644 "$SOURCE_ZSH_COMPLETION" "$ZSH_COMPLETION_TARGET"

if command -v systemctl >/dev/null 2>&1; then
    ${SUDO} systemctl daemon-reload || true
fi

if command -v udevadm >/dev/null 2>&1; then
    ${SUDO} udevadm control --reload-rules || true
    ${SUDO} udevadm trigger --subsystem-match=usb || true
fi

echo "Installed successfully."
echo "Configuration file template created at '/etc/usb-wakeup-blocker.conf'."
echo "Please edit it to your needs, then enable and start the service with:"
echo "  sudo systemctl enable --now usb-wakeup-blocker.service"
echo "Shell completions installed for bash and zsh. Restart your shell to load them."
