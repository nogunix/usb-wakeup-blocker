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
インストール後、以下のコマンドでサービスを有効化・起動するだけです。

```bash
sudo ./install.sh
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

## ライセンス

このプロジェクトは MIT ライセンスで公開されています。詳細は [LICENSE](LICENSE) ファイルをご覧ください。