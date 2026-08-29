#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'

SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../bin/usb-wakeup-blocker.sh"

setup() {
    MOCK_ROOT="$BATS_TMPDIR/mockfs-macos"
    rm -rf "$MOCK_ROOT"
    MOCK_BIN_PATH="$MOCK_ROOT/bin"
    mkdir -p "$MOCK_BIN_PATH"

    export SKIP_ROOT_CHECK=1
    export PLATFORM=Darwin

    # Mock ioreg for IOUSBHostDevice (depth 1)
    cat > "$MOCK_BIN_PATH/ioreg" <<'IOREG_EOF'
#!/bin/bash
# Detect which ioreg invocation this is by looking at -c argument
class=""
for arg in "$@"; do
    case "$prev" in
        -c) class="$arg" ;;
    esac
    prev="$arg"
done

if [[ "$class" == "IOUSBHostDevice" ]]; then
    cat <<'EOF'
+-o Mouse Device@01100000  <class IOUSBHostDevice, id 0x100000a01, registered, matched, active, busy 0, retain 10>
  | {
  |   "USB Product Name" = "Mouse Device"
  |   "USB Vendor Name" = "Vendor 1"
  |   "locationID" = 17825792
  |   "idVendor" = 1000
  |   "idProduct" = 2000
  |   "bDeviceClass" = 0
  | }
+-o Keyboard Device@01200000  <class IOUSBHostDevice, id 0x100000a02, registered, matched, active, busy 0, retain 10>
  | {
  |   "USB Product Name" = "Keyboard Device"
  |   "USB Vendor Name" = "Vendor 2"
  |   "locationID" = 18874368
  |   "idVendor" = 1001
  |   "idProduct" = 2001
  |   "bDeviceClass" = 0
  | }
+-o Combo Device@01300000  <class IOUSBHostDevice, id 0x100000a03, registered, matched, active, busy 0, retain 10>
  | {
  |   "USB Product Name" = "Combo Device"
  |   "USB Vendor Name" = "Vendor 3"
  |   "locationID" = 19922944
  |   "idVendor" = 1002
  |   "idProduct" = 2002
  |   "bDeviceClass" = 0
  | }
+-o Other Device@01400000  <class IOUSBHostDevice, id 0x100000a04, registered, matched, active, busy 0, retain 10>
  | {
  |   "USB Product Name" = "Other Device"
  |   "USB Vendor Name" = "Vendor 4"
  |   "locationID" = 20971520
  |   "idVendor" = 1003
  |   "idProduct" = 2003
  |   "bDeviceClass" = 0
  | }
EOF
elif [[ "$class" == "IOUSBHostInterface" ]]; then
    cat <<'EOF'
+-o IOUSBHostInterface@0  <class IOUSBHostInterface, id 0x100000b01, registered, matched, active, busy 0, retain 10>
  | {
  |   "bInterfaceProtocol" = 2
  |   "USB Product Name" = "Mouse Device"
  |   "locationID" = 17825792
  |   "bInterfaceClass" = 3
  | }
+-o IOUSBHostInterface@0  <class IOUSBHostInterface, id 0x100000b02, registered, matched, active, busy 0, retain 10>
  | {
  |   "bInterfaceProtocol" = 1
  |   "USB Product Name" = "Keyboard Device"
  |   "locationID" = 18874368
  |   "bInterfaceClass" = 3
  | }
+-o IOUSBHostInterface@0  <class IOUSBHostInterface, id 0x100000b03, registered, matched, active, busy 0, retain 10>
  | {
  |   "bInterfaceProtocol" = 2
  |   "USB Product Name" = "Combo Device"
  |   "locationID" = 19922944
  |   "bInterfaceClass" = 3
  | }
+-o IOUSBHostInterface@1  <class IOUSBHostInterface, id 0x100000b04, registered, matched, active, busy 0, retain 10>
  | {
  |   "bInterfaceProtocol" = 1
  |   "USB Product Name" = "Combo Device"
  |   "locationID" = 19922944
  |   "bInterfaceClass" = 3
  | }
+-o IOUSBHostInterface@0  <class IOUSBHostInterface, id 0x100000b05, registered, matched, active, busy 0, retain 10>
  | {
  |   "bInterfaceProtocol" = 0
  |   "USB Product Name" = "Other Device"
  |   "locationID" = 20971520
  |   "bInterfaceClass" = 8
  | }
EOF
fi
IOREG_EOF
    chmod +x "$MOCK_BIN_PATH/ioreg"

    # Mock usb-wakeup-helper
    MOCK_HELPER_STATE="$MOCK_ROOT/helper-state"
    mkdir -p "$MOCK_HELPER_STATE"
    cat > "$MOCK_BIN_PATH/usb-wakeup-helper" <<HELPER_EOF
#!/bin/bash
STATE_DIR="$MOCK_HELPER_STATE"
case "\$1" in
    get)
        loc="\$2"
        if [[ -f "\$STATE_DIR/\$loc" ]]; then
            cat "\$STATE_DIR/\$loc"
        else
            echo "default"
        fi
        ;;
    set)
        loc="\$2"
        val="\$3"
        echo "\$val" > "\$STATE_DIR/\$loc"
        ;;
    list)
        for f in "\$STATE_DIR"/*; do
            [[ -f "\$f" ]] || continue
            loc="\$(basename "\$f")"
            echo "\$loc\t(unknown)\t(unknown)\t\$(cat "\$f")"
        done
        ;;
esac
HELPER_EOF
    chmod +x "$MOCK_BIN_PATH/usb-wakeup-helper"

    export USB_WAKEUP_HELPER="$MOCK_BIN_PATH/usb-wakeup-helper"
    export PATH="$MOCK_BIN_PATH:$PATH"

    TEST_SCRIPT_PATH="$SCRIPT_UNDER_TEST"
}

# --- Test Cases ---

@test "macOS: Default mode (-m) should disable only mouse" {
    run "$TEST_SCRIPT_PATH" -m
    assert_success

    # Mouse (17825792) should be disabled
    assert_equal "$(cat "$MOCK_HELPER_STATE/17825792")" "disabled"
    # Keyboard (18874368) should not be touched
    [ ! -f "$MOCK_HELPER_STATE/18874368" ]
    # Combo (19922944) has mouse interface, should be disabled
    assert_equal "$(cat "$MOCK_HELPER_STATE/19922944")" "disabled"
    # Other (20971520) should not be touched
    [ ! -f "$MOCK_HELPER_STATE/20971520" ]
}

@test "macOS: Combo mode (-c) should disable mouse and keyboard" {
    run "$TEST_SCRIPT_PATH" -c
    assert_success

    assert_equal "$(cat "$MOCK_HELPER_STATE/17825792")" "disabled"
    assert_equal "$(cat "$MOCK_HELPER_STATE/18874368")" "disabled"
    assert_equal "$(cat "$MOCK_HELPER_STATE/19922944")" "disabled"
    [ ! -f "$MOCK_HELPER_STATE/20971520" ]
}

@test "macOS: All mode (-a) should disable all devices" {
    run "$TEST_SCRIPT_PATH" -a
    assert_success

    assert_equal "$(cat "$MOCK_HELPER_STATE/17825792")" "disabled"
    assert_equal "$(cat "$MOCK_HELPER_STATE/18874368")" "disabled"
    assert_equal "$(cat "$MOCK_HELPER_STATE/19922944")" "disabled"
    assert_equal "$(cat "$MOCK_HELPER_STATE/20971520")" "disabled"
}

@test "macOS: Whitelist (-w) should keep whitelisted device enabled" {
    run "$TEST_SCRIPT_PATH" -c -w "Keyboard Device"
    assert_success

    assert_equal "$(cat "$MOCK_HELPER_STATE/17825792")" "disabled"
    [ ! -f "$MOCK_HELPER_STATE/18874368" ] # whitelisted, no change
    assert_equal "$(cat "$MOCK_HELPER_STATE/19922944")" "disabled"
    [ ! -f "$MOCK_HELPER_STATE/20971520" ]
}

@test "macOS: Whitelist should enable a disabled device" {
    echo "disabled" > "$MOCK_HELPER_STATE/18874368"

    run "$TEST_SCRIPT_PATH" -a -w "Keyboard Device"
    assert_success

    assert_equal "$(cat "$MOCK_HELPER_STATE/18874368")" "enabled"
}

@test "macOS: Dry run (-d) should not change any state" {
    run "$TEST_SCRIPT_PATH" -a -d -v
    assert_success
    assert_output --partial "Dry Run: true"

    [ ! -f "$MOCK_HELPER_STATE/17825792" ]
    [ ! -f "$MOCK_HELPER_STATE/18874368" ]
}

@test "macOS: Verbose output (-v) should display table" {
    run "$TEST_SCRIPT_PATH" -v -d
    assert_success
    assert_output --partial "macOS"
    assert_output --partial "Product (for -w)"
    assert_output --partial "Mouse Device"
    assert_output --partial "Keyboard Device"
}

@test "macOS: List mode (-l) should show status without changes" {
    run "$TEST_SCRIPT_PATH" -l
    assert_success
    assert_output --partial "Mouse Device"
    [ ! -f "$MOCK_HELPER_STATE/17825792" ]
}

@test "macOS: Help (-h) should display usage" {
    run "$TEST_SCRIPT_PATH" -h
    assert_success
    assert_output --partial "Usage: usb-wakeup-blocker.sh"
}

@test "macOS: Partial whitelist match should work" {
    run "$TEST_SCRIPT_PATH" -a -w "Mouse"
    assert_success
    [ ! -f "$MOCK_HELPER_STATE/17825792" ] # whitelisted
    assert_equal "$(cat "$MOCK_HELPER_STATE/18874368")" "disabled"
}

@test "macOS: Missing helper should warn in verbose mode" {
    export USB_WAKEUP_HELPER="/nonexistent/helper"
    run "$TEST_SCRIPT_PATH" -m -v
    assert_success
    assert_output --partial "WARNING: Helper not found"
}

@test "macOS: Single location filter (-p) should process only that device" {
    run "$TEST_SCRIPT_PATH" -a -p 17825792
    assert_success

    assert_equal "$(cat "$MOCK_HELPER_STATE/17825792")" "disabled"
    [ ! -f "$MOCK_HELPER_STATE/18874368" ]
    [ ! -f "$MOCK_HELPER_STATE/19922944" ]
    [ ! -f "$MOCK_HELPER_STATE/20971520" ]
}

@test "macOS: --daemon should exec helper with blocked device IDs" {
    # Replace mock helper with one that records args and exits
    cat > "$MOCK_BIN_PATH/usb-wakeup-helper" <<HELPER_EOF
#!/bin/bash
echo "\$@" > "$MOCK_HELPER_STATE/daemon-args"
exit 0
HELPER_EOF
    chmod +x "$MOCK_BIN_PATH/usb-wakeup-helper"

    run "$TEST_SCRIPT_PATH" --daemon -m
    assert_success

    # Should have called "daemon <mouse_id> <combo_id>"
    daemon_args="$(cat "$MOCK_HELPER_STATE/daemon-args")"
    [[ "$daemon_args" == *"daemon"* ]]
    [[ "$daemon_args" == *"17825792"* ]]  # Mouse
    [[ "$daemon_args" == *"19922944"* ]]  # Combo (has mouse interface)
    # Keyboard and Other should NOT be included
    [[ "$daemon_args" != *"18874368"* ]]
    [[ "$daemon_args" != *"20971520"* ]]
}

@test "macOS: --daemon with whitelist should exclude whitelisted devices" {
    cat > "$MOCK_BIN_PATH/usb-wakeup-helper" <<HELPER_EOF
#!/bin/bash
echo "\$@" > "$MOCK_HELPER_STATE/daemon-args"
exit 0
HELPER_EOF
    chmod +x "$MOCK_BIN_PATH/usb-wakeup-helper"

    run "$TEST_SCRIPT_PATH" --daemon -a -w "Mouse Device"
    assert_success

    daemon_args="$(cat "$MOCK_HELPER_STATE/daemon-args")"
    # Mouse is whitelisted, should not be in daemon args
    [[ "$daemon_args" != *"17825792"* ]]
    # Others should be blocked
    [[ "$daemon_args" == *"18874368"* ]]
    [[ "$daemon_args" == *"19922944"* ]]
    [[ "$daemon_args" == *"20971520"* ]]
}

@test "macOS: --daemon with no devices to block should exit cleanly" {
    cat > "$MOCK_BIN_PATH/usb-wakeup-helper" <<HELPER_EOF
#!/bin/bash
echo "\$@" > "$MOCK_HELPER_STATE/daemon-args"
exit 0
HELPER_EOF
    chmod +x "$MOCK_BIN_PATH/usb-wakeup-helper"

    # Whitelist everything in mouse mode
    run "$TEST_SCRIPT_PATH" --daemon -m -w "Mouse" -w "Combo"
    assert_success
    assert_output --partial "No devices to block"
    [ ! -f "$MOCK_HELPER_STATE/daemon-args" ]
}
