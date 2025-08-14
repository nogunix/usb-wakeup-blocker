# usb-wakeup-blocker

[![CI](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml/badge.svg)](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)

[English](./README.md) | [日本語](./README.ja.md)

特定のUSBデバイスがスリープからコンピュータを復帰できるかどうかを制御するスクリプトとsystemdサービスです。

## 概要

多くのLinuxシステムでは、マウスやキーボードを含む多くのUSBデバイスがスリープ解除できる状態になっています。これにより、わずかなマウスの動きやUSBの電源変動で意図せず復帰してしまうことがあります。

このプロジェクトは**ホワイトリスト方式**を採用しています。許可するデバイスを明示的に指定し、それ以外はすべてスリープ解除を無効化します。

### デフォルト動作

デフォルトでは、**マウス**のみがスリープ解除できないように設定されます。他のデバイス（キーボードなど）は元の動作を維持します。

## 特徴

- **ホワイトリスト制御**: スリープ解除を許可するデバイスを明示的に指定可能。
- **USBデバイス管理**: マウス、キーボードなどのUSBデバイスを制御。
- **設定ファイルによる管理**: `/etc/usb-wakeup-blocker.conf`で簡単に設定。
- **systemd統合**: 起動時に自動で適用。
- **診断モード**: 詳細表示（`-v`）、ドライラン（`-d`）対応。

## 必要要件

- systemdを使用するLinuxシステム
- `lsusb`コマンド（`usbutils`パッケージに含まれる）

## インストール

```bash
# 1. リポジトリをクローン
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker

# 2. インストールスクリプト実行（管理者権限が必要）
sudo ./install.sh
```

このスクリプトは以下を行います：

1. メインスクリプトを`/usr/local/bin/`へコピー
2. systemdサービスファイルを`/etc/systemd/system/`へコピー
3. デフォルト設定ファイルを`/etc/usb-wakeup-blocker.conf`にコピー（存在しない場合）
4. systemdデーモンを再読み込み

**注意**: サービスは自動では有効化・起動されません。設定後に手動で有効化してください。

## 簡単な使い方（設定ファイル編集不要）

ほとんどのユーザーは設定ファイルを編集する必要はありません。インストール後、以下で有効化できます。

```bash
sudo systemctl enable --now usb-wakeup-blocker.service
```

**デフォルト動作:**
- マウスのみをブロック
- キーボードなどは通常通り使用可能

設定変更は`/etc/usb-wakeup-blocker.conf`を編集してください。

## 設定方法

設定は`/etc/usb-wakeup-blocker.conf`内の`ARGS`変数にコマンドライン引数を設定します。

### モード選択

以下のフラグを使用して、どのデバイスをブロックするかを選択します。

* `-m`（デフォルト）: マウスのみブロック
* `-c`: マウスとキーボードをブロック
* `-a`: すべてのUSBデバイスをブロック

**例:**
```ini
# /etc/usb-wakeup-blocker.conf
ARGS='-c'
```

### ステップ1: デバイス名の確認

```bash
sudo /usr/local/bin/usb-wakeup-blocker.sh -v
```

出力例：
```
Device: 1-2.2  | Product: USB Receiver              | Mouse: true  | Keyboard: true  | Action: ignore
Device: 1-2.3  | Product: REALFORCE HYBRID JP FULL  | Mouse: false | Keyboard: true  | Action: ignore
```

### ステップ2: 設定ファイル編集

```bash
sudo nano /etc/usb-wakeup-blocker.conf
```

#### ホワイトリスト構文

* USBデバイス: `-w "製品名"`
* 複数登録する場合は`-w`を複数回追加

**例: 特定のキーボードを許可**
```ini
ARGS='-w "REALFORCE HYBRID JP FULL"'
```

### ステップ3: サービス再起動

```bash
sudo systemctl restart usb-wakeup-blocker.service
```

## アンインストール

```bash
sudo ./uninstall.sh
```

これにより、サービス停止と関連ファイルの削除を行います。

## トラブルシューティング

サービス状態確認：
```bash
systemctl status usb-wakeup-blocker.service
```
ログ確認：
```bash
journalctl -u usb-wakeup-blocker.service
```

## 開発とテスト

自動テスト実行：
```bash
./test/run-tests.sh
```

ShellCheckでLint：
```bash
shellcheck bin/usb-wakeup-blocker.sh
```

## ライセンス

MITライセンス。詳細は[LICENSE](LICENSE)参照。