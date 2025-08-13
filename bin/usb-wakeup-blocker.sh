#!/usr/bin/env bash
# usb-wakeup-blocker.sh
# Disable USB/ACPI devices from waking up the system (with whitelist support)

# ===== Constants =====
readonly DEFAULT_MODE="mouse"   # mouse / all / combo
readonly -a VALID_MODES=(mouse all combo)

# ===== Test-overridable paths =====
# For tests, set:
#   export ACPI_WAKEUP_FILE="/tmp/mock_proc_acpi_wakeup"
#   export USB_DEVICES_GLOB="/tmp/mock_sys_bus_usb/devices/*"
#   export ACPI_TOGGLE_LOG_FILE="/tmp/mock_proc_acpi_wakeup.writes.log"
ACPI_WAKEUP_FILE="${ACPI_WAKEUP_FILE:-/proc/acpi/wakeup}"
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
  -p <name>    Whitelist ACPI device by name (multiple allowed).
  -d           Dry run (show actions but do not apply changes).
  -v           Verbose output.
  -h           Show this help.

Examples:
  usb-wakeup-blocker.sh -c -w "My Keyboard" -p "LID"
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

# ===== USB/ACPI helper =====
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

process_acpi_devices() {
    local dry_run=$1 verbose=$2
    shift 2
    local acpi_whitelist_patterns=("$@")

    [[ ${#acpi_whitelist_patterns[@]} -eq 0 ]] && return

    $verbose && {
        echo
        echo "--- ACPI Wakeup Management ---"
        echo "------------------------------"
    }

    if [[ ! -f "$ACPI_WAKEUP_FILE" ]]; then
        $verbose && echo "ACPI management skipped: $ACPI_WAKEUP_FILE not found."
        return
    fi

    while read -r device s_state status _; do
        status=${status#\*}
        local is_whitelisted=false
        for pattern in "${acpi_whitelist_patterns[@]}"; do
            [[ "$device" == *"$pattern"* ]] && { is_whitelisted=true; break; }
        done

        local desired_state="disabled"
        $is_whitelisted && desired_state="enabled"

        local action="No change needed"
        if [[ "$status" != "$desired_state" ]]; then
            action="Toggling state"
            if ! $dry_run; then
                if ! echo "$device" > "$ACPI_WAKEUP_FILE" 2>/dev/null; then
                    action="Toggle (failed)"
                    $verbose && warning "ACPI toggle failed: $device"
                else
                    # Optional: test-only logging when ACPI_TOGGLE_LOG_FILE is set
                    if [[ -n "${ACPI_TOGGLE_LOG_FILE:-}" ]]; then
                        printf '%s\n' "$device" >> "$ACPI_TOGGLE_LOG_FILE"
                    fi
                fi
            fi
        fi

        $verbose && printf "ACPI Device: %-10s | Current: %-8s | Desired: %-8s | Action: %s\n" \
            "$device" "$status" "$desired_state" "$action"
    done < <(tail -n +2 "$ACPI_WAKEUP_FILE")
}

# ===== main =====
main() {
    # Allow tests to skip root check
    if [[ "${SKIP_ROOT_CHECK:-0}" != "1" ]]; then
        require_root
    fi

    local mode="$DEFAULT_MODE"
    local dry_run=false
    local verbose=false
    local -a whitelist_patterns=()
    local -a acpi_whitelist_patterns=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -a) mode="all" ;;
            -m) mode="mouse" ;;
            -c) mode="combo" ;;
            -w)
                shift || error "-w requires an argument"
                [[ -n "${1:-}" ]] || error "-w requires a non-empty argument"
                whitelist_patterns+=("$1")
                ;;
            -p)
                shift || error "-p requires an argument"
                [[ -n "${1:-}" ]] || error "-p requires a non-empty argument"
                acpi_whitelist_patterns+=("$1")
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
    process_acpi_devices "$dry_run" "$verbose" "${acpi_whitelist_patterns[@]}"

    $verbose && { echo "--------------------------"; echo "Done."; }
    return 0
}

# --- call main only when executed directly (not when sourced by tests) ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
