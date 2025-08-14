# Contributing to usb-wakeup-blocker

Thank you for considering a contribution! This guide outlines how to set up your environment, run checks, and submit changes.

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

## 2. Coding Guidelines

- Write Bash scripts with `set -euo pipefail` and remain POSIX‑compatible where possible.
- Keep functions small and well‑commented.
- New features should be covered by tests in `test/test.bats`; when necessary, bypass root checks using `SKIP_ROOT_CHECK=1`.

## 3. Submitting Changes

1. Fork the repository and create a feature branch.
2. Ensure all tests and ShellCheck pass.
3. Update documentation (e.g., README) if behavior changes.
4. Open a pull request summarizing your changes and referencing relevant issues.

Happy hacking!
