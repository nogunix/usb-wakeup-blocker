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
    MOCK_PROC_FILE="$MOCK_ROOT/proc/acpi/wakeup"
    MOCK_BIN_PATH="$MOCK_ROOT/bin"
    mkdir -p "$MOCK_SYS_PATH" "$(dirname "$MOCK_PROC_FILE")" "$MOCK_BIN_PATH"

    # 2) Override script's file paths with environment variables
    export USB_DEVICES_GLOB="${MOCK_SYS_PATH}/*"
    export ACPI_WAKEUP_FILE="${MOCK_PROC_FILE}"
    export ACPI_TOGGLE_LOG_FILE="${MOCK_PROC_FILE}.writes.log"
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

    # 5) Create mock ACPI file
    cat > "$MOCK_PROC_FILE" <<EOF
Device	S-state	  Status   Sysfs node
LID	  S4	*enabled
PBTN	  S5	*enabled
GPP0	  S4	*disabled
EOF
    # Initialize: create an empty write log
    : > "${ACPI_TOGGLE_LOG_FILE}"

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
    run "$TEST_SCRIPT_PATH" -c
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb4/power/wakeup")" "enabled"
}

@test "Whitelist (-w): should keep whitelisted device enabled" {
    run "$TEST_SCRIPT_PATH" -c -w "Keyboard Device"
    assert_success

    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "disabled"
    assert_equal "$(cat "$MOCK_SYS_PATH/usb2/power/wakeup")" "enabled" # Whitelisted
    assert_equal "$(cat "$MOCK_SYS_PATH/usb3/power/wakeup")" "disabled"
}

@test "ACPI Whitelist (-p): should attempt to disable non-whitelisted ACPI devices" {
    run "$TEST_SCRIPT_PATH" -p "LID"
    assert_success

    # PBTN should be changed from enabled to disabled, so check the log
    assert_equal "$(cat "${ACPI_TOGGLE_LOG_FILE}")" "PBTN"
}

@test "Dry run (-d): should not change any files" {
    # Save initial state
    local initial_usb1
    initial_usb1=$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")
    local initial_acpi_writes
    initial_acpi_writes=$(cat "${ACPI_TOGGLE_LOG_FILE}")

    run "$TEST_SCRIPT_PATH" -a -p "LID" -d -v
    assert_success
    assert_output --partial "Action: disable"
    assert_output --partial "Dry Run: $dry_run" || assert_output --partial "Dry Run: true"

    # Verify that files have not been changed
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "$initial_usb1"
    assert_equal "$(cat "${ACPI_TOGGLE_LOG_FILE}")" "$initial_acpi_writes"
}
