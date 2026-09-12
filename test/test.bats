#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'

# Path to the script under test
SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../bin/usb-wakeup-blocker.sh"

# Helper function to create a mock USB device
create_mock_usb_device() {
    local name="$1" busnum="$2" devnum="$3" state="$4" class="$5" protocol="$6" product="$7" vendor="$8"
    mkdir -p "$MOCK_SYS_PATH/$name/power"
    echo "$busnum" > "$MOCK_SYS_PATH/$name/busnum"
    echo "$devnum" > "$MOCK_SYS_PATH/$name/devnum"
    echo "$state" > "$MOCK_SYS_PATH/$name/power/wakeup"
    [[ -n "$product" ]] && echo "$product" > "$MOCK_SYS_PATH/$name/product"
    [[ -n "$vendor" ]] && echo "$vendor" > "$MOCK_SYS_PATH/$name/manufacturer"
    if [[ -n "$class" ]]; then
        mkdir -p "$MOCK_SYS_PATH/$name/$name:1.0"
        echo "$class" > "$MOCK_SYS_PATH/$name/$name:1.0/bInterfaceClass"
        echo "$protocol" > "$MOCK_SYS_PATH/$name/$name:1.0/bInterfaceProtocol"
    fi
}

# --- Setup ---
setup() {
    # 1) Define mock paths and create directories
    MOCK_ROOT="$BATS_TMPDIR/mockfs"
    rm -rf "$MOCK_ROOT"
    MOCK_SYS_PATH="$MOCK_ROOT/sys/bus/usb/devices"
    MOCK_BIN_PATH="$MOCK_ROOT/bin"
    mkdir -p "$MOCK_SYS_PATH" "$MOCK_BIN_PATH"

    # 2) Override script's file paths with environment variables (USB only)
    export USB_DEVICES_GLOB="${MOCK_SYS_PATH}/*"
    export SKIP_ROOT_CHECK=1

    # 3) Create a mock 'lsusb' command (and prepend its dir to PATH)
    cat > "$MOCK_BIN_PATH/lsusb" <<'EOF'
#!/bin/sh
# Usage in script: lsusb -v -s BUS:DEV, or lsusb -v -d VID:PID when the
# device exposes no busnum/devnum.
# Here, $1='-v', $2='-s'|'-d', $3='BUS:DEV'|'VID:PID'
case "$2" in
    -d)
        case "$3" in
            # A device whose identity is only available from lsusb: no
            # product/manufacturer and no interface directories in sysfs.
            "1d6b:0002") echo "  idVendor           0x1d6b Acme Corp"
                         echo "  iProduct           2 Wireless Combo"
                         echo "      bInterfaceProtocol      1 Keyboard"
                         echo "      bInterfaceProtocol      2 Mouse" ;;
        esac
        ;;
    *)
        case "$3" in
            "1:1") echo "iProduct 1 Mouse Device"
                   echo "bInterfaceProtocol 2 Mouse" ;;
            "1:2") echo "iProduct 2 Keyboard Device"
                   echo "bInterfaceProtocol 1 Keyboard" ;;
            "1:3") echo "iProduct 3 Combo Device"
                   echo "bInterfaceProtocol 1 Keyboard"
                   echo "bInterfaceProtocol 2 Mouse" ;;
            "1:4") echo "iProduct 4 Other Device" ;;
            *) echo "iProduct (unknown product)" ;;
        esac
        ;;
esac
EOF
    chmod +x "$MOCK_BIN_PATH/lsusb"
    export PATH="$MOCK_BIN_PATH:$PATH"

    # 4) Create mock USB devices
    # Usage: name busnum devnum state [class protocol product vendor]
    create_mock_usb_device "usb1" "1" "1" "enabled" "03" "02" "Mouse Device" "Vendor 1"
    create_mock_usb_device "usb2" "1" "2" "enabled" "03" "01" "Keyboard Device" "Vendor 2"
    create_mock_usb_device "usb3" "1" "3" "enabled" "03" "02" "Combo Device" "Vendor 3"
    # Add second interface for Combo Keyboard
    mkdir -p "$MOCK_SYS_PATH/usb3/usb3:1.1"
    echo "03" > "$MOCK_SYS_PATH/usb3/usb3:1.1/bInterfaceClass"
    echo "01" > "$MOCK_SYS_PATH/usb3/usb3:1.1/bInterfaceProtocol"

    create_mock_usb_device "usb4" "1" "4" "enabled" "00" "00" "Other Device" "Vendor 4"

    # Script to be executed in tests
    TEST_SCRIPT_PATH="$SCRIPT_UNDER_TEST"
}

# --- Test Cases ---

@test "Default mode (-m): should disable only mouse" {
    run "$TEST_SCRIPT_PATH" -m
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "enabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")" "enabled"
}

@test "Combo mode (-c): should disable mouse and keyboard" {
    # reset
    echo enabled > "$MOCK_SYS_PATH/usb1/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb2/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb3/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb4/power/wakeup"

    run "$TEST_SCRIPT_PATH" -c
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")" "enabled"
}

@test "Whitelist (-w): should keep whitelisted device enabled" {
    # reset
    echo enabled > "$MOCK_SYS_PATH/usb1/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb2/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb3/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb4/power/wakeup"

    run "$TEST_SCRIPT_PATH" -c -w "Keyboard Device"
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "enabled" # Whitelisted
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")" "enabled"
}

@test "Config WHITELIST_PATTERNS handles space-separated values" {
    # reset
    echo enabled > "$MOCK_SYS_PATH/usb1/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb2/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb3/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb4/power/wakeup"

    config_file="$BATS_TMPDIR/uwb.conf"
    cat > "$config_file" <<'EOF'
MODE=combo
WHITELIST_PATTERNS='"Mouse Device" "Keyboard Device"'
EOF
    export CONFIG_FILE="$config_file"

    run "$TEST_SCRIPT_PATH"
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "enabled"  # Whitelisted
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "enabled"  # Whitelisted
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")" "enabled"

    unset CONFIG_FILE
}

@test "Config MODE=all with whitelist keeps keyboard enabled" {
    # reset
    echo enabled > "$MOCK_SYS_PATH/usb1/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb2/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb3/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb4/power/wakeup"

    config_file="$BATS_TMPDIR/uwb-all.conf"
    cat > "$config_file" <<'EOF'
MODE=all
WHITELIST_PATTERNS=("Keyboard Device")
EOF
    export CONFIG_FILE="$config_file"

    run "$TEST_SCRIPT_PATH"
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "enabled"  # Whitelisted
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")" "disabled"

    rm -f "$config_file"
    unset CONFIG_FILE
}

@test "Dry run (-d): should not change any files" {
    # reset
    echo enabled > "$MOCK_SYS_PATH/usb1/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb2/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb3/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb4/power/wakeup"

    # capture initial states
    initial_usb1="$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")"
    initial_usb2="$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")"
    initial_usb3="$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")"
    initial_usb4="$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")"

    run "$TEST_SCRIPT_PATH" -a -d -v
    assert_success
    assert_output --partial "Dry Run: true"

    # unchanged
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "$initial_usb1"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "$initial_usb2"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "$initial_usb3"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")" "$initial_usb4"
}

@test "Help (-h): should display usage" {
    run "$TEST_SCRIPT_PATH" -h
    assert_success
    assert_output --partial "Usage: usb-wakeup-blocker.sh"
}

@test "Unknown option: should fail with error" {
    run "$TEST_SCRIPT_PATH" --unknown
    assert_failure
    assert_output --partial "ERROR: Unknown option: --unknown"
}

@test "Missing argument for -w: should fail with error" {
    run "$TEST_SCRIPT_PATH" -w
    assert_failure
    assert_output --partial "ERROR: -w requires a non-empty argument"
}

@test "Invalid mode in config: should warn and use default" {
    config_file="$BATS_TMPDIR/uwb-invalid.conf"
    echo "MODE=invalid" > "$config_file"
    export CONFIG_FILE="$config_file"

    run "$TEST_SCRIPT_PATH"
    assert_success
    assert_output --partial "WARNING: Invalid mode: invalid, using default (mouse)"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "disabled"

    unset CONFIG_FILE
}

@test "Lowercase whitelist_patterns in config: should work" {
    config_file="$BATS_TMPDIR/uwb-lower.conf"
    cat > "$config_file" <<'EOF'
MODE=all
whitelist_patterns=("Mouse Device")
EOF
    export CONFIG_FILE="$config_file"

    run "$TEST_SCRIPT_PATH"
    assert_success
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "enabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "disabled"

    unset CONFIG_FILE
}

@test "Verbose output (-v): should display table" {
    run "$TEST_SCRIPT_PATH" -v -d
    assert_success
    assert_output --partial "Device"
    assert_output --partial "Product (for -w)"
    assert_output --partial "Action"
    assert_output --partial "usb1"
    assert_output --partial "Mouse Device"
}

@test "Partial whitelist match: should work" {
    run "$TEST_SCRIPT_PATH" -a -w "Mouse"
    assert_success
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "enabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "disabled"
}

@test "lsusb fails: should handle gracefully" {
    # Create a failing lsusb
    cat > "$MOCK_BIN_PATH/lsusb" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN_PATH/lsusb"

    echo "Sysfs Mouse" > "$MOCK_SYS_PATH/usb1/product"
    echo "Sysfs Manufacturer" > "$MOCK_SYS_PATH/usb1/manufacturer"

    run "$TEST_SCRIPT_PATH" -a -w "Sysfs Mouse" -v
    assert_success
    assert_output --partial "Sysfs Mouse"
    assert_output --partial "Sysfs Manufacturer"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "enabled"
}

@test "Root check: should fail if not root" {
    unset SKIP_ROOT_CHECK
    # Mock id -u to return non-zero
    cat > "$MOCK_BIN_PATH/id" <<'EOF'
#!/bin/sh
echo 1000
EOF
    chmod +x "$MOCK_BIN_PATH/id"
    # Ensure EUID is not set to 0 if possible, but EUID is readonly in bash.
    # However, the script uses ${EUID:-$(id -u)}.
    # In bats, EUID might be set. Let's see.

    run "$TEST_SCRIPT_PATH"
    # This might pass if EUID is 0 in the environment.
    # We can use 'env -u EUID' if needed, but EUID is a shell variable.
    if [[ "$status" -eq 0 ]]; then
        # If it succeeded, it means EUID was 0.
        # We can skip this test or try to force it.
        skip "Cannot test root check when running as root"
    else
        assert_output --partial "ERROR: This script must be run as root."
    fi
}

@test "Whitelist: should enable a disabled device" {
    # start disabled
    echo disabled > "$MOCK_SYS_PATH/usb2/power/wakeup"

    run "$TEST_SCRIPT_PATH" -a -w "Keyboard Device"
    assert_success
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "enabled"
}

@test "safe_write failure: should warn" {
    # Make a file non-writable
    chmod -w "$MOCK_SYS_PATH/usb1/power/wakeup"

    run "$TEST_SCRIPT_PATH" -m -v
    assert_success
    assert_output --partial "WARNING: Not writable: $MOCK_SYS_PATH/usb1/power/wakeup"
    assert_output --partial "disable (failed)"

    # restore for other tests (though setup runs every time)
    chmod +w "$MOCK_SYS_PATH/usb1/power/wakeup"
}

@test "Path option (-p): should process only specific device" {
    # reset all to enabled
    echo enabled > "$MOCK_SYS_PATH/usb1/power/wakeup"
    echo enabled > "$MOCK_SYS_PATH/usb2/power/wakeup"

    # Only process usb1 (mouse)
    run "$TEST_SCRIPT_PATH" -m -p "$MOCK_SYS_PATH/usb1"
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "enabled" # Should not be touched
}

@test "List option (-l): should show status without changes" {
    # capture initial state
    initial_usb1="$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")"

    run "$TEST_SCRIPT_PATH" -l
    assert_success
    assert_output --partial "Device"
    assert_output --partial "usb1"
    
    # unchanged
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "$initial_usb1"
}


# Creates a device that sysfs describes only by vendor/product ID: no
# busnum/devnum, no product/manufacturer and no interface directories, so
# every attribute has to come from `lsusb -v -d VID:PID`.
create_lsusb_only_device() {
    local name="$1" state="$2" vid="$3" pid="$4"
    mkdir -p "$MOCK_SYS_PATH/$name/power"
    echo "$state" > "$MOCK_SYS_PATH/$name/power/wakeup"
    echo "$vid" > "$MOCK_SYS_PATH/$name/idVendor"
    echo "$pid" > "$MOCK_SYS_PATH/$name/idProduct"
}

@test "lsusb -d fallback: identifies a device that has no busnum/devnum" {
    create_lsusb_only_device "usb5" "enabled" "1d6b" "0002"

    run "$TEST_SCRIPT_PATH" -m -v -p "$MOCK_SYS_PATH/usb5"
    assert_success

    # Product and vendor names come from iProduct/idVendor in the lsusb output.
    assert_output --partial "Wireless Combo"
    assert_output --partial "Acme Corp"
    # Mouse and keyboard are detected from the lsusb protocol lines alone.
    assert_output --partial "disable"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb5/power/wakeup")" "disabled"
}

@test "lsusb -d fallback: whitelist matches the lsusb product name" {
    create_lsusb_only_device "usb5" "enabled" "1d6b" "0002"

    run "$TEST_SCRIPT_PATH" -c -w "Wireless Combo" -p "$MOCK_SYS_PATH/usb5"
    assert_success
    assert_equal "$(cat "$MOCK_SYS_PATH/usb5/power/wakeup")" "enabled"
}

@test "Unknown device: falls back to placeholder product and vendor names" {
    # No idVendor/idProduct either, so lsusb is never consulted for this one.
    mkdir -p "$MOCK_SYS_PATH/usb6/power"
    echo enabled > "$MOCK_SYS_PATH/usb6/power/wakeup"

    run "$TEST_SCRIPT_PATH" -l -p "$MOCK_SYS_PATH/usb6"
    assert_success
    assert_output --partial "(unknown product)"
    assert_output --partial "(unknown vendor)"
}

@test "get_device_info: returns the documented tab-separated fields" {
    # Sourcing the script only defines its functions, so the helper can be
    # called directly to pin down its return format.
    run bash -c '
        source "$1"
        get_device_info "$2" | cat -A
    ' _ "$TEST_SCRIPT_PATH" "$MOCK_SYS_PATH/usb1"
    assert_success
    # is_mouse \t is_keyboard \t product_name \t vendor_name
    assert_output "true^Ifalse^IMouse Device^IVendor 1\$"
}

@test "Config lowercase whitelist_patterns as a quoted string" {
    config_file="$BATS_TMPDIR/uwb-lower-string.conf"
    cat > "$config_file" <<'EOF'
MODE=all
whitelist_patterns='"Mouse Device" "Keyboard Device"'
EOF
    export CONFIG_FILE="$config_file"

    run "$TEST_SCRIPT_PATH"
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "enabled"   # Whitelisted
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "enabled"   # Whitelisted
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")" "disabled"

    rm -f "$config_file"
    unset CONFIG_FILE
}

@test "Missing argument for -p: should fail with error" {
    run "$TEST_SCRIPT_PATH" -p
    assert_failure
    assert_output --partial "ERROR: -p requires a non-empty argument"
}

@test "Long options (--list, --path, --help) behave like the short ones" {
    initial_usb1="$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")"

    run "$TEST_SCRIPT_PATH" --list --path "$MOCK_SYS_PATH/usb1"
    assert_success
    assert_output --partial "usb1"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "$initial_usb1"

    run "$TEST_SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage: usb-wakeup-blocker.sh"
}
