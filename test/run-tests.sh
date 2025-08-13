#!/usr/bin/env bash
set -euo pipefail

# プロジェクトのルートディレクトリに移動
cd "$(dirname "$0")/.."

# bats-coreの実行ファイルを指定してテストを実行
./test/bats-core/bin/bats test/test.bats

echo "All tests passed!"
