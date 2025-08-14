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
WHITELIST_PATTERNS='Mouse Device Keyboard Device'
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
