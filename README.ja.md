# usb-wakeup-blocker

Linux PCのスリープ復帰を、許可したUSBデバイスだけに制限するスクリプト & systemdサービス。

[![CI](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml/badge.svg)](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)

[English](./README.md) | [日本語](./README.ja.md)

---

## このツールが必要になるとき
ノートPCのフタを閉じたりスリープにしたのに、マウスにちょっと触れただけで復帰してしまったり、ランダムなUSB信号で勝手に起動してしまった経験はありませんか？

**usb-wakeup-blocker** は、どのUSBデバイスがスリープ復帰できるかを **完全にコントロール** できます。
デフォルト設定では:
- **マウスのみ** スリープ復帰をブロック
- キーボードやその他のUSBデバイスはそのまま動作

---

## クイックスタート（デフォルト: マウスのみブロック）

```bash
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker
sudo ./install.sh
sudo systemctl enable --now usb-wakeup-blocker.service
```

これで設定完了 ✅ — マウスでは復帰できなくなり、キーボードは今まで通り使用できます。

---

## 出力例（詳細モード）

```bash
sudo /usr/local/bin/usb-wakeup-blocker.sh -v
```

```
--- USB Wakeup Management ---
Mode: mouse
Dry Run: false
-----------------------------
Device: 1-2             | Product: USB2.1 Hub                | Mouse: false | Keyboard: false | Action: ignore
Device: 1-2.2           | Product: USB Receiver              | Mouse: true  | Keyboard: true  | Action: ignore
Device: 1-2.3           | Product: REALFORCE HYBRID JP FULL  | Mouse: false | Keyboard: true  | Action: ignore
Device: 1-2.4           | Product: 2.4G Keyboard             | Mouse: true  | Keyboard: true  | Action: ignore
Device: 2-2             | Product: USB3.1 Hub                | Mouse: false | Keyboard: false | Action: ignore
Device: 3-3             | Product: ELAN:Fingerprint          | Mouse: false | Keyboard: false | Action: ignore
Device: 3-4             | Product: (unknown product)         | Mouse: false | Keyboard: false | Action: ignore
Device: usb1            | Product: xHCI Host Controller      | Mouse: false | Keyboard: false | Action: ignore
Device: usb2            | Product: xHCI Host Controller      | Mouse: false | Keyboard: false | Action: ignore
Device: usb3            | Product: xHCI Host Controller      | Mouse: false | Keyboard: false | Action: ignore
Device: usb4            | Product: xHCI Host Controller      | Mouse: false | Keyboard: false | Action: ignore
--------------------------
Done.
```

---


## オプション一覧

| フラグ | 説明 | デフォルト |
|--------|------|------------|
| `-m` | マウスのみスリープ復帰をブロック | ✅ |
| `-c` | マウスとキーボード両方をブロック | ❌ |
| `-a` | 全USBデバイスをブロック | ❌ |
| `-w "NAME"` | デバイス名でホワイトリスト登録（複数指定可） | ❌ |
| `-v` | 詳細出力モード | ❌ |
| `-d` | ドライランモード（変更なし） | ❌ |

---

## 設定方法

設定ファイルの場所:
```
/etc/usb-wakeup-blocker.conf
```

`ARGS` 変数にオプションを設定します。systemdで起動する際にスクリプトへ渡されます。

**例: マウスとキーボードをブロックし、特定のキーボードを許可**
```ini
ARGS='-c -w "REALFORCE HYBRID JP FULL"'
```

設定変更後はサービスを再起動:
```bash
sudo systemctl restart usb-wakeup-blocker.service
```

---

## アンインストール

```bash
sudo ./uninstall.sh
```

削除されるもの:
- インストールされたスクリプト
- systemdサービスファイル
- 設定ファイル

---

## トラブルシューティング

### よくある問題と対策

| 問題 | 原因 | 対策 |
|------|------|------|
| `lsusb: command not found` | `usbutils` が未インストール | Fedora: `sudo dnf install usbutils` / Debian系: `sudo apt install usbutils` |
| 詳細モードで何も表示されない | `sudo` なしで実行 | `sudo` を付けて実行 |
| 再起動後に設定が戻る | サービスが有効化されていない | `sudo systemctl enable usb-wakeup-blocker.service` |

---

## 開発・テスト

テストスイート実行:
```bash
./test/run-tests.sh
```

ShellCheckでスクリプトを検証:
```bash
shellcheck bin/usb-wakeup-blocker.sh
```

---

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照