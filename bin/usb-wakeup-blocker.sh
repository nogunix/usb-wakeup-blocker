#!/usr/bin/env bash
# usb-wakeup-blocker.sh
# Disable USB devices from waking up the system (with whitelist support)

# If not running under bash, re-exec with bash (POSIX-safe)
[ -n "${BASH_VERSION:-}" ] || exec /usr/bin/env bash "$0" "$@"

set -euo pipefail
IFS=$'\n\t'

set -euo pipefail

# ===== Constants =====
readonly DEFAULT_MODE="mouse"   # mouse / all / combo
readonly -a VALID_MODES=(mouse all combo)

# ===== Test-overridable paths =====
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
               Use the "Product" field from -v output.
  -d           Dry run (show actions but do not apply changes).
  -v           Verbose output.
  -h           Show this help.

Examples:
  usb-wakeup-blocker.sh -c -w "My Keyboard"
  usb-wakeup-blocker.sh -m -w "USB Receiver"
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

# ===== Table formatting (for -v) =====
# Keep column widths centralized
HEADER_FORMAT="%-15s | %-28s | %-28s | %-5s | %-8s | %-s\n"

# ===== USB helper =====
# Return value of get_device_info (tab-separated):
#   is_mouse \t is_keyboard \t product_name \t vendor_name
# - product_name … Product name used for the -w option (from sysfs's product or lsusb -v's iProduct)
# - vendor_name  … Vendor name from the end of the idVendor line in `lsusb -v`, or sysfs manufacturer
declare -A DEVICE_INFO_CACHE
get_device_info() {
    local device_dir="$1"
    local busnum devnum lsusb_v_output is_mouse is_keyboard product_name vendor_name
    is_mouse="false"; is_keyboard="false"; product_name="(unknown product)"; vendor_name=""

    if [[ -v DEVICE_INFO_CACHE["$device_dir"] ]]; then
        echo "${DEVICE_INFO_CACHE[$device_dir]}"
        return
    fi

    # Prefer sysfs product for -w matching
    if [[ -r "$device_dir/product" ]]; then
        product_name="$(<"$device_dir/product")"
        [[ -n "$product_name" ]] || product_name="(unknown product)"
    fi

    if [[ -f "$device_dir/busnum" && -f "$device_dir/devnum" ]]; then
        busnum="$(<"$device_dir/busnum")"
        devnum="$(<"$device_dir/devnum")"
    fi

    if is_function_available lsusb; then
        if [[ -n "${busnum:-}" && -n "${devnum:-}" ]]; then
            lsusb_v_output="$(lsusb -v -s "${busnum}:${devnum}" 2>/dev/null || true)"
        else
            if [[ -r "$device_dir/idVendor" && -r "$device_dir/idProduct" ]]; then
                local vid pid
                vid="$(<"$device_dir/idVendor")"
                pid="$(<"$device_dir/idProduct")"
                lsusb_v_output="$(lsusb -v -d "${vid}:${pid}" 2>/dev/null || true)"
            fi
        fi
    else
        lsusb_v_output=""
    fi

    # Detect Mouse/Keyboard and extract iProduct/vendor
    if [[ -n "$lsusb_v_output" ]]; then
        # --- Mouse / Keyboard detection ---
        if grep -qiE 'Interface.*Keyboard|HID.*Keyboard|Protocol.*Keyboard|Protocol.*\(Keyboard\)' <<<"$lsusb_v_output"; then
            is_keyboard="true"
        fi
        if grep -qiE 'Interface.*Mouse|HID.*Mouse|Protocol.*Mouse|Protocol.*\(Mouse\)' <<<"$lsusb_v_output"; then
            is_mouse="true"
        fi

        # --- Extract only the product name from iProduct ---
        local ip
        ip="$(sed -nE 's/^[[:space:]]*iProduct[[:space:]]+[0-9]+[[:space:]]+(.+)$/\1/p' <<<"$lsusb_v_output" | head -n1)"
        [[ -n "$ip" ]] && product_name="$ip"

        # --- Extract only the vendor name from idVendor ---
        local iv
        iv="$(sed -nE 's/^[[:space:]]*idVendor[[:space:]]+0x[0-9A-Fa-f]+[[:space:]]+(.+)$/\1/p' <<<"$lsusb_v_output" | head -n1)"
        [[ -n "$iv" ]] && vendor_name="$iv"
    fi

    # Fallback to sysfs manufacturer if vendor name is not available
    if [[ -z "$vendor_name" && -r "$device_dir/manufacturer" ]]; then
        vendor_name="$(<"$device_dir/manufacturer")"
    fi
    [[ -n "$vendor_name" ]] || vendor_name="(unknown vendor)"
    [[ -n "$product_name" ]] || product_name="(unknown product)"

    # Join with a literal tab character ($'\t')
    DEVICE_INFO_CACHE["$device_dir"]="${is_mouse}"$'\t'"${is_keyboard}"$'\t'"${product_name}"$'\t'"${vendor_name}"
    echo "${DEVICE_INFO_CACHE[$device_dir]}"
}

# Generate a table border line matching the header width
print_line() {
    local line
    # We intentionally use a variable as the printf format to centralize column widths.
    # shellcheck disable=SC2059
    printf -v line "$HEADER_FORMAT" "Device" "Product (for -w)" "Vendor" "Mouse" "Keyboard" "Action"
    printf '%*s\n' "${#line}" '' | tr ' ' '-'
}

process_usb_devices() {
    local mode=$1 dry_run=$2 verbose=$3
    shift 3
    local whitelist_patterns=("$@")

    if $verbose; then
        echo "--- USB Wakeup Management ---"
        echo "Mode: $mode"
        echo "Dry Run: $dry_run"
        # Table header
        print_line
        # shellcheck disable=SC2059
        printf "$HEADER_FORMAT" "Device" "Product (for -w)" "Vendor" "Mouse" "Keyboard" "Action"
        print_line
    fi

    for dir in $USB_DEVICES_GLOB; do
        [[ -f "$dir/power/wakeup" ]] || continue

        local is_mouse is_keyboard product_name vendor_name
        IFS=$'\t' read -r is_mouse is_keyboard product_name vendor_name < <(get_device_info "$dir")

        # Match -w option only against product_name (separate from lsusb vendor name)
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
        local current_state action="ignore"
        current_state="$(<"$wakeup_file")"

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

        if $verbose; then
            printf "%-15s | %-28s | %-28s | %-5s | %-8s | %-s\n" \
                "$(basename "$dir")" \
                "$product_name" \
                "$vendor_name" \
                "$is_mouse" \
                "$is_keyboard" \
                "$action"
        fi
    done

    if $verbose; then
        print_line 94
        echo "Done."
    fi
}

# ===== main =====
main() {
    # Allow tests to skip root check
    if [[ "${SKIP_ROOT_CHECK:-0}" != "1" ]]; then
        require_root
    fi

    # --- Set defaults BEFORE loading config (avoid set -u unbound vars) ---
    local mode="$DEFAULT_MODE"
    local dry_run=false
    local verbose=false
    local -a whitelist_patterns=()

    # --- Load config file (override defaults) ---
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        mode="${MODE:-$mode}"
        dry_run=${DRY_RUN:-$dry_run}
        verbose=${VERBOSE:-$verbose}

    # Reset and ingest from config (string or array)
    whitelist_patterns=()

    # WHITELIST_PATTERNS is the key from the config file (uppercase).
    # The lowercase whitelist_patterns is an internal buffer (a different variable).
    # shellcheck disable=SC2153
    if declare -p WHITELIST_PATTERNS >/dev/null 2>&1; then
        # Check if it is defined as an array
        # shellcheck disable=SC2153
        if declare -p WHITELIST_PATTERNS 2>/dev/null | grep -q '^declare \-a '; then
            # If it's an array
            # shellcheck disable=SC2153
            { whitelist_patterns+=("${WHITELIST_PATTERNS[@]}"); }
        else
            # If it's a string (space-separated)
            # shellcheck disable=SC2153
            { read -r -a _tmp <<<"${WHITELIST_PATTERNS}"; }
            whitelist_patterns+=("${_tmp[@]}")
            unset _tmp
        fi
    fi

    fi
    # --- Parse command-line arguments (override config) ---
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
    return 0
}

# --- call main only when executed directly (not when sourced by tests) ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
