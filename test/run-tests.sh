#!/usr/bin/env bash
set -euo pipefail

# Change to the project root directory
cd "$(dirname "$0")/.."

# Run tests using the bats-core executable
./test/bats-core/bin/bats test/test.bats

echo "All tests passed!"
