# usb-wakeup-blocker

[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)

[English](./README.md) | [日本語](./README.ja.md)

コンピュータをスリープから復帰させるUSBおよびACPIデバイスを、正確に制御するためのスクリプトと systemd サービスです。

## 概要

多くの Linux システムでは、初期設定で多くのデバイスがスリープからの復帰を許可されています。これにより、感度の高いマウスのわずかな動きや USB 電源の変動で、意図せずコンピュータが復帰してしまうことがあります。

このプロジェクトは **ホワイトリスト方式** を採用し、スリープからの復帰を「許可する」デバイスのみを明示的に指定します。それ以外のデバイスは自動的に復帰が無効化されます。

### デフォルトの挙動

設定を行わない場合、サービスは「マウスのみ」スリープ復帰を防止します。  
キーボードやPCの蓋、電源ボタンなど他のデバイスは従来通り動作します。  
これは、最も一般的な「マウスによる誤復帰防止」に適した初期設定です。

## 特徴

- **ホワイトリスト制御**: 復帰を許可するデバイスを明示的に指定できます
- **USB・ACPI両対応**: USB周辺機器（マウス・キーボード）だけでなく、内蔵キーボードや電源ボタン、PCの蓋（リッド）などのACPIデバイスも制御可能
- **設定ファイル管理**: `/etc/usb-wakeup-blocker.conf` で簡単に設定
- **systemd連携**: 起動時に自動で設定を適用
- **診断機能**: 詳細表示（`-v`）やドライラン（`-d`）モードでトラブルシュートも容易

## 要件

- `systemd` を利用する Linux システム
- `lsusb` コマンド（通常は `usbutils` パッケージに含まれます）

## インストール

```bash
# 1. リポジトリをクローン
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker

# 2. インストールスクリプトを実行
# インストールスクリプトは、ファイルのコピーとサービスの管理のために管理者権限を必要とします。
sudo ./install.sh
```

このスクリプトは以下を実行します：
1. メインスクリプトを `/usr/local/bin/` にコピー
2. systemd サービスファイルを `/etc/systemd/system/` にコピー
3. デフォルト設定ファイルを `/etc/usb-wakeup-blocker.conf` にコピー（未作成の場合のみ）
4. systemd デーモンをリロード

**注意**: サービスは自動では有効化・起動されません。設定後に手動で実行してください。

## シンプルな使い方（設定ファイル編集不要）

ほとんどのユーザーは設定ファイルを編集する必要はありません。  
インストール後（どちらの方法でも）、以下のコマンドでサービスを有効化・起動するだけです。

```bash
sudo systemctl enable --now usb-wakeup-blocker.service
```

**デフォルト動作:**  
- マウスのみがスリープ復帰をブロックされます。
- キーボードやPCの蓋、電源ボタンなどは従来通り動作します。

もしブロック・許可するデバイスを変更したい場合は、後から `/etc/usb-wakeup-blocker.conf` を編集してください。

## 設定

インストール後は `/etc/usb-wakeup-blocker.conf` を編集して設定します。

1. **デバイス名の確認**  
   詳細表示モードでスクリプトを実行し、利用可能なUSB・ACPIデバイスを確認します。
   ```bash
   sudo /usr/local/bin/usb-wakeup-blocker.sh -v
   ```
   出力から、許可したいUSBキーボードの `Product` 名や、内蔵デバイスの `ACPI Device` 名（例: `GPP3`, `LID`）を探します。

2. **設定ファイルの編集**  
   ```bash
   sudo nano /etc/usb-wakeup-blocker.conf
   ```

3. **`ARGS` 変数の更新**  
   `-w`（USB用）や `-p`（ACPI用）フラグで許可したいデバイスを追加します。
   ```ini
   # 例: 特定のUSBキーボードとPCの蓋による復帰を許可
   ARGS='-w "My USB Keyboard" -p "LID"'
   ```

4. **サービスの再起動**  
   設定変更を反映するにはサービスを再起動します。
   ```bash
   sudo systemctl restart usb-wakeup-blocker.service
   ```

初回セットアップ時は、以下でサービスを有効化（起動時に自動実行）し、即座に起動できます。
```bash
sudo systemctl enable --now usb-wakeup-blocker.service
```

## アンインストール

```bash
sudo ./uninstall.sh
```

これによりサービスが停止・無効化され、インストール時に作成されたファイル（設定ファイル含む）が削除されます。

## トラブルシューティング

### サービス状態の確認

* サービス状態の確認
    ```bash
    systemctl status usb-wakeup-blocker.service
    ```
* ログの表示
    ```bash
    journalctl -u usb-wakeup-blocker.service
    ```

### 詳細表示（-v）出力の読み方

`-v` フラグを付けてスクリプトを実行すると、調査した各デバイスに関する詳細情報が表示されます。これは、設定ファイルに記述する正しいデバイス名を見つけたり、デバッグしたりするのに役立ちます。

**出力例 (USB):**
```
$ sudo /usr/local/bin/usb-wakeup-blocker.sh -v
--- USB Wakeup Blocker ---
Mode: mouse
Dry Run: false
--------------------------
Device: 1-2.2           | Product: USB Receiver              | Mouse: true  | Keyboard: true  | Action: ignore
Device: 1-2.3           | Product: REALFORCE HYBRID JP FULL  | Mouse: false | Keyboard: true  | Action: ignore
--------------------------
Done.
```

**出力例 (ACPIデバイスを含む場合):**

`-p` フラグを使用してACPIデバイスを管理する場合、追加のセクションが表示されます。

```
$ sudo /usr/local/bin/usb-wakeup-blocker.sh -v -p "LID"
... (USBデバイスの出力) ...

--- ACPI Wakeup Management ---
------------------------------
ACPI Device: LID        | Current: enabled  | Desired: enabled  | Action: No change needed
ACPI Device: GPP3       | Current: enabled  | Desired: disabled | Action: Toggling state
```

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
    *   `Toggling state`: 現在の状態が望ましい状態と一致しなかったため、スクリプトが状態を切り替えました。
    *   `No change needed`: デバイスは既に望ましい状態です。

## ライセンス

このプロジェクトは MIT ライセンスで公開されています。詳細は [LICENSE](LICENSE) ファイルをご覧ください。