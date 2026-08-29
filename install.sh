#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then SUDO=sudo; else SUDO=; fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: sudo $0"
    echo "Installs the usb-wakeup-blocker script and service."
    exit 0
fi

set -euo pipefail

OS="$(uname -s)"

SOURCE_BIN="bin/usb-wakeup-blocker.sh"
SOURCE_CONFIG="etc/usb-wakeup-blocker.conf"
SOURCE_BASH_COMPLETION="completions/bash/usb-wakeup-blocker"
SOURCE_ZSH_COMPLETION="completions/zsh/_usb-wakeup-blocker"

if [[ "$OS" == "Darwin" ]]; then
    # ===== macOS =====
    PREFIX="/usr/local"
    BIN="$PREFIX/bin/usb-wakeup-blocker.sh"
    HELPER_BIN="$PREFIX/bin/usb-wakeup-helper"
    CONFIG_DIR="$PREFIX/etc"
    CONFIG_FILE="$CONFIG_DIR/usb-wakeup-blocker.conf"
    LAUNCHD_PLIST="/Library/LaunchDaemons/com.usb-wakeup-blocker.plist"
    BASH_COMPLETION_TARGET="$PREFIX/share/bash-completion/completions/usb-wakeup-blocker"
    ZSH_COMPLETION_TARGET="$PREFIX/share/zsh/site-functions/_usb-wakeup-blocker"

    SOURCE_HELPER="helpers/macos/usb-wakeup-helper.c"
    SOURCE_LAUNCHD="launchd/com.usb-wakeup-blocker.plist"

    for f in "$SOURCE_BIN" "$SOURCE_CONFIG" "$SOURCE_HELPER" "$SOURCE_LAUNCHD" "$SOURCE_BASH_COMPLETION" "$SOURCE_ZSH_COMPLETION"; do
        if [ ! -f "$f" ]; then
            echo "Error: Source file not found: $f" >&2
            exit 1
        fi
    done

    if ! command -v cc >/dev/null 2>&1; then
        echo "Error: C compiler (cc) not found. Install Xcode Command Line Tools:" >&2
        echo "  xcode-select --install" >&2
        exit 1
    fi

    echo "Compiling IOKit helper..."
    cc -framework IOKit -framework CoreFoundation -o /tmp/usb-wakeup-helper "$SOURCE_HELPER"

    ${SUDO} install -d "$PREFIX/bin"
    ${SUDO} install -m755 "$SOURCE_BIN" "$BIN"
    ${SUDO} install -m755 /tmp/usb-wakeup-helper "$HELPER_BIN"
    rm -f /tmp/usb-wakeup-helper

    ${SUDO} install -d "$CONFIG_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        ${SUDO} install -m644 "$SOURCE_CONFIG" "$CONFIG_FILE"
    fi

    ${SUDO} install -m644 "$SOURCE_LAUNCHD" "$LAUNCHD_PLIST"

    ${SUDO} install -d "$(dirname "$BASH_COMPLETION_TARGET")"
    ${SUDO} install -m644 "$SOURCE_BASH_COMPLETION" "$BASH_COMPLETION_TARGET"
    ${SUDO} install -d "$(dirname "$ZSH_COMPLETION_TARGET")"
    ${SUDO} install -m644 "$SOURCE_ZSH_COMPLETION" "$ZSH_COMPLETION_TARGET"

    echo "Installed successfully."
    echo "Configuration file template created at '$CONFIG_FILE'."
    echo "Please edit it to your needs, then load the service with:"
    echo "  sudo launchctl load -w $LAUNCHD_PLIST"
    echo "Shell completions installed for bash and zsh. Restart your shell to load them."
else
    # ===== Linux =====
    PREFIX="/usr"
    BIN="$PREFIX/bin/usb-wakeup-blocker.sh"
    CONFIG_DIR="/etc"
    CONFIG_FILE="$CONFIG_DIR/usb-wakeup-blocker.conf"
    SERVICE="$PREFIX/lib/systemd/system/usb-wakeup-blocker.service"
    UDEV_RULES_TARGET="$CONFIG_DIR/udev/rules.d/99-usb-wakeup-blocker.rules"
    BASH_COMPLETION_TARGET="$PREFIX/share/bash-completion/completions/usb-wakeup-blocker"
    ZSH_COMPLETION_TARGET="$PREFIX/share/zsh/site-functions/_usb-wakeup-blocker"

    SOURCE_SERVICE="systemd/usb-wakeup-blocker.service"
    SOURCE_UDEV_RULES="udev/99-usb-wakeup-blocker.rules"

    for f in "$SOURCE_BIN" "$SOURCE_CONFIG" "$SOURCE_SERVICE" "$SOURCE_UDEV_RULES" "$SOURCE_BASH_COMPLETION" "$SOURCE_ZSH_COMPLETION"; do
        if [ ! -f "$f" ]; then
            echo "Error: Source file not found: $f" >&2
            exit 1
        fi
    done

    ${SUDO} install -Dm755 "$SOURCE_BIN" "$BIN"
    ${SUDO} install -d "$CONFIG_DIR"
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
fi
