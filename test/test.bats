#!/usr/bin/env bats

load 'bats-support/load'
load 'bats-assert/load'

# テスト対象のスクリプトへのパス
SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../bin/usb-wakeup-blocker.sh"

# モックUSBデバイスを作成するヘルパー関数
create_mock_usb_device() {
    local name="$1" busnum="$2" devnum="$3" state="$4"
    mkdir -p "$MOCK_SYS_PATH/$name/power"
    echo "$busnum" > "$MOCK_SYS_PATH/$name/busnum"
    echo "$devnum" > "$MOCK_SYS_PATH/$name/devnum"
    echo "$state" > "$MOCK_SYS_PATH/$name/power/wakeup"
}

# --- セットアップ ---
setup() {
    # 1) まずモック用のパスを定義してディレクトリを作成
    MOCK_ROOT="$BATS_TMPDIR/mockfs"
    MOCK_SYS_PATH="$MOCK_ROOT/sys/bus/usb/devices"
    MOCK_PROC_FILE="$MOCK_ROOT/proc/acpi/wakeup"
    MOCK_BIN_PATH="$MOCK_ROOT/bin"
    mkdir -p "$MOCK_SYS_PATH" "$(dirname "$MOCK_PROC_FILE")" "$MOCK_BIN_PATH"

    # 2) スクリプトの参照先を環境変数で上書き
    export USB_DEVICES_GLOB="${MOCK_SYS_PATH}/*"
    export ACPI_WAKEUP_FILE="${MOCK_PROC_FILE}"
    export ACPI_TOGGLE_LOG_FILE="${MOCK_PROC_FILE}.writes.log"
    export SKIP_ROOT_CHECK=1

    # 3) `lsusb`コマンドのモックを作成（PATHの先頭に追加）
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

    # 4) モックUSBデバイス
    create_mock_usb_device "usb1" "1" "1" "enabled"   # Mouse
    create_mock_usb_device "usb2" "1" "2" "enabled"   # Keyboard
    create_mock_usb_device "usb3" "1" "3" "enabled"   # Combo
    create_mock_usb_device "usb4" "1" "4" "enabled"   # Other

    # 5) モックACPIファイル
    cat > "$MOCK_PROC_FILE" <<EOF
Device	S-state	  Status   Sysfs node
LID	  S4	*enabled
PBTN	  S5	*enabled
GPP0	  S4	*disabled
EOF
    # 初期化：書き込みログを空で作成
    : > "${ACPI_TOGGLE_LOG_FILE}"

    # 実行対象スクリプト
    TEST_SCRIPT_PATH="$SCRIPT_UNDER_TEST"
}

# --- テストケース ---

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

    # PBTNがenabledからdisabledに変更されるはずなので、ログを確認
    assert_equal "$(cat "${ACPI_TOGGLE_LOG_FILE}")" "PBTN"
}

@test "Dry run (-d): should not change any files" {
    # 初期状態を保存
    local initial_usb1
    initial_usb1=$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")
    local initial_acpi_writes
    initial_acpi_writes=$(cat "${ACPI_TOGGLE_LOG_FILE}")

    run "$TEST_SCRIPT_PATH" -a -p "LID" -d -v
    assert_success
    assert_output --partial "Action: disable"
    assert_output --partial "Dry Run: $dry_run" || assert_output --partial "Dry Run: true"

    # ファイルが変更されていないことを確認
    assert_equal "$(cat "$MOCK_SYS_PATH/usb1/power/wakeup")" "$initial_usb1"
    assert_equal "$(cat "${ACPI_TOGGLE_LOG_FILE}")" "$initial_acpi_writes"
}
