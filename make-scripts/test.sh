#!/usr/bin/env bash
# Run all unit tests with the Node test runner.
set -euo pipefail

node_bin="${NODE:-node}"
tests="$(find . -path ./node_modules -prune -o -path '*/node_modules' -prune \
  -o -path './skills/*/assets' -prune -o -path ./.git -prune -o -path ./.claude -prune \
  -o -type f \( -name '*.test.mjs' -o -path './scripts/test-*.mjs' \) -print | sort)"
[ -n "$tests" ] || { echo "no tests found" >&2; exit 1; }
# shellcheck disable=SC2086
"$node_bin" --test $tests
