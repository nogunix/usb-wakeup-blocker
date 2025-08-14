#!/usr/bin/env bash
# usb-wakeup-blocker.sh
# Disable USB devices from waking up the system (with whitelist support)

# ===== Constants =====
readonly DEFAULT_MODE="mouse"   # mouse / all / combo
readonly -a VALID_MODES=(mouse all combo)

# ===== Test-overridable paths =====
# For tests, set:
#   export USB_DEVICES_GLOB="/tmp/mock_sys_bus_usb/devices/*"
CONFIG_FILE="${CONFIG_FILE:-/etc/usb-wakeup-blocker.conf}"
USB_DEVICES_GLOB="${USB_DEVICES_GLOB:-/sys/bus/usb/devices/*}"

# Safer globbing: if no match, expand to empty (not literal)
shopt -s nullglob

# ===== Utility functions =====
error() { echo "ERROR: $*" >&2; exit 1; }
warning() { echo "WARNING: $*" >&2; }
internal_error() { echo "INTERNAL ERROR: $*" >&2; exit 1; }
is_function_available() { type "$1" >/dev/null 2>&1; }

usage() {
    cat <<'EOF'
Usage: usb-wakeup-blocker.sh [OPTIONS]

Options:
  -a           Block all USB devices from waking the system.
  -m           Block only mice (default).
  -c           Block both mice and keyboards.
  -w <name>    Whitelist USB device by product name (multiple allowed).
  -d           Dry run (show actions but do not apply changes).
  -v           Verbose output.
  -h           Show this help.

Examples:
  usb-wakeup-blocker.sh -c -w "My Keyboard"
EOF
}

member() {
    local elt=$1; shift
    local x
    for x in "$@"; do
        [[ "$x" == "$elt" ]] && return 0
    done
    return 1
}

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        error "This script must be run as root."
    fi
}

safe_write() {
    # safe_write <value> <file> <verbose:true|false>
    local value=$1 file=$2 verbose=$3
    if [[ ! -w "$file" ]]; then
        $verbose && warning "Not writable: $file"
        return 1
    fi
    if ! printf '%s\n' "$value" > "$file"; then
        $verbose && warning "Write failed: $file"
        return 1
    fi
    return 0
}

# ===== USB helper =====
declare -A DEVICE_INFO_CACHE
get_device_info() {
    local device_dir="$1"
    local busnum devnum lsusb_output is_mouse is_keyboard product_name

    if [[ -v DEVICE_INFO_CACHE["$device_dir"] ]]; then
        echo "${DEVICE_INFO_CACHE[$device_dir]}"
        return
    fi

    if [[ ! -f "$device_dir/busnum" || ! -f "$device_dir/devnum" ]]; then
        DEVICE_INFO_CACHE["$device_dir"]="false false (error: no bus/dev num)"
        echo "${DEVICE_INFO_CACHE[$device_dir]}"
        return
    fi

    busnum=$(<"$device_dir/busnum")
    devnum=$(<"$device_dir/devnum")

    if is_function_available lsusb; then
        lsusb_output=$(lsusb -v -s "${busnum}:${devnum}" 2>/dev/null || true)
    else
        lsusb_output=""
    fi

    if [[ -z "$lsusb_output" ]]; then
        DEVICE_INFO_CACHE["$device_dir"]="false false (unknown product)"
        echo "${DEVICE_INFO_CACHE[$device_dir]}"
        return
    fi

    [[ "$lsusb_output" =~ bInterfaceProtocol.*2\ Mouse ]] && is_mouse="true" || is_mouse="false"
    [[ "$lsusb_output" =~ bInterfaceProtocol.*1\ Keyboard ]] && is_keyboard="true" || is_keyboard="false"

    product_name=$(echo "$lsusb_output" | grep -m1 -E "^[[:space:]]*iProduct[[:space:]]+[0-9]+" | sed -E 's/.*iProduct[[:space:]]+[0-9]+[[:space:]]+//')
    [[ -z "$product_name" ]] && product_name="(unknown product)"

    DEVICE_INFO_CACHE["$device_dir"]="$is_mouse $is_keyboard $product_name"
    echo "${DEVICE_INFO_CACHE[$device_dir]}"
}

process_usb_devices() {
    local mode=$1 dry_run=$2 verbose=$3
    shift 3
    local whitelist_patterns=("$@")

    $verbose && {
        echo "--- USB Wakeup Management ---"
        echo "Mode: $mode"
        echo "Dry Run: $dry_run"
        echo "-----------------------------"
    }

    for dir in $USB_DEVICES_GLOB; do
        [[ -f "$dir/power/wakeup" ]] || continue

        read -r is_mouse is_keyboard product_name < <(get_device_info "$dir")
        local is_whitelisted=false
        for pattern in "${whitelist_patterns[@]}"; do
            [[ "$product_name" == *"$pattern"* ]] && { is_whitelisted=true; break; }
        done

        local disable=false
        if ! $is_whitelisted; then
            case "$mode" in
                all)   disable=true ;;
                mouse) [[ "$is_mouse" == "true" ]] && disable=true ;;
                combo) [[ "$is_mouse" == "true" || "$is_keyboard" == "true" ]] && disable=true ;;
            esac
        fi

        local wakeup_file="$dir/power/wakeup"
        local current_state
        current_state=$(<"$wakeup_file")
        local action="ignore"

        if $disable && [[ "$current_state" == "enabled" ]]; then
            action="disable"
            if ! $dry_run; then
                safe_write "disabled" "$wakeup_file" "$verbose" || action="disable (failed)"
            fi
        elif $is_whitelisted && [[ "$current_state" == "disabled" ]]; then
            action="enable (whitelisted)"
            if ! $dry_run; then
                safe_write "enabled" "$wakeup_file" "$verbose" || action="enable (failed)"
            fi
        fi

        $verbose && printf "Device: %-15s | Product: %-25s | Mouse: %-5s | Keyboard: %-5s | Action: %s\n" \
            "$(basename "$dir")" "$product_name" "$is_mouse" "$is_keyboard" "$action"
    done
}

# ===== main =====
main() {
    # Allow tests to skip root check
    if [[ "${SKIP_ROOT_CHECK:-0}" != "1" ]]; then
        require_root
    fi

    # --- Load config file for default values ---
    local mode="$DEFAULT_MODE"
    local dry_run=false
    local verbose=false
    local -a whitelist_patterns=()

    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        # Config file can set: MODE, DRY_RUN, VERBOSE, WHITELIST_PATTERNS (as array)
        mode="${MODE:-$mode}"
        dry_run=${DRY_RUN:-$dry_run}
        verbose=${VERBOSE:-$verbose}
        whitelist_patterns=("${WHITELIST_PATTERNS[@]:-}")
    fi

    # --- Parse command-line arguments (they override config file values) ---
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -a) mode="all" ;;
            -m) mode="mouse" ;;
            -c) mode="combo" ;;
            -w)
                shift || error "-w requires an argument"
                [[ -n "${1:-}" ]] || error "-w requires a non-empty argument"
                whitelist_patterns+=("$1") # Append to patterns from config
                ;;
            -d) dry_run=true ;;
            -v) verbose=true ;;
            *) error "Unknown option: $1" ;;
        esac
        shift
    done

    if ! member "$mode" "${VALID_MODES[@]}"; then
        warning "Invalid mode: $mode, using default ($DEFAULT_MODE)"
        mode="$DEFAULT_MODE"
    fi

    process_usb_devices "$mode" "$dry_run" "$verbose" "${whitelist_patterns[@]}"

    $verbose && { echo "--------------------------"; echo "Done."; }
    return 0
}

# --- call main only when executed directly (not when sourced by tests) ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi