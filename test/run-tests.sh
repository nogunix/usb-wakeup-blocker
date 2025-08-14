#!/usr/bin/env bash
set -euo pipefail

# project root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${ROOT_DIR}/test"
VENDORED_BATS="${TEST_DIR}/bats-core/bin/bats"

# 1) If submodules are not found, initialize them automatically.
if [[ ! -x "${VENDORED_BATS}" || ! -d "${TEST_DIR}/bats-support" || ! -d "${TEST_DIR}/bats-assert" ]]; then
  echo "[info] initializing submodules (bats-core/support/assert)..." >&2
  git -C "${ROOT_DIR}" submodule update --init --recursive
fi

# 2) Check for the vendored executable again.
if [[ -x "${VENDORED_BATS}" ]]; then
  BATS_BIN="${VENDORED_BATS}"
else
  # 3) If the vendored one is not found, use the system's bats if available.
  if command -v bats >/dev/null 2>&1; then
    BATS_BIN="$(command -v bats)"
  else
    # 4) If that is also not found, download and use a temporary bats-core.
    echo "[info] bats-core not found. Downloading a portable version of bats-core..." >&2
    TMP_BATS_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_BATS_DIR}"' EXIT
    BATS_VERSION="${BATS_VERSION:-v1.11.0}"
    ARCHIVE_URL="https://github.com/bats-core/bats-core/archive/refs/tags/${BATS_VERSION}.tar.gz"
    if ! command -v curl >/dev/null 2>&1; then
      echo "[error] curl is required to download bats-core." >&2
      exit 1
    fi
    curl -fsSL "${ARCHIVE_URL}" -o "${TMP_BATS_DIR}/bats.tar.gz" || {
      curl_status=$?
      echo "[error] failed to download bats-core archive (curl exit code ${curl_status})." >&2
      exit "${curl_status}"
    }
    tar -xzf "${TMP_BATS_DIR}/bats.tar.gz" -C "${TMP_BATS_DIR}" || {
      tar_status=$?
      echo "[error] failed to extract bats-core archive (tar exit code ${tar_status})." >&2
      exit "${tar_status}"
    }
    PORTABLE_DIR="$(find "${TMP_BATS_DIR}" -maxdepth 1 -type d -name "bats-core-*")"
    BATS_BIN="${PORTABLE_DIR}/bin/bats"
  fi
fi

# 5) Run the tests.
exec "${BATS_BIN}" "${TEST_DIR}/test.bats"
