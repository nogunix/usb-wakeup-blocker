# Contributing to usb-wakeup-blocker

Thank you for considering a contribution!
This guide outlines how to set up your environment, run checks, and submit changes.

## 1. Development Environment

1. **Clone the repository**
   ```bash
   git clone https://github.com/nogunix/usb-wakeup-blocker.git
   cd usb-wakeup-blocker
   ```
2. **Run the test suite**
   ```bash
   ./test/run-tests.sh
   ```
   *(Uses Bats to execute `test/test.bats`)*
3. **Lint the script with ShellCheck**
   ```bash
   shellcheck bin/usb-wakeup-blocker.sh
   ```

### 開発環境 (日本語)
1. **リポジトリをクローンする**
   ```bash
   git clone https://github.com/nogunix/usb-wakeup-blocker.git
   cd usb-wakeup-blocker
   ```
2. **テストスイートを実行する**
   ```bash
   ./test/run-tests.sh
   ```
   *(`test/test.bats` を Bats で実行します)*
3. **ShellCheck でスクリプトを lint する**
   ```bash
   shellcheck bin/usb-wakeup-blocker.sh
   ```

## 2. Coding Guidelines

- Write Bash scripts with `set -euo pipefail` and remain POSIX‑compatible where possible.
- Keep functions small and well‑commented.
- New features should be covered by tests in `test/test.bats`; when necessary, bypass root checks using `SKIP_ROOT_CHECK=1`.

### コーディングガイドライン (日本語)
- Bash スクリプトでは `set -euo pipefail` を使用し、可能な限り POSIX 互換を保ってください。
- 関数は小さく、十分なコメントを記述してください。
- 新機能には `test/test.bats` でテストを追加し、必要に応じて `SKIP_ROOT_CHECK=1` で root チェックを回避してください。

## 3. Submitting Changes

1. Fork the repository and create a feature branch.
2. Ensure all tests and ShellCheck pass.
3. Update documentation (e.g., README) if behavior changes.
4. Open a pull request summarizing your changes and referencing relevant issues.

### 変更の提出 (日本語)
1. リポジトリをフォークし、機能ブランチを作成してください。
2. すべてのテストと ShellCheck が成功することを確認してください。
3. 挙動が変わる場合はドキュメント（例: README）を更新してください。
4. 変更点を要約し、関連する issue を参照してプルリクエストを作成してください。

Happy hacking!

ハッピーハッキング！
