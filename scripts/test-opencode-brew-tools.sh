#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$ROOT/installers/opencode.sh"
CATALOG="$ROOT/installers/brew-tools.tsv"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/opencode-brew-tools-test.XXXXXX")"
PASSES=0

cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT INT TERM

fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
pass() { PASSES=$((PASSES + 1)); printf 'PASS %s\n' "$1"; }

assert_contains() {
  grep -Fq "$2" "$1" || fail "$3"
}

assert_not_contains() {
  ! grep -Fq "$2" "$1" || fail "$3"
}

assert_count() {
  local actual
  actual="$(grep -Fc "$2" "$1" 2>/dev/null || true)"
  [ "$actual" = "$3" ] || fail "$4 (expected $3, found $actual)"
}

expect_failure() {
  local expected="$1"
  shift
  local output status
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "$expected: command unexpectedly succeeded"
  case "$output" in *"$expected"*) ;; *) fail "$expected: unclear error: $output" ;; esac
}

make_isolated_bin() {
  local name="$1" tool source
  local bin="$SCRATCH/$name"
  mkdir -p "$bin"
  for tool in bash awk basename chmod comm cp dirname find ln mkdir mktemp mv readlink rm rmdir sort tr wc; do
    source="$(command -v "$tool")"
    [ -n "$source" ] || fail "isolated PATH prerequisite missing: $tool"
    ln -s "$source" "$bin/$tool"
  done
  printf '%s\n' "$bin"
}

make_fake_brew() {
  local bin="$1"
  cat > "$bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$BREW_TEST_LOG"
[ "${1:-}" = "install" ] && [ -n "${2:-}" ] || exit 2
[ "${BREW_TEST_FAIL_FORMULA:-}" != "$2" ] || exit 1
printf '#!/usr/bin/env bash\nexit 0\n' > "$BREW_TEST_BIN/$2"
chmod +x "$BREW_TEST_BIN/$2"
EOF
  chmod +x "$bin/brew"
}

shouldPlanBrewToolsByDefaultForGlobalInstall() {
  local bin output error
  bin="$(make_isolated_bin global-default-bin)"
  output="$SCRATCH/global-default.out"
  error="$SCRATCH/global-default.err"

  # Given a global architecture install with both audit commands absent
  # When the installer runs in dry-run mode without a Brew option
  if ! PATH="$bin" "$INSTALLER" install --domain architecture --dry-run > "$output" 2> "$error"; then
    fail "global Brew dry run failed: $(cat "$error")"
  fi

  # Then both required formulas are planned without invoking Homebrew
  assert_contains "$output" 'brew install govulncheck' "global default missed govulncheck"
  assert_contains "$output" 'brew install osv-scanner' "global default missed osv-scanner"
  [ ! -s "$error" ] || fail "global Brew dry run produced warnings"
  pass shouldPlanBrewToolsByDefaultForGlobalInstall
}

shouldHonorTargetDefaultsAndExplicitOverrides() {
  local bin log target output
  bin="$(make_isolated_bin target-options-bin)"
  make_fake_brew "$bin"
  log="$SCRATCH/target-options.log"
  target="$SCRATCH/default-target"
  output="$SCRATCH/global-opt-out.out"

  # Given a fake Homebrew and an explicit scratch target
  # When no Brew option is provided
  BREW_TEST_LOG="$log" BREW_TEST_BIN="$bin" PATH="$bin" \
    "$INSTALLER" install --domain architecture --target "$target" >/dev/null

  # Then project-style targets do not change Homebrew by default
  [ ! -s "$log" ] || fail "explicit target installed Brew tools by default"
  [ -f "$target/.agents-orchestrator-manifest" ] || fail "explicit target was not installed"

  # Given a global dry run
  # When Brew installation is explicitly disabled
  PATH="$bin" "$INSTALLER" install --domain architecture --dry-run --no-install-brew-tools > "$output"

  # Then no formulas are planned
  assert_not_contains "$output" 'brew install ' "global opt-out still planned Brew tools"
  pass shouldHonorTargetDefaultsAndExplicitOverrides
}

shouldInstallMissingSelectedToolsOnlyOnce() {
  local bin log target manifest
  bin="$(make_isolated_bin selected-tools-bin)"
  make_fake_brew "$bin"
  log="$SCRATCH/selected-tools.log"
  target="$SCRATCH/selected-tools-target"
  manifest="$target/.agents-orchestrator-manifest"

  # Given an architecture selection with both audit commands absent
  # When Brew tools are explicitly installed twice
  BREW_TEST_LOG="$log" BREW_TEST_BIN="$bin" PATH="$bin" \
    "$INSTALLER" install --domain architecture --target "$target" --install-brew-tools >/dev/null
  BREW_TEST_LOG="$log" BREW_TEST_BIN="$bin" PATH="$bin" \
    "$INSTALLER" install --domain architecture --target "$target" --install-brew-tools >/dev/null

  # Then each formula is installed once and remains outside manifest ownership
  assert_count "$log" 'install govulncheck' 1 "govulncheck install was not idempotent"
  assert_count "$log" 'install osv-scanner' 1 "osv-scanner install was not idempotent"
  [ -x "$bin/govulncheck" ] || fail "fake govulncheck command was not installed"
  [ -x "$bin/osv-scanner" ] || fail "fake osv-scanner command was not installed"
  assert_not_contains "$manifest" 'govulncheck' "manifest claimed govulncheck"
  assert_not_contains "$manifest" 'osv-scanner' "manifest claimed osv-scanner"
  PATH="$bin" "$INSTALLER" uninstall --target "$target" >/dev/null
  [ -x "$bin/govulncheck" ] || fail "uninstall removed shared govulncheck command"
  [ -x "$bin/osv-scanner" ] || fail "uninstall removed shared osv-scanner command"
  pass shouldInstallMissingSelectedToolsOnlyOnce
}

shouldIgnoreToolsForUnselectedComponents() {
  local bin log target
  bin="$(make_isolated_bin unselected-tools-bin)"
  make_fake_brew "$bin"
  log="$SCRATCH/unselected-tools.log"
  target="$SCRATCH/unselected-tools-target"

  # Given a selection that excludes dependency-security-audit
  # When Brew tool installation is explicitly enabled
  BREW_TEST_LOG="$log" BREW_TEST_BIN="$bin" PATH="$bin" \
    "$INSTALLER" install --domain plan --target "$target" --install-brew-tools >/dev/null

  # Then no audit formula is installed
  [ ! -s "$log" ] || fail "unselected component triggered a Brew install"
  pass shouldIgnoreToolsForUnselectedComponents
}

shouldWarnAndContinueWhenBrewIsUnavailableOrFails() {
  local missing_bin missing_target missing_error failing_bin failing_target failing_log failing_error
  missing_bin="$(make_isolated_bin missing-brew-bin)"
  missing_target="$SCRATCH/missing-brew-target"
  missing_error="$SCRATCH/missing-brew.err"

  # Given both required commands and Homebrew are absent
  # When an explicit Brew-enabled install runs
  PATH="$missing_bin" "$INSTALLER" install --domain architecture --target "$missing_target" \
    --install-brew-tools >/dev/null 2> "$missing_error"

  # Then the OpenCode target commits and the missing formulas are reported
  [ -f "$missing_target/.agents-orchestrator-manifest" ] || fail "missing Homebrew blocked OpenCode install"
  assert_contains "$missing_error" 'Homebrew not found; skipped required formulas: govulncheck, osv-scanner' \
    "missing Homebrew warning omitted formulas"

  failing_bin="$(make_isolated_bin failing-brew-bin)"
  make_fake_brew "$failing_bin"
  failing_target="$SCRATCH/failing-brew-target"
  failing_log="$SCRATCH/failing-brew.log"
  failing_error="$SCRATCH/failing-brew.err"

  # Given Homebrew fails for govulncheck but can install osv-scanner
  # When the Brew-enabled install runs
  BREW_TEST_LOG="$failing_log" BREW_TEST_BIN="$failing_bin" BREW_TEST_FAIL_FORMULA=govulncheck \
    PATH="$failing_bin" "$INSTALLER" install --domain architecture --target "$failing_target" \
    --install-brew-tools >/dev/null 2> "$failing_error"

  # Then the remaining formula is attempted and the OpenCode target stays installed
  assert_count "$failing_log" 'install govulncheck' 1 "failing formula was not attempted"
  assert_count "$failing_log" 'install osv-scanner' 1 "formula processing stopped after failure"
  assert_contains "$failing_error" 'brew install govulncheck failed' "formula failure warning was unclear"
  [ -f "$failing_target/.agents-orchestrator-manifest" ] || fail "formula failure rolled back OpenCode"
  pass shouldWarnAndContinueWhenBrewIsUnavailableOrFails
}

shouldRejectConflictingOrNonInstallOptions() {
  local bin
  bin="$(make_isolated_bin invalid-options-bin)"

  # Given incompatible or action-inapplicable Brew options
  # When the CLI parses them
  # Then it fails before any installer action
  expect_failure 'cannot be combined' env PATH="$bin" "$INSTALLER" install --domain architecture --dry-run \
    --install-brew-tools --no-install-brew-tools
  expect_failure 'valid only with install' env PATH="$bin" "$INSTALLER" status --domain architecture \
    --install-brew-tools
  pass shouldRejectConflictingOrNonInstallOptions
}

assert_contains "$CATALOG" $'skills\tdependency-security-audit\tgovulncheck\tgovulncheck' \
  "catalog missed govulncheck mapping"
assert_contains "$CATALOG" $'skills\tdependency-security-audit\tosv-scanner\tosv-scanner' \
  "catalog missed osv-scanner mapping"

shouldPlanBrewToolsByDefaultForGlobalInstall
shouldHonorTargetDefaultsAndExplicitOverrides
shouldInstallMissingSelectedToolsOnlyOnce
shouldIgnoreToolsForUnselectedComponents
shouldWarnAndContinueWhenBrewIsUnavailableOrFails
shouldRejectConflictingOrNonInstallOptions

printf 'PASS: %d OpenCode Brew tool installer checks.\n' "$PASSES"
