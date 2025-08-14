# usb-wakeup-blocker

Linux PCが予期せずスリープ解除されるのを防ぎ、どのUSBデバイスにスリープ解除を許可するかを正確に制御できます。

[![CI](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml/badge.svg)](https://github.com/nogunix/usb-wakeup-blocker/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/nogunix/usb-wakeup-blocker/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/nogunix/usb-wakeup-blocker)](https://github.com/nogunix/usb-wakeup-blocker/commits/main)

[English](./README.md) | [日本語](./README.ja.md)

---

## なぜ必要か
ノートPCのふたを閉じたりPCをスリープにしたのに、マウスを少し動かしただけで復帰したり、ランダムなUSB信号で勝手に復帰してしまった経験はありませんか？

**usb-wakeup-blocker** を使えば、どのUSBデバイスがスリープ解除できるかを**完全に制御**できます。
デフォルトでは:
- マウスのみスリープ解除をブロック
- キーボードや他のデバイスは影響を受けません

---

## クイックスタート（デフォルト: マウスのみブロック）

```bash
git clone https://github.com/nogunix/usb-wakeup-blocker.git
cd usb-wakeup-blocker
sudo ./install.sh
sudo systemctl enable --now usb-wakeup-blocker.service
```

これで完了 ✅ — マウスではスリープ解除できなくなりますが、キーボードは従来通り使えます。

---

## オプション一覧

| フラグ | 説明 |
|--------|------|
| `-m` | マウスのみスリープ解除をブロック *(デフォルト)* |
| `-c` | マウスとキーボード両方をブロック |
| `-a` | すべてのUSBデバイスをブロック |
| `-w "NAME"` | 製品名でデバイスをホワイトリストに追加（複数可） |
| `-v` | 詳細出力（診断用、"Product"列の値を-wに使用できます） |
| `-d` | ドライランモード（設定変更なし） |

---

## 設定ファイル

設定ファイルの場所：

```
/etc/usb-wakeup-blocker.conf
```

systemdで起動する際のオプションは`ARGS`変数で指定します。

**例: マウスとキーボードをブロックし、特定のキーボードは許可する**
```ini
ARGS='-c -w "My USB Keyboard"'
```

設定変更を反映するにはサービスを再起動します：
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

| 問題 | 原因 | 解決方法 |
|------|------|----------|
| `lsusb: command not found` | `usbutils` がインストールされていない | `sudo dnf install usbutils` (Fedora) / `sudo apt install usbutils` (Debian/Ubuntu) |
| 詳細モードでデバイスが表示されない | `sudo`なしで実行している | `sudo`を付けて実行する |
| 再起動後に設定が元に戻る | サービスが有効化されていない | `sudo systemctl enable usb-wakeup-blocker.service` |

---

## 開発とテスト

テストスイートの実行：
```bash
./test/run-tests.sh
```

ShellCheckによるスクリプトチェック：
```bash
shellcheck bin/usb-wakeup-blocker.sh
```

---

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。