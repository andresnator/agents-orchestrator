#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v node >/dev/null 2>&1 || {
  echo "FAIL: node is required for the caveman-mode contracts" >&2
  exit 1
}
node -e 'process.exit(process.features && process.features.typescript ? 0 : 1)' >/dev/null 2>&1 || {
  echo "FAIL: caveman-mode contracts need Node with native TypeScript type stripping (>= 22.18)" >&2
  exit 1
}

node "$ROOT/scripts/caveman-mode-contracts.ts"
