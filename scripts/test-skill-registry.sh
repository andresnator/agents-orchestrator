#!/usr/bin/env bash
# Deterministic contracts for the meta skill-registry plugin. Runs entirely
# inside a throwaway HOME/worktree; it never reads or writes real user state.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v node >/dev/null 2>&1 || {
  echo "FAIL: node is required for the skill-registry contracts" >&2
  exit 1
}
node -e 'process.exit(process.features && process.features.typescript ? 0 : 1)' >/dev/null 2>&1 || {
  echo "FAIL: skill-registry contracts need Node with native TypeScript type stripping (>= 22.18)" >&2
  exit 1
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/skill-registry-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/home"
HOME="$TMP/home" SKILL_REGISTRY_TEST_ROOT="$TMP" node "$ROOT/scripts/skill-registry-contracts.ts"
