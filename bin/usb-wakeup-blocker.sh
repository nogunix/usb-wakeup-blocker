#!/bin/bash
# usb-wakeup-blocker.sh
# Disable USB/ACPI devices from waking up the system (with whitelist support)

# ===== Constants =====
readonly DEFAULT_MODE="mouse"   # mouse / all / combo
readonly VALID_MODES="mouse all combo"

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

# ===== USB/ACPI helper =====
declare -A DEVICE_INFO_CACHE
get_device_info() {
    local device_dir="$1"
    local busnum devnum lsusb_output is_mouse is_keyboard product_name

    if [[ -v "DEVICE_INFO_CACHE[$device_dir]" ]]; then
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
    lsusb_output=$(lsusb -v -s "${busnum}:${devnum}" 2>/dev/null)

    if [[ -z "$lsusb_output" ]]; then
        DEVICE_INFO_CACHE["$device_dir"]="false false (error: lsusb failed)"
        echo "${DEVICE_INFO_CACHE[$device_dir]}"
        return
    fi

    [[ "$lsusb_output" =~ bInterfaceProtocol.*2\ Mouse ]] && is_mouse="true" || is_mouse="false"
    [[ "$lsusb_output" =~ bInterfaceProtocol.*1\ Keyboard ]] && is_keyboard="true" || is_keyboard="false"

    product_name=$(echo "$lsusb_output" | grep "iProduct" | sed -E 's/.*iProduct[[:space:]]+[0-9]+[[:space:]]+//' | head -n 1)
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

    for dir in /sys/bus/usb/devices/*; do
        [[ -f "$dir/power/wakeup" ]] || continue

        read is_mouse is_keyboard product_name < <(get_device_info "$dir")
        local is_whitelisted=false
        for pattern in "${whitelist_patterns[@]}"; do
            [[ "$product_name" == *"$pattern"* ]] && { is_whitelisted=true; break; }
        done

        local disable=false
        if ! $is_whitelisted; then
            case "$mode" in
                all) disable=true ;;
                mouse) [[ "$is_mouse" == "true" ]] && disable=true ;;
                combo) [[ "$is_mouse" == "true" || "$is_keyboard" == "true" ]] && disable=true ;;
            esac
        fi

        local wakeup_file="$dir/power/wakeup"
        local current_state=$(<"$wakeup_file")
        local action="ignore"
        if $disable && [ "$current_state" == "enabled" ]; then
            action="disable"
            ! $dry_run && echo "disabled" > "$wakeup_file"
        elif $is_whitelisted && [ "$current_state" == "disabled" ]; then
            action="enable (whitelisted)"
            ! $dry_run && echo "enabled" > "$wakeup_file"
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

    [[ -f /proc/acpi/wakeup ]] || { $verbose && echo "ACPI management skipped: /proc/acpi/wakeup not found."; return; }

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
            ! $dry_run && echo "$device" > /proc/acpi/wakeup
        fi

        $verbose && printf "ACPI Device: %-10s | Current: %-8s | Desired: %-8s | Action: %s\n" \
            "$device" "$status" "$desired_state" "$action"
    done < <(tail -n +2 /proc/acpi/wakeup)
}

# ===== main =====
main() {
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
            -w) shift; whitelist_patterns+=("$1") ;;
            -p) shift; acpi_whitelist_patterns+=("$1") ;;
            -d) dry_run=true ;;
            -v) verbose=true ;;
            *) error "Unknown option: $1" ;;
        esac
        shift
    done

    member "$mode" $VALID_MODES || { warning "Invalid mode: $mode, using default ($DEFAULT_MODE)"; mode="$DEFAULT_MODE"; }

    process_usb_devices "$mode" "$dry_run" "$verbose" "${whitelist_patterns[@]}"
    process_acpi_devices "$dry_run" "$verbose" "${acpi_whitelist_patterns[@]}"

    $verbose && { echo "--------------------------"; echo "Done."; }
}

main "$@"