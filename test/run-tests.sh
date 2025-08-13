#!/usr/bin/env bash
set -euo pipefail

# project root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${ROOT_DIR}/test"
VENDORED_BATS="${TEST_DIR}/bats-core/bin/bats"

# 1) サブモジュールが無ければ自動初期化
if [[ ! -x "${VENDORED_BATS}" || ! -d "${TEST_DIR}/bats-support" || ! -d "${TEST_DIR}/bats-assert" ]]; then
  echo "[info] initializing submodules (bats-core/support/assert)..." >&2
  git -C "${ROOT_DIR}" submodule update --init --recursive
fi

# 2) もう一度 vendored を確認
if [[ -x "${VENDORED_BATS}" ]]; then
  BATS_BIN="${VENDORED_BATS}"
else
  # 3) システムの bats があればそれを使う
  if command -v bats >/dev/null 2>&1; then
    BATS_BIN="$(command -v bats)"
  else
    # 4) それも無ければ、一時的に bats-core をダウンロードして使う
    echo "[info] bats-core not found. downloading portable bats-core..." >&2
    TMP_BATS_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_BATS_DIR}"' EXIT
    BATS_VERSION="${BATS_VERSION:-v1.11.0}"
    ARCHIVE_URL="https://github.com/bats-core/bats-core/archive/refs/tags/${BATS_VERSION}.tar.gz"
    curl -fsSL "${ARCHIVE_URL}" -o "${TMP_BATS_DIR}/bats.tar.gz"
    tar -xzf "${TMP_BATS_DIR}/bats.tar.gz" -C "${TMP_BATS_DIR}"
    PORTABLE_DIR="$(find "${TMP_BATS_DIR}" -maxdepth 1 -type d -name "bats-core-*")"
    BATS_BIN="${PORTABLE_DIR}/bin/bats"
  fi
fi

# 5) 実行
exec "${BATS_BIN}" "${TEST_DIR}/test.bats"