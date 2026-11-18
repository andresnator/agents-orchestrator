#!/usr/bin/env bash
# Run the static checks: shell syntax and sentence length.
# Usage: lint.sh <shell-script>...
# Env: NODE (default: node).
set -euo pipefail

for script in "$@"; do
  bash -n "$script"
done
"${NODE:-node}" "$(dirname "$0")/../scripts/lint-sentences.mjs"
