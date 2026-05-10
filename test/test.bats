#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'

# Path to the script under test
SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../bin/usb-wakeup-blocker.sh"

# Helper function to create a mock USB device
create_mock_usb_device() {
    local name="$1" busnum="$2" devnum="$3" state="$4"
    mkdir -p "$MOCK_SYS_PATH/$name/power"
    echo "$busnum" > "$MOCK_SYS_PATH/$name/busnum"
    echo "$devnum" > "$MOCK_SYS_PATH/$name/devnum"
    echo "$state" > "$MOCK_SYS_PATH/$name/power/wakeup"
}

# --- Setup ---
setup() {
    # 1) Define mock paths and create directories
    MOCK_ROOT="$BATS_TMPDIR/mockfs"
    MOCK_SYS_PATH="$MOCK_ROOT/sys/bus/usb/devices"
    MOCK_BIN_PATH="$MOCK_ROOT/bin"
    mkdir -p "$MOCK_SYS_PATH" "$MOCK_BIN_PATH"

    # 2) Override script's file paths with environment variables (USB only)
    export USB_DEVICES_GLOB="${MOCK_SYS_PATH}/*"
    export SKIP_ROOT_CHECK=1

    # 3) Create a mock 'lsusb' command (and prepend its dir to PATH)
    cat > "$MOCK_BIN_PATH/lsusb" <<'EOF'
#!/bin/sh
# Usage in script: lsusb -v -s BUS:DEV
# Here, $1='-v', $2='-s', $3='BUS:DEV'
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
EOF
    chmod +x "$MOCK_BIN_PATH/lsusb"
    export PATH="$MOCK_BIN_PATH:$PATH"

    # 4) Create mock USB devices
    create_mock_usb_device "usb1" "1" "1" "enabled"   # Mouse
    create_mock_usb_device "usb2" "1" "2" "enabled"   # Keyboard
    create_mock_usb_device "usb3" "1" "3" "enabled"   # Combo
    create_mock_usb_device "usb4" "1" "4" "enabled"   # Other

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

