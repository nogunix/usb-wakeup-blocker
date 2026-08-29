#!/usr/bin/env bash

# usb-wakeup-blocker.sh — Disable USB devices from waking up the system (with whitelist support)
#
# MIT License
#
# Copyright (c) 2025 Masaharu Noguchi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Re-exec with bash if needed (POSIX-safe)
[ -n "${BASH_VERSION:-}" ] || exec /usr/bin/env bash "$0" "$@"

# Require bash 4+ for associative arrays
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  for _candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    # shellcheck disable=SC2016
    if [[ -x "$_candidate" ]] && "$_candidate" -c '[[ ${BASH_VERSINFO[0]} -ge 4 ]]' 2>/dev/null; then
      exec "$_candidate" "$0" "$@"
    fi
  done
  echo "ERROR: bash 4+ is required. On macOS, install it with: brew install bash" >&2
  exit 1
fi

set -euo pipefail
IFS=$'\n\t'

# ===== Constants =====
readonly DEFAULT_MODE="mouse"               # mouse / all / combo
readonly -a VALID_MODES=(mouse all combo)

# ===== Platform detection =====
PLATFORM="${PLATFORM:-$(uname -s)}"

# ===== Test-overridable paths =====
if [[ "$PLATFORM" == "Darwin" ]]; then
  CONFIG_FILE="${CONFIG_FILE:-/usr/local/etc/usb-wakeup-blocker.conf}"
  USB_WAKEUP_HELPER="${USB_WAKEUP_HELPER:-/usr/local/bin/usb-wakeup-helper}"
else
  CONFIG_FILE="${CONFIG_FILE:-/etc/usb-wakeup-blocker.conf}"
  USB_DEVICES_GLOB="${USB_DEVICES_GLOB:-/sys/bus/usb/devices/*}"
fi

# Safer globbing: if no match, expand to empty (not literal)
shopt -s nullglob

# ===== Utility functions =====
error()           { echo "ERROR: $*" >&2; exit 1; }
warning()         { echo "WARNING: $*" >&2; }
internal_error()  { echo "INTERNAL ERROR: $*" >&2; exit 1; }
is_function_available() { type "$1" >/dev/null 2>&1; }

usage() {
  cat <<EOF
Usage: usb-wakeup-blocker.sh [OPTIONS]

Options:
  -a          Block all USB devices from waking the system.
  -m          Block only mice (default).
  -c          Block both mice and keyboards.
  -w          Whitelist USB device by product name (multiple allowed). Use the "Product" field from -v/--list output.
  -d          Dry run (show actions but do not apply changes).
  -v          Verbose output.
  -l          List current wakeup status of all USB devices.
  -p          Path to a specific USB device in sysfs (Linux) or location ID (macOS).
  --daemon    (macOS only) Run as persistent daemon. Disables wakeup before each sleep.
  -h          Show this help.

Examples:
  usb-wakeup-blocker.sh -c -w "My Keyboard"
  usb-wakeup-blocker.sh -m -w "USB Receiver"
  usb-wakeup-blocker.sh -l
  usb-wakeup-blocker.sh --daemon          # macOS: run as sleep-aware daemon
EOF
}

member() {
  local elt=$1; shift
  local x
  for x in "$@"; do [[ "$x" == "$elt" ]] && return 0; done
  return 1
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    error "This script must be run as root."
  fi
}

safe_write() {
  # safe_write <value> <file> <verbose-bool>
  local value=$1 file=$2 verbose=$3
  if [[ ! -w "$file" ]]; then $verbose && warning "Not writable: $file"; return 1; fi
  if ! printf '%s\n' "$value" > "$file"; then $verbose && warning "Write failed: $file"; return 1; fi
  return 0
}

# ===== USB helper =====
# Return value of get_device_info (tab-separated):
# is_mouse \t is_keyboard \t product_name \t vendor_name
# - product_name … Product name used for the -w option (from sysfs's product or lsusb -v's iProduct)
# - vendor_name … Vendor name from the end of the idVendor line in `lsusb -v`, or sysfs manufacturer
declare -A DEVICE_INFO_CACHE
get_device_info() {
  local device_dir="$1"
  local busnum devnum lsusb_v_output is_mouse is_keyboard product_name vendor_name

  is_mouse="false"; is_keyboard="false"; product_name="(unknown product)"; vendor_name=""

  if [[ -v DEVICE_INFO_CACHE["$device_dir"] ]]; then
    echo "${DEVICE_INFO_CACHE[$device_dir]}"
    return
  fi

  # 1) Try sysfs first (fast and often sufficient)
  if [[ -r "$device_dir/product" ]]; then
    product_name="$(<"$device_dir/product")"
    [[ -n "$product_name" ]] || product_name="(unknown product)"
  fi
  if [[ -r "$device_dir/manufacturer" ]]; then
    vendor_name="$(<"$device_dir/manufacturer")"
  fi

  # Check interfaces for HID class/protocol
  for intf in "$device_dir"/*:*; do
    [[ -d "$intf" ]] || continue
    if [[ -r "$intf/bInterfaceClass" && -r "$intf/bInterfaceProtocol" ]]; then
      local class protocol
      class="$(<"$intf/bInterfaceClass")"
      protocol="$(<"$intf/bInterfaceProtocol")"
      # Class 03 = HID, Protocol 01 = Keyboard, 02 = Mouse
      if [[ "$class" == "03" ]]; then
        [[ "$protocol" == "01" ]] && is_keyboard="true"
        [[ "$protocol" == "02" ]] && is_mouse="true"
      fi
    fi
  done

  # 2) Fallback to lsusb -v for more detailed detection if needed
  # We only call lsusb if we haven't identified both or if product/vendor is still missing
  if [[ "$is_mouse" == "false" || "$is_keyboard" == "false" || "$product_name" == "(unknown product)" ]]; then
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
    fi

    if [[ -n "${lsusb_v_output:-}" ]]; then
      # Detect Mouse/Keyboard if not already found via sysfs
      if [[ "$is_keyboard" == "false" ]] && grep -qiE 'Interface.*Keyboard|HID.*Keyboard|Protocol.*Keyboard|Protocol.*\(Keyboard\)' <<<"$lsusb_v_output"; then
        is_keyboard="true"
      fi
      if [[ "$is_mouse" == "false" ]] && grep -qiE 'Interface.*Mouse|HID.*Mouse|Protocol.*Mouse|Protocol.*\(Mouse\)' <<<"$lsusb_v_output"; then
        is_mouse="true"
      fi
      # Extract only the product name from iProduct if missing
      if [[ "$product_name" == "(unknown product)" ]]; then
        local ip
        ip="$(sed -nE 's/^[[:space:]]*iProduct[[:space:]]+[0-9]+[[:space:]]+(.+)$/\1/p' <<<"$lsusb_v_output" | head -n1)"
        [[ -n "$ip" ]] && product_name="$ip"
      fi
      # Extract only the vendor name from idVendor if missing
      if [[ -z "$vendor_name" ]]; then
        local iv
        iv="$(sed -nE 's/^[[:space:]]*idVendor[[:space:]]+0x[0-9A-Fa-f]+[[:space:]]+(.+)$/\1/p' <<<"$lsusb_v_output" | head -n1)"
        [[ -n "$iv" ]] && vendor_name="$iv"
      fi
    fi
  fi

  [[ -n "$vendor_name" ]]  || vendor_name="(unknown vendor)"
  [[ -n "$product_name" ]] || product_name="(unknown product)"

  # Join with a literal tab character ($'\t')
  DEVICE_INFO_CACHE["$device_dir"]="${is_mouse}"$'\t'"${is_keyboard}"$'\t'"${product_name}"$'\t'"${vendor_name}"
  echo "${DEVICE_INFO_CACHE[$device_dir]}"
}

# ===== macOS USB helpers =====
declare -A MACOS_DEVICE_INFO_CACHE
declare -A MACOS_INTF_MOUSE
declare -A MACOS_INTF_KEYBOARD

macos_parse_interfaces() {
  local line class proto cur_loc
  cur_loc=""; class=""; proto=""

  _macos_flush_intf() {
    if [[ -n "$cur_loc" && "$class" == "3" ]]; then
      [[ "$proto" == "1" ]] && MACOS_INTF_KEYBOARD["$cur_loc"]="true"
      [[ "$proto" == "2" ]] && MACOS_INTF_MOUSE["$cur_loc"]="true"
    fi
    cur_loc=""; class=""; proto=""
  }

  while IFS= read -r line; do
    if [[ "$line" =~ ^\+\-o ]]; then
      _macos_flush_intf
    elif [[ "$line" =~ \"locationID\"[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
      cur_loc="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"bInterfaceClass\"[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
      class="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"bInterfaceProtocol\"[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
      proto="${BASH_REMATCH[1]}"
    fi
  done < <(ioreg -r -c IOUSBHostInterface -d1 -l -w0 2>/dev/null)
  _macos_flush_intf
  unset -f _macos_flush_intf
}

macos_get_device_info() {
  local location_id="$1"
  if [[ -v MACOS_DEVICE_INFO_CACHE["$location_id"] ]]; then
    echo "${MACOS_DEVICE_INFO_CACHE[$location_id]}"
    return
  fi
  local is_mouse="${MACOS_INTF_MOUSE[$location_id]:-false}"
  local is_keyboard="${MACOS_INTF_KEYBOARD[$location_id]:-false}"
  MACOS_DEVICE_INFO_CACHE["$location_id"]="${is_mouse}"$'\t'"${is_keyboard}"
  echo "${MACOS_DEVICE_INFO_CACHE[$location_id]}"
}

macos_set_wakeup() {
  local location_id="$1" value="$2" verbose="$3"
  if [[ ! -x "$USB_WAKEUP_HELPER" ]]; then
    $verbose && warning "Helper not found: $USB_WAKEUP_HELPER"
    return 1
  fi
  if ! "$USB_WAKEUP_HELPER" set "$location_id" "$value" 2>/dev/null; then
    $verbose && warning "Failed to set wakeup for device $location_id"
    return 1
  fi
  return 0
}

macos_get_wakeup_status() {
  local location_id="$1"
  if [[ -x "$USB_WAKEUP_HELPER" ]]; then
    "$USB_WAKEUP_HELPER" get "$location_id" 2>/dev/null
  else
    echo "default"
  fi
}

process_usb_devices_macos() {
  local mode=$1 dry_run=$2 verbose=$3; shift 3
  local whitelist_patterns=("$@")

  macos_parse_interfaces

  if $verbose; then
    echo "--- USB Wakeup Management (macOS) ---"
    echo "Mode: $mode"
    echo "Dry Run: $dry_run"
    print_line
    # shellcheck disable=SC2059
    printf "$HEADER_FORMAT" "Location ID" "Product (for -w)" "Vendor" "Mouse" "Keyboard" "Action"
    print_line
  fi

  local line cur_product="" cur_vendor="" cur_loc=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^\+\-o ]]; then
      if [[ -n "$cur_loc" ]] && \
         { [[ -z "${MACOS_SINGLE_LOCATION:-}" ]] || [[ "$cur_loc" == "$MACOS_SINGLE_LOCATION" ]]; }; then
        macos_process_single_device "$cur_loc" "$cur_product" "$cur_vendor" \
          "$mode" "$dry_run" "$verbose" "${whitelist_patterns[@]}"
      fi
      cur_product=""
      cur_vendor=""
      cur_loc=""
    fi
    if [[ "$line" =~ \"locationID\"[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
      cur_loc="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"USB\ Product\ Name\"[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      cur_product="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"USB\ Vendor\ Name\"[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      cur_vendor="${BASH_REMATCH[1]}"
    fi
  done < <(ioreg -r -c IOUSBHostDevice -d1 -l -w0 2>/dev/null)

  if [[ -n "$cur_loc" ]] && \
     { [[ -z "${MACOS_SINGLE_LOCATION:-}" ]] || [[ "$cur_loc" == "$MACOS_SINGLE_LOCATION" ]]; }; then
    macos_process_single_device "$cur_loc" "$cur_product" "$cur_vendor" \
      "$mode" "$dry_run" "$verbose" "${whitelist_patterns[@]}"
  fi

  if $verbose; then
    print_line
    echo "Done."
  fi
}

macos_process_single_device() {
  local location_id="$1" product_name="$2" vendor_name="$3"
  local mode="$4" dry_run="$5" verbose="$6"; shift 6
  local whitelist_patterns=("$@")

  [[ -n "$product_name" ]] || product_name="(unknown product)"
  [[ -n "$vendor_name" ]]  || vendor_name="(unknown vendor)"

  local is_mouse is_keyboard
  IFS=$'\t' read -r is_mouse is_keyboard < <(macos_get_device_info "$location_id")

  local is_whitelisted=false
  for pattern in "${whitelist_patterns[@]}"; do
    [[ "$product_name" == *"$pattern"* ]] && { is_whitelisted=true; break; }
  done

  local disable=false
  if ! $is_whitelisted; then
    case "$mode" in
      all)   disable=true ;;
      mouse) [[ "$is_mouse" == "true"    ]] && disable=true ;;
      combo) [[ "$is_mouse" == "true" || "$is_keyboard" == "true" ]] && disable=true ;;
    esac
  fi

  local current_state action="ignore"
  current_state="$(macos_get_wakeup_status "$location_id")"

  if $disable && [[ "$current_state" != "disabled" ]]; then
    action="disable"
    if ! $dry_run; then
      macos_set_wakeup "$location_id" "disabled" "$verbose" || action="disable (failed)"
    fi
  elif $is_whitelisted && [[ "$current_state" == "disabled" ]]; then
    action="enable (whitelisted)"
    if ! $dry_run; then
      macos_set_wakeup "$location_id" "enabled" "$verbose" || action="enable (failed)"
    fi
  fi

  local loc_hex
  loc_hex=$(printf "0x%08x" "$location_id")
  if $verbose; then
    printf "%-15s | %-28s | %-28s | %-5s | %-8s | %-s\n" \
      "$loc_hex" "$product_name" "$vendor_name" "$is_mouse" "$is_keyboard" "$action"
  fi
}

# ===== Table formatting (for -v) =====
# Keep column widths centralized
readonly HEADER_FORMAT="%-15s | %-28s | %-28s | %-5s | %-8s | %-s\n"

# Generate a table border line matching the header width
print_line() {
  local line
  # We intentionally use a variable as the printf format to centralize column widths.
  # shellcheck disable=SC2059
  printf -v line "$HEADER_FORMAT" "Device" "Product (for -w)" "Vendor" "Mouse" "Keyboard" "Action"
  printf '%*s\n' "${#line}" '' | tr ' ' '-'
}

process_usb_devices() {
  local mode=$1 dry_run=$2 verbose=$3; shift 3
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

  # Expand glob if it contains wildcards, otherwise use as-is (for -p)
  local dirs
  if [[ "$USB_DEVICES_GLOB" == *"*"* ]]; then
    # shellcheck disable=SC2206
    dirs=( $USB_DEVICES_GLOB )
  else
    dirs=( "$USB_DEVICES_GLOB" )
  fi

  for dir in "${dirs[@]}"; do
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
        mouse) [[ "$is_mouse" == "true"    ]] && disable=true ;;
        combo) [[ "$is_mouse" == "true" || "$is_keyboard" == "true" ]] && disable=true ;;
      esac
    fi

    local wakeup_file="$dir/power/wakeup"
    local current_state action="ignore"
    current_state="$(<"$wakeup_file")"

    if $disable && [[ "$current_state" == "enabled" ]]; then
      action="disable"
      if ! $dry_run; then safe_write "disabled" "$wakeup_file" "$verbose" || action="disable (failed)"; fi
    elif $is_whitelisted && [[ "$current_state" == "disabled" ]]; then
      action="enable (whitelisted)"
      if ! $dry_run; then safe_write "enabled" "$wakeup_file" "$verbose" || action="enable (failed)"; fi
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
    print_line
    echo "Done."
  fi
}

macos_collect_blocked_ids() {
  local mode=$1; shift
  local whitelist_patterns=("$@")
  local -a blocked_ids=()

  macos_parse_interfaces

  local line cur_loc=""
  local cur_product=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^\+\-o ]]; then
      if [[ -n "$cur_loc" ]]; then
        local is_mouse is_keyboard
        IFS=$'\t' read -r is_mouse is_keyboard < <(macos_get_device_info "$cur_loc")
        local is_whitelisted=false
        for pattern in "${whitelist_patterns[@]}"; do
          [[ "$cur_product" == *"$pattern"* ]] && { is_whitelisted=true; break; }
        done
        if ! $is_whitelisted; then
          local disable=false
          case "$mode" in
            all)   disable=true ;;
            mouse) [[ "$is_mouse" == "true"    ]] && disable=true ;;
            combo) [[ "$is_mouse" == "true" || "$is_keyboard" == "true" ]] && disable=true ;;
          esac
          $disable && blocked_ids+=("$cur_loc")
        fi
      fi
      cur_loc=""
      cur_product=""
    fi
    if [[ "$line" =~ \"locationID\"[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
      cur_loc="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"USB\ Product\ Name\"[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      cur_product="${BASH_REMATCH[1]}"
    fi
  done < <(ioreg -r -c IOUSBHostDevice -d1 -l -w0 2>/dev/null)

  if [[ -n "$cur_loc" ]]; then
    local is_mouse is_keyboard
    IFS=$'\t' read -r is_mouse is_keyboard < <(macos_get_device_info "$cur_loc")
    local is_whitelisted=false
    for pattern in "${whitelist_patterns[@]}"; do
      [[ "$cur_product" == *"$pattern"* ]] && { is_whitelisted=true; break; }
    done
    if ! $is_whitelisted; then
      local disable=false
      case "$mode" in
        all)   disable=true ;;
        mouse) [[ "$is_mouse" == "true"    ]] && disable=true ;;
        combo) [[ "$is_mouse" == "true" || "$is_keyboard" == "true" ]] && disable=true ;;
      esac
      $disable && blocked_ids+=("$cur_loc")
    fi
  fi

  echo "${blocked_ids[@]}"
}

macos_start_daemon() {
  local mode=$1 verbose=$2; shift 2
  local whitelist_patterns=("$@")

  if [[ ! -x "$USB_WAKEUP_HELPER" ]]; then
    error "Helper not found: $USB_WAKEUP_HELPER"
  fi

  local ids
  ids="$(macos_collect_blocked_ids "$mode" "${whitelist_patterns[@]}")"

  if [[ -z "$ids" ]]; then
    echo "No devices to block. Exiting."
    exit 0
  fi

  $verbose && echo "Starting daemon for devices: $ids"

  # shellcheck disable=SC2086
  exec "$USB_WAKEUP_HELPER" daemon $ids
}

# ===== main =====
main() {
  # Allow tests to skip root check
  if [[ "${SKIP_ROOT_CHECK:-0}" != "1" ]]; then
    require_root
  fi

  # Preserve original arguments for later use ("set --" below)
  local -a args=("$@")

  # --- Defaults BEFORE loading config (avoid set -u on unset vars) ---
  local mode="$DEFAULT_MODE"
  local dry_run=false
  local verbose=false
  local macos_single_location=""
  local daemon_mode=false
  local -a WL_PATTERNS=()   # internal buffer (distinct name to avoid collisions)

  # --- Load config file (override defaults) ---
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    # Accept config overrides
    mode="${MODE:-$mode}"
    dry_run="${DRY_RUN:-$dry_run}"
    verbose="${VERBOSE:-$verbose}"

    # Ingest whitelist patterns (array or string)
    if [[ -v WHITELIST_PATTERNS ]]; then
      if declare -p WHITELIST_PATTERNS 2>/dev/null | grep -q '^declare \-a '; then
        WL_PATTERNS+=("${WHITELIST_PATTERNS[@]}")
      else
        # Use eval with "set --" so quoted multi-word entries remain distinct
        eval "set -- $WHITELIST_PATTERNS"
        WL_PATTERNS+=("$@")
      fi
    fi
    # Also accept lowercase key, if present
    if [[ -v whitelist_patterns ]]; then
      if declare -p whitelist_patterns 2>/dev/null | grep -q '^declare \-a '; then
        WL_PATTERNS+=("${whitelist_patterns[@]}")
      else
        eval "set -- $whitelist_patterns"
        WL_PATTERNS+=("$@")
      fi
    fi
  fi

  # Restore original arguments before processing CLI options
  set -- "${args[@]}"

  # --- Parse command-line arguments (override config) ---
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -a) mode="all" ;;
      -m) mode="mouse" ;;
      -c) mode="combo" ;;
      -w) shift || error "-w requires an argument"
          [[ -n "${1:-}" ]] || error "-w requires a non-empty argument"
          WL_PATTERNS+=("$1") ;;
      -d) dry_run=true ;;
      -v) verbose=true ;;
      -l|--list) verbose=true; dry_run=true ;;
      --daemon) daemon_mode=true ;;
      -p|--path) shift || error "-p requires an argument"
                 [[ -n "${1:-}" ]] || error "-p requires a non-empty argument"
                 if [[ "$PLATFORM" == "Darwin" ]]; then
                   macos_single_location="$1"
                 else
                   USB_DEVICES_GLOB="$1"
                 fi ;;
      *)  error "Unknown option: $1" ;;
    esac
    shift
  done

  if ! member "$mode" "${VALID_MODES[@]}"; then
    warning "Invalid mode: $mode, using default ($DEFAULT_MODE)"
    mode="$DEFAULT_MODE"
  fi

  if [[ "$PLATFORM" == "Darwin" ]]; then
    if $daemon_mode; then
      macos_start_daemon "$mode" "$verbose" "${WL_PATTERNS[@]}"
    else
      MACOS_SINGLE_LOCATION="$macos_single_location" \
        process_usb_devices_macos "$mode" "$dry_run" "$verbose" "${WL_PATTERNS[@]}"
    fi
  else
    process_usb_devices "$mode" "$dry_run" "$verbose" "${WL_PATTERNS[@]}"
  fi
  return 0
}

# --- call main only when executed directly (not when sourced by tests) ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
