# usb-wakeup-blocker

[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)

[English](./README.md) | [日本語](./README.ja.md)

お使いのコンピューターで、どのUSBデバイスやACPIデバイスがスリープ解除できるかを正確に制御するためのスクリプトとsystemdサービスです。

## 概要

多くのLinuxシステムでは、デフォルトで多くのデバイスがシステムをスリープから復帰させることができます。しかし、敏感なマウスやUSBの一時的な電力変動によって意図せずPCが起動してしまうのは煩わしいものです。

このプロジェクトは、**ホワイトリスト方式**でその問題を解決します。どのデバイスを無効にするか推測する代わりに、どのデバイスがシステムをスリープ解除**できる**かを明示的に定義します。それ以外のすべてのデバイスは自動的に無効化されます。

### デフォルトの動作

設定を一切行わない場合、このサービスは**マウス**によるスリープ復帰のみをブロックします。キーボード、PCの蓋、電源ボタンなど、他のすべてのデバイスは以前と同様に機能します。これは、敏感なマウスによる偶発的なスリープ解除を防ぐという、最も一般的なユースケースに対応する賢明なデフォルト設定です。

## 特徴

- **ホワイトリスト制御**: どのデバイスがシステムをスリープ解除できるかを明示的に定義します。
- **USBとACPIの両方を管理**: USB周辺機器（マウス、キーボード）だけでなく、内蔵のACPIデバイス（内蔵キーボード、電源ボタン、蓋など）も制御します。
- **設定ファイル**: すべての設定はシンプルな設定ファイル（`/etc/usb-wakeup-blocker.conf`）で管理します。
- **Systemd連携**: `systemd`サービスとして動作し、起動時に設定を自動的に適用します。
- **診断機能**: 詳細表示（`-v`）とドライラン（`-d`）モードを搭載し、トラブルシューティングを容易にします。

## 要件

- `systemd` を使用するLinuxシステム
- `lsusb` コマンド（通常は `usbutils` パッケージで提供されます）

## インストール

```bash
# 1. リポジトリをクローンします
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker

# 2. インストールスクリプトを実行します
# ファイルのコピーやサービスの管理には管理者権限が必要です
sudo ./install.sh
```

このスクリプトは以下の処理を行います:
1.  メインスクリプトを `/usr/local/bin/` にコピーします。
2.  systemdサービスファイルを `/etc/systemd/system/` にコピーします。
3.  デフォルトの設定ファイルを `/etc/usb-wakeup-blocker.conf` にコピーします（ファイルがまだ存在しない場合）。
4.  systemdデーモンをリロードします。

**注意**: サービスは自動的には有効化・起動されません。設定後に手動で有効化する必要があります。

## 簡単な使い方：設定ファイル編集なし

ほとんどのユーザーは、設定ファイルを編集する必要はありません。  
サービスをインストールして起動するだけです。

```bash
sudo systemctl enable --now usb-wakeup-blocker.service
```

**デフォルトの動作:**
- マウスによるスリープ復帰のみがブロックされます。
- キーボード、蓋の開閉、電源ボタンは通常通り機能します。

ブロックまたは許可するデバイスを変更したい場合は、`/etc/usb-wakeup-blocker.conf` を手動で編集してください。

## 設定

設定は `/etc/usb-wakeup-blocker.conf` ファイルで行います。このファイル内の `ARGS` 変数に、スクリプトに渡すコマンドライン引数を記述します。

### 動作モードの選択

スクリプトは、どの種類のデバイスからのスリープ復帰をブロックするかを制御するためのモードを提供します。これらのモードは、`/etc/usb-wakeup-blocker.conf` ファイルの `ARGS` 変数に含めることで設定できます。

*   **`-m` (デフォルト)**: マウスのみがシステムをスリープ解除するのをブロックします。
*   **`-c`**: マウスとキーボードの両方がシステムをスリープ解除するのをブロックします。
*   **`-a`**: すべてのUSBデバイスがシステムをスリープ解除するのをブロックします。

**例:**
```ini
# /etc/usb-wakeup-blocker.conf
# マウスとキーボードの両方をブロックするモードに設定
ARGS='-c'
```

### ステップ1: デバイス名を確認する

まず、`-v`（詳細表示）オプションを使って、デバイスの正確な名前を確認します。

*   **USBデバイスを確認する場合:**
```bash
sudo /usr/local/bin/usb-wakeup-blocker.sh -v
```

*   **ACPIデバイス（PCの蓋や電源ボタンなど）を確認する場合:**
    安全機能のため、`-v`に加えて`-p`オプションで何らかのパターンを一時的に指定する必要があります。これにより、ACPIデバイスを意図的に確認していることが示されます。例えば、"LID"をテストしつつ、すべてのACPIデバイスを表示するには以下のように実行します。
```bash
sudo /usr/local/bin/usb-wakeup-blocker.sh -v -p "LID"
```

出力から、ホワイトリストに追加したいデバイスの `Product` 名（USBデバイスの場合）または `ACPI Device` 名（ACPIデバイスの場合）をメモします。

**出力例:**
```
--- USB Wakeup Blocker ---
...
Device: 1-2.3           | Product: REALFORCE HYBRID JP FULL  | ...
...
--- ACPI Wakeup Management ---
...
ACPI Device: LID        | Current: enabled  | ...
...
```
この例では、USBキーボードの製品名は `REALFORCE HYBRID JP FULL`、ノートPCの蓋は `LID` です。

### ステップ2: ホワイトリストをテストする（任意ですが推奨）

設定ファイルを編集する前に、コマンドラインで直接ホワイトリストのパターンをテストできます。これにより、正しいデバイス名を使用しているか、スクリプトが期待通りに動作するかを事前に確認できます。

`-v` を付けて再度スクリプトを実行しますが、今度はステップ1でメモしたデバイス名を `-w` または `-p` フラグで追加します。

```bash
# USBキーボードのホワイトリストをテストし、Actionの変化を確認します
sudo /usr/local/bin/usb-wakeup-blocker.sh -v -w "REALFORCE HYBRID JP FULL"

# PCの蓋のホワイトリストをテストします
sudo /usr/local/bin/usb-wakeup-blocker.sh -v -p "LID"
```

出力の `Action` 列を確認してください。ホワイトリストに追加したデバイスのアクションが `enable (whitelisted)` または `No change needed`（既に有効だった場合）に変わるはずです。これで、指定したパターンが正しいことが確認できます。

### ステップ3: 設定ファイルを編集する

次に、設定ファイルを編集して、見つけたデバイス名をホワイトリストに追加します。

```bash
sudo nano /etc/usb-wakeup-blocker.conf
```

`ARGS` 変数を以下のように更新します。

#### ホワイトリストの書き方

*   **USBデバイス**: `-w "製品名"` を使います。
*   **ACPIデバイス**: `-p "デバイス名"` を使います。
*   デバイス名にスペースが含まれる場合は、必ずダブルクォート `"` で囲ってください。
*   複数のデバイスを許可するには、`-w` や `-p` を繰り返し記述します。

#### 設定例

**例1: 特定のUSBキーボードのみを許可**
```ini
# /etc/usb-wakeup-blocker.conf
# "REALFORCE HYBRID JP FULL" という名前のUSBデバイスによるスリープ復帰を許可します。
ARGS='-w "REALFORCE HYBRID JP FULL"'
```
> **ヒント**: 製品名は部分一致で動作するため、`-w "REALFORCE"` のように短く指定することも可能です。

**例2: キーボードとPCの蓋を許可**
```ini
# /etc/usb-wakeup-blocker.conf
# マウスとキーボードの両方をブロックするモード(-c)にしつつ、
# 特定のUSBキーボードとPCの蓋(LID)からの復帰は許可します。
ARGS='-c -w "2.4G Keyboard" -p "LID"'
```

### ステップ4: サービスを再起動する

設定ファイルを保存したら、`systemd` サービスを再起動して変更を適用します。

```bash
sudo systemctl restart usb-wakeup-blocker.service
```

これで、設定がシステムに反映されます。

## アンインストール

```bash
# アンインストールスクリプトには管理者権限が必要です
sudo ./uninstall.sh
```

これによりサービスが停止・無効化され、インストール時に作成されたファイル（設定ファイル含む）が削除されます。  
スクリプトによって変更されたスリープ復帰設定を完全にリセットするには、システムの再起動を推奨します。

## トラブルシューティング

### サービス状態の確認

*   **サービス状態の確認:**
    ```bash
    systemctl status usb-wakeup-blocker.service
    ```
*   **ログの表示:**
    ```bash
    journalctl -u usb-wakeup-blocker.service
    ```

### 詳細表示（-v）出力の読み方

`-v` フラグを付けてスクリプトを実行すると、調査した各デバイスに関する詳細情報が表示されます。これは、設定ファイルに記述する正しいデバイス名を見つけたり、デバッグしたりするのに役立ちます。

**出力例:**
```
$ sudo /usr/local/bin/usb-wakeup-blocker.sh -v -c -w "REALFORCE" -p "LID"
--- USB Wakeup Blocker ---
Mode: combo
Whitelist Patterns: REALFORCE
ACPI Whitelist Patterns: LID
Dry Run: false
--------------------------
Device: 1-2.2           | Product: USB Receiver              | Mouse: true  | Keyboard: true  | Action: disable
Device: 1-2.3           | Product: REALFORCE HYBRID JP FULL  | Mouse: false | Keyboard: true  | Action: enable (whitelisted)
--------------------------
Done.

--- ACPI Wakeup Management ---
------------------------------
ACPI Device: LID        | Current: enabled  | Desired: enabled  | Action: No change needed
ACPI Device: GPP3       | Current: enabled  | Desired: disabled | Action: Toggling state
```

ヘッダー部分には、現在の動作モード (`Mode`) や、認識されたホワイトリストのパターン (`Whitelist Patterns`) が表示されます。これにより、意図した設定でスクリプトが実行されているかを一目で確認できます。

各項目の意味は以下の通りです。

**USBデバイス:**

*   **`Device`**: USBデバイスの内部システムIDです（例: `1-2.2`）。
*   **`Product`**: 人間が読める製品名です。設定ファイルで `-w`（ホワイトリスト）フラグと共に使用するのはこの名前です。
*   **`Mouse` / `Keyboard`**: デバイスがマウスまたはキーボードとして認識される場合は `true` になります。
*   **`Action`**: スクリプトが実行したアクションです。
    *   `disable`: デバイスがブロック条件に一致したため、ウェイクアップ機能が無効化されました。
    *   `enable (whitelisted)`: デバイスがホワイトリストに含まれていたため、ウェイクアップ機能が有効化されました。
    *   `ignore`: デバイスのウェイクアップ設定が既に望ましい状態だったため、変更は行われませんでした。

**ACPIデバイス:** (`-p` フラグを使用したときのみ表示されます)

*   **`ACPI Device`**: ACPIデバイス名です（例: `LID`）。`-p` フラグでこの名前を使用します。
*   **`Current`**: 現在のウェイクアップ状態です（`enabled` または `disabled`）。
*   **`Desired`**: ホワイトリストに基づいた望ましい状態です。ホワイトリスト内のデバイスは `enabled`、それ以外は `disabled` になります。
*   **`Action`**:
    *   `disable`: デバイスがホワイトリストに含まれていないため、ウェイクアップ機能が無効化されました。
    *   `enable (whitelisted)`: デバイスがホワイトリストに含まれていたため、ウェイクアップ機能が有効化されました。
    *   `ignore`: デバイスのウェイクアップ設定が既に望ましい状態だったため、変更は行われませんでした。

## ライセンス

このプロジェクトは MIT ライセンスで公開されています。詳細は LICENSE ファイルをご覧ください。