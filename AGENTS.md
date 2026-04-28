# Project Instructions: usb-wakeup-blocker

This file provides context and instructions for AI agents working on the `usb-wakeup-blocker` project.

## Project Overview
`usb-wakeup-blocker` is a Linux utility designed to disable USB devices from waking up the system. It supports whitelisting specific devices to allow them to maintain wakeup capabilities (e.g., keyboards or specific mice).

## Architecture & Components
- **`bin/usb-wakeup-blocker.sh`**: The core Bash script that identifies USB devices and modifies their wakeup status in `/sys/bus/usb/devices/*/power/wakeup`.
- **`etc/usb-wakeup-blocker.conf`**: Configuration file where users can specify arguments for the script (e.g., mode, whitelists).
- **`systemd/usb-wakeup-blocker.service`**: A systemd unit that runs the script at boot or on demand.
- **`test/`**: Contains automated tests using the [BATS](https://github.com/bats-core/bats-core) framework.

## Coding Standards & Conventions
- **Bash Scripting**:
  - Follow ShellCheck best practices.
  - Use `#!/usr/bin/env bash` for the shebang.
  - Maintain the MIT License header in all script files.
  - Use descriptive variable names and provide comments for complex logic.
- **Systemd**:
  - Ensure service files follow standard systemd unit patterns.
  - Use `EnvironmentFile` for configuration where appropriate.
- **Versioning**:
  - Follow semantic versioning.
  - Update `CHANGELOG.md` for any significant changes.

## Development & Testing
- **Running Tests**: Use the provided test runner:
  ```bash
  ./test/run-tests.sh
  ```
- **Adding Tests**: New features or bug fixes must be accompanied by corresponding test cases in `test/test.bats`.
- **Validation**: Always run tests and ShellCheck before submitting changes.

## Security
- Be cautious when handling system paths and user input to prevent command injection or unauthorized file access.
- The script requires root privileges to modify `/sys` entries; ensure logic is robust and safe.
