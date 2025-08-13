# usb-wakeup-blocker

[![GitHub last commit](https://img.shields.io/github/last-commit/mnoguchi/usb-wakeup-blocker)](https://github.com/mnoguchi/usb-wakeup-blocker/commits/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/mnoguchi/usb-wakeup-blocker/blob/main/LICENSE)

English | 日本語

コンピュータをスリープから復帰させることができるUSBおよびACPIデバイスを、正確に制御するためのスクリプトとsystemdサービスです。

## 概要

多くのLinuxシステムでは、デフォルトで多くのデバイスがスリープからの復帰を許可されています。これは、高感度なマウスのわずかな動きや、USB電源の瞬間的な変動によって、意図せずコンピュータがスリープから復帰してしまう原因となり、非常に煩わしいことがあります。

このプロジェクトは、**ホワイトリスト方式**を導入することでこの問題を解決します。無効化するデバイスを推測する代わりに、スリープからの復帰を**許可する**デバイスを明示的に定義します。それ以外のすべてのデバイスは、自動的に復帰が無効になります。

## 特徴

- **ホワイトリスト制御**: どのデバイスがシステムを復帰させられるかを明示的に定義できます。
- **USBとACPIの両方を管理**: マウスやキーボードといったUSB周辺機器だけでなく、内蔵キーボードや電源ボタン、PCの蓋（リッド）などの内部ACPIデバイスも制御します。
- **設定ファイル**: すべての設定は、シンプルな設定ファイル（`/etc/usb-wakeup-blocker.conf`）で管理されます。
- **Systemd連携**: `systemd`サービスとして動作し、起動時に設定を自動的に適用します。
- **診断機能**: トラブルシューティングを容易にするための詳細表示（`-v`）モードと、ドライラン（`-d`）モードを備えています。

## 要件

- `systemd`を使用するLinuxシステム
- `lsusb`コマンド（通常は`usbutils`パッケージに含まれています）

## インストール

```bash
# インストールスクリプトは、ファイルのコピーとサービスの管理のために管理者権限を必要とします。
sudo ./install.sh
```

このスクリプトは以下の処理を実行します：
1.  メインスクリプトを`/usr/local/bin/`にコピーします。
2.  systemdサービスファイルを`/etc/systemd/system/`にコピーします。
3.  デフォルトの設定ファイルを`/etc/usb-wakeup-blocker.conf`にコピーします（ファイルがまだ存在しない場合のみ）。
4.  systemdデーモンをリロードします。

**注意**: サービスは自動的には有効化・起動されません。設定後に手動で実行する必要があります。

## 設定

インストール後、すべての設定は`/etc/usb-wakeup-blocker.conf`ファイルを編集して行います。

1.  **デバイス名を見つける**: スクリプトを詳細表示モードで実行し、利用可能なすべてのUSBおよびACPIデバイスを確認します。
    ```bash
    sudo /usr/local/bin/usb-wakeup-blocker.sh -v
    ```
    出力の中から、有効にしたいUSBキーボードの`Product`名や、内蔵デバイスの`ACPI Device`名（例: `GPP3`, `LID`）を探します。

2.  **設定ファイルを編集する**:
    ```bash
    sudo nano /etc/usb-wakeup-blocker.conf
    ```

3.  **`ARGS`変数を更新する**: `-w`（USB用）と`-p`（ACPI用）フラグを使って、許可したいデバイスを追加します。
    ```ini
    # 例: 特定のUSBキーボードとPCの蓋によるスリープ復帰を許可する
    ARGS='-w "My USB Keyboard" -p "LID"'
    ```

4.  **サービスを再起動して変更を適用する**:
    ```bash
    sudo systemctl restart usb-wakeup-blocker.service
    ```

初めてサービスをセットアップする場合は、以下のコマンドでサービスを有効化（起動時に自動実行）し、即座に起動します。
```bash
sudo systemctl enable --now usb-wakeup-blocker.service
```

## アンインストール

```bash
# アンインストールスクリプトは管理者権限を必要とします。
sudo ./uninstall.sh
```

これにより、サービスが停止・無効化され、インストール時に作成されたすべてのファイル（設定ファイルを含む）が削除されます。

## トラブルシューティング

### サービスの確認

*   **サービスの状態を確認する**:
    ```bash
    systemctl status usb-wakeup-blocker.service
    ```
*   **ログを表示する**:
    ```bash
    journalctl -u usb-wakeup-blocker.service
    ```

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルをご覧ください。