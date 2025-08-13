#!/bin/bash

# Default values
MODE="mouse"
DRY_RUN=false
VERBOSE=false

# --- Helper Functions ---

# Gets device information (product name, mouse/keyboard interface presence)
# Caches lsusb output to avoid multiple calls for the same device.
# Usage: get_device_info <device_dir>
# Outputs: <is_mouse> <is_keyboard> <product_name>
declare -A DEVICE_INFO_CACHE
get_device_info() {
  local device_dir="$1"
  local busnum devnum lsusb_output is_mouse is_keyboard product_name

  if [[ -v "DEVICE_INFO_CACHE[$device_dir]" ]]; then
    echo "${DEVICE_INFO_CACHE[$device_dir]}"
    return
  fi

  if [[ ! -f "$device_dir/busnum" || ! -f "$device_dir/devnum" ]]; then
    DEVICE_INFO_CACHE["$device_dir"]="false false (error: no bus/dev nu    # ...existing code...
    while getopts "amcdvw:p:" opt; do
      case $opt in
        a) MODE="all" ;;
        m) MODE="mouse" ;;
        c) MODE="combo" ;;
        d) DRY_RUN=true ;;
        v) VERBOSE=true ;;
        w) WHITELIST_PATTERNS+=("$OPTARG") ;;
        p) ACPI_WHITELIST_PATTERNS+=("$OPTARG") ;;
        \?)
          echo "Usage: $0 [OPTIONS]"
          echo
          echo "Options:"
          echo "  -a           Block all USB devices from waking the system."
          echo "  -m           Block only mice (default)."
          echo "  -c           Block both mice and keyboards."
          echo "  -w <name>    Whitelist USB device by product name (can be used multiple times)."
          echo "  -p <name>    Whitelist ACPI device by name (can be used multiple times)."
          echo "  -d           Dry run (show actions but do not apply changes)."
          echo "  -v           Verbose output."
          echo
          echo "Examples:"
          echo "  $0 -c -w \"My Keyboard\" -p \"LID\""
          exit 1
          ;;
      esac
    done
    # ...existingm)"
    echo "${DEVICE_INFO_CACHE[$device_dir]}"
    return
  fi

  busnum=$(<"$device_dir/busnum")
  devnum=$(<"$device_dir/devnum")

  # Get lsusb output once. Redirect stderr to /dev/null.
  lsusb_output=$(lsusb -v -s "${busnum}:${devnum}" 2>/dev/null)

  if [[ -z "$lsusb_output" ]]; then
      DEVICE_INFO_CACHE["$device_dir"]="false false (error: lsusb failed)"
      echo "${DEVICE_INFO_CACHE[$device_dir]}"
      return
  fi

  # Check for interfaces
  if echo "$lsusb_output" | grep -q "bInterfaceProtocol .* 2 Mouse"; then
    is_mouse="true"
  else
    is_mouse="false"
  fi

  if echo "$lsusb_output" | grep -q "bInterfaceProtocol .* 1 Keyboard"; then
    is_keyboard="true"
  else
    is_keyboard="false"
  fi

  # Get product name for logging
  product_name=$(echo "$lsusb_output" | grep "iProduct" | sed -e 's/.*iProduct\s*[0-9]\+\s*//' | head -n 1)
  [[ -z "$product_name" ]] && product_name="(unknown product)"

  DEVICE_INFO_CACHE["$device_dir"]="$is_mouse $is_keyboard $product_name"
  echo "${DEVICE_INFO_CACHE[$device_dir]}"
}


# --- Main Logic ---

# Parse command-line options
WHITELIST_PATTERNS=()
ACPI_WHITELIST_PATTERNS=()
while getopts "amcdvw:p:" opt; do
  case $opt in
    a) MODE="all" ;;
    m) MODE="mouse" ;;
    c) MODE="combo" ;;
    d) DRY_RUN=true ;;
    v) VERBOSE=true ;;
    w) WHITELIST_PATTERNS+=("$OPTARG") ;;
    p) ACPI_WHITELIST_PATTERNS+=("$OPTARG") ;;
    \?)
      echo "Usage: $0 [-a | -m | -c] [-w <usb_product>] [-p <acpi_device>] [-d] [-v]" >&2
      exit 1
      ;;
  esac
done

if $VERBOSE; then
  echo "--- USB Wakeup Blocker ---"
  echo "Mode: $MODE"
  if [ ${#WHITELIST_PATTERNS[@]} -gt 0 ]; then
    echo "Whitelist Patterns: ${WHITELIST_PATTERNS[*]}"
  fi
  if [ ${#ACPI_WHITELIST_PATTERNS[@]} -gt 0 ]; then
    echo "ACPI Whitelist Patterns: ${ACPI_WHITELIST_PATTERNS[*]}"
  fi
  echo "Dry Run: $DRY_RUN"
  echo "--------------------------"
fi

# --- USB Wakeup Management ---
for dir in /sys/bus/usb/devices/*; do
  # Skip non-device directories
  if [ ! -f "$dir/product" ] && [ ! -f "$dir/idProduct" ]; then
    continue
  fi

  # Skip root hubs
  if [ -f "$dir/bDeviceClass" ] && [ "$(<"$dir/bDeviceClass")" == "09" ]; then
      continue
  fi

  # Get device info
  read -r is_mouse is_keyboard product_name < <(get_device_info "$dir")

  # Check if device is whitelisted
  is_whitelisted=false
  for pattern in "${WHITELIST_PATTERNS[@]}"; do
    if [[ "$product_name" == *"$pattern"* ]]; then
      is_whitelisted=true
      break
    fi
  done

  # Determine if the device should be disabled based on the mode
  disable=false
  if ! $is_whitelisted; then
    case "$MODE" in
      all) disable=true ;;
      mouse) [[ "$is_mouse" == "true" ]] && disable=true ;;
      combo) [[ "$is_mouse" == "true" || "$is_keyboard" == "true" ]] && disable=true ;;
    esac
  fi

  # Set wakeup state
  wakeup_file="$dir/power/wakeup"
  if [ -w "$wakeup_file" ]; then
    current_state=$(<"$wakeup_file")
    action="ignore"
    if $disable && [ "$current_state" == "enabled" ]; then
      action="disable"
      ! $DRY_RUN && echo "disabled" > "$wakeup_file"
    elif $is_whitelisted && [ "$current_state" == "disabled" ]; then
      action="enable (whitelisted)"
      ! $DRY_RUN && echo "enabled" > "$wakeup_file"
    fi

    if $VERBOSE; then
      device_id=$(basename "$dir")
      printf "Device: %-15s | Product: %-25s | Mouse: %-5s | Keyboard: %-5s | Action: %s\n" \
        "$device_id" "$product_name" "$is_mouse" "$is_keyboard" "$action"
    fi
  fi
done

if $VERBOSE; then
  echo "--------------------------"
  echo "Done."
fi

# --- ACPI Wakeup Management ---
# Only manage ACPI devices if an ACPI whitelist pattern is provided via the -p flag.
# This prevents accidentally disabling all ACPI wakeup sources by default.
if [ ${#ACPI_WHITELIST_PATTERNS[@]} -gt 0 ]; then
  if $VERBOSE; then
    echo
    echo "--- ACPI Wakeup Management ---"
    echo "------------------------------"
  fi

  # Read all lines from /proc/acpi/wakeup, skipping the header
  if [ ! -f /proc/acpi/wakeup ]; then
      if $VERBOSE; then echo "ACPI management skipped: /proc/acpi/wakeup not found."; fi
      exit 0
  fi

  # Use process substitution to avoid subshell variable scope issues
  while read -r device s_state status _; do
    # remove asterisk from status if present
    status=${status#\*}

    is_whitelisted=false
    for pattern in "${ACPI_WHITELIST_PATTERNS[@]}"; do
      # Use wildcard matching for flexibility
      if [[ "$device" == *"$pattern"* ]]; then
        is_whitelisted=true
        break
      fi
    done

    action="ignore"
    # We need to toggle the state if it doesn't match our desired state
    if ($is_whitelisted && [[ "$status" == "disabled" ]]) || \
       (! $is_whitelisted && [[ "$status" == "enabled" ]]); then
      
      if $VERBOSE; then
        printf "ACPI Device: %-10s | Current: %-8s | Desired: %-8s | Action: Toggling state\n" "$device" "$status" "$( [[ "$status" == "disabled" ]] && echo "enabled" || echo "disabled" )"
      fi

      if ! $DRY_RUN && [ -w "/proc/acpi/wakeup" ]; then
        echo "$device" > /proc/acpi/wakeup
      elif $DRY_RUN; then
        echo "[DRY RUN] Would toggle ACPI device $device to $( [[ "$status" == "disabled" ]] && echo "enabled" || echo "disabled" )"
      fi
    fi
  done < <(tail -n +2 /proc/acpi/wakeup)
fi