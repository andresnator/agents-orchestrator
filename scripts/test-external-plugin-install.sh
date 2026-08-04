#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/scripts/fixtures/external-plugins"
INSTALLER="$ROOT/installers/opencode.sh"
PLUGIN_SPEC="./plugins/model-configurator/tui.js"
OLD_PLUGIN_SPEC="./plugins/model-configurator.tsx"
MIN_OPENCODE_VERSION="1.17.15"
PASSES=0

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

pass() {
  PASSES=$((PASSES + 1))
  printf 'PASS %s\n' "$1"
}

assert_file_equals() {
  cmp -s "$1" "$2" || fail "$3"
}

assert_contains() {
  grep -Fq "$2" "$1" || fail "$3"
}

assert_count() {
  local actual
  actual="$(grep -Fc "$2" "$1" || true)"
  [ "$actual" = "$3" ] || fail "$4 (expected $3, found $actual)"
}

assert_json_value() {
  local actual
  actual="$(jq -r "$2" "$1")"
  [ "$actual" = "$3" ] || fail "$4 (expected $3, found $actual)"
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    fail "shasum or sha256sum is required"
  fi
}

make_fake_opencode() {
  local root="$1" version="$2" binary
  binary="$root/opencode"
  mkdir -p "$root"
  cat > "$binary" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "--version" ]; then
  printf '%s\\n' '$version'
  exit 0
fi
exit 0
EOF
  chmod +x "$binary"
  printf '%s\n' "$binary"
}

make_external_artifacts() {
  local root="$1"
  mkdir -p "$root"
  cat > "$root/model-configurator.js" <<'EOF'
export default { id: "fixture.model-configurator", tui: async () => {} }
EOF
  cat > "$root/skill-registry.js" <<'EOF'
export default { id: "fixture.skill-registry", server: async () => ({}) }
EOF
  cat > "$root/graphify-init.js" <<'EOF'
export default { id: "fixture.graphify-init", server: async () => ({}) }
EOF
}

target_snapshot() {
  (
    cd "$1" || exit 1
    find . -mindepth 1 ! -name '*.bak' | LC_ALL=C sort | while IFS= read -r entry; do
      if [ -L "$entry" ]; then
        printf 'link\t%s\t%s\n' "$entry" "$(readlink "$entry")"
      elif [ -d "$entry" ]; then
        printf 'dir\t%s\n' "$entry"
      else
        printf 'file\t%s\t%s\n' "$entry" "$(cksum <"$entry")"
      fi
    done
  )
}

shouldPreserveJsoncManagedEntry() {
  local scratch rendered removed
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-jsonc.XXXXXX")"
  rendered="$scratch/rendered.jsonc"
  removed="$scratch/removed.jsonc"

  # Given user-owned JSONC with comments, trailing commas, and Unicode
  # When the external TUI entry is added and removed
  # Then additions are exact and foreign content survives removal
  python3 "$ROOT/scripts/jsonc-array.py" add "$FIXTURES/tui-comments-before.jsonc" plugin "$PLUGIN_SPEC" > "$rendered"
  assert_file_equals "$rendered" "$FIXTURES/tui-comments-after-add.jsonc" "JSONC add changed unexpected bytes"
  python3 "$ROOT/scripts/jsonc-array.py" remove "$rendered" plugin "$PLUGIN_SPEC" > "$removed"
  python3 "$ROOT/scripts/jsonc-array.py" has "$removed" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "JSONC remove retained the managed entry"
  assert_contains "$removed" "// Keep this inline comment." "JSONC remove dropped a foreign comment"
  assert_contains "$removed" '"./foreign.tsx"' "JSONC remove dropped a foreign plugin"
  assert_contains "$removed" '"label": "Configuración ágil"' "JSONC remove damaged Unicode"
  rm -rf "$scratch"
  pass "shouldPreserveJsoncManagedEntry"
}

shouldHandleMissingPropertyAndTrailingComment() {
  local scratch rendered
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-jsonc.XXXXXX")"
  rendered="$scratch/rendered.jsonc"

  # Given valid JSONC shapes that previously exposed separator bugs
  # When the managed value is added
  # Then both complete documents match their approved fixtures
  python3 "$ROOT/scripts/jsonc-array.py" add "$FIXTURES/tui-missing-plugin-before.jsonc" plugin "$PLUGIN_SPEC" > "$rendered"
  assert_file_equals "$rendered" "$FIXTURES/tui-missing-plugin-after-add.jsonc" "missing plugin property rendered unexpectedly"
  python3 "$ROOT/scripts/jsonc-array.py" add "$FIXTURES/tui-trailing-comment-before.jsonc" plugin "$PLUGIN_SPEC" > "$rendered"
  assert_file_equals "$rendered" "$FIXTURES/tui-trailing-comment-after-add.jsonc" "trailing-comment add rendered unexpectedly"
  rm -rf "$scratch"
  pass "shouldHandleMissingPropertyAndTrailingComment"
}

shouldInstallRepairStatusAndUninstallExternalPlugins() {
  local scratch target artifacts binary status_output before_package
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-install.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  status_output="$scratch/status.txt"
  mkdir -p "$target"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  cp "$FIXTURES/tui-comments-before.jsonc" "$target/tui.json"
  printf '{"name":"foreign-package","foreign":true}\n' > "$target/package.json"
  cp "$target/package.json" "$scratch/package-before.json"
  before_package="$scratch/package-before.json"

  # Given a compatible runtime, foreign config, and deterministic external artifacts
  # When install, repair, status, reinstall, and uninstall run
  # Then only pinned bundles, profile snapshots, and the exact TUI value are owned
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta,common --target "$target" >/dev/null
  [ -f "$target/plugins/model-configurator/tui.js" ] || fail "model configurator bundle missing"
  [ -f "$target/plugins/model-configurator/profiles/default.json" ] || fail "model profile snapshot missing"
  [ -f "$target/plugins/skill-registry.js" ] || fail "skill registry bundle missing"
  [ -f "$target/plugins/graphify-init.js" ] || fail "Graphify bundle missing"
  assert_file_equals "$target/package.json" "$before_package" "fresh install changed package.json"
  assert_count "$target/tui.json" "$PLUGIN_SPEC" 1 "install duplicated the TUI entry"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-array' 1 "manifest did not narrowly own the TUI entry"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-object' 0 "fresh manifest still owns an npm dependency"

  printf 'corrupt\n' > "$target/plugins/skill-registry.js"
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta,common --target "$target" >/dev/null
  assert_file_equals "$target/plugins/skill-registry.js" "$artifacts/skill-registry.js" "reinstall did not repair a stale bundle"

  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" status --domain meta,common --target "$target" > "$status_output"
  assert_contains "$status_output" $'meta\texternal-tui-plugins\tmodel-configurator\t-\tinstalled+registered@0.1.0' "status missed model configurator"
  assert_contains "$status_output" $'meta\texternal-server-plugins\tskill-registry\t-\tinstalled@0.1.0' "status missed skill registry"
  assert_contains "$status_output" $'common\texternal-server-plugins\tgraphify-init\t-\tinstalled@0.1.0' "status missed Graphify"

  "$INSTALLER" uninstall --target "$target" >/dev/null
  [ ! -e "$target/plugins/model-configurator" ] || fail "uninstall retained model configurator"
  [ ! -e "$target/plugins/skill-registry.js" ] || fail "uninstall retained skill registry"
  [ ! -e "$target/plugins/graphify-init.js" ] || fail "uninstall retained Graphify"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "uninstall retained the owned TUI value"
  assert_contains "$target/tui.json" '"./foreign.tsx"' "uninstall removed a foreign TUI plugin"
  assert_file_equals "$target/package.json" "$before_package" "uninstall changed foreign package.json"
  rm -rf "$scratch"
  pass "shouldInstallRepairStatusAndUninstallExternalPlugins"
}

shouldPreservePreexistingTuiRegistration() {
  local scratch target artifacts binary
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-preowned.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  mkdir -p "$target"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  printf '{"plugin":["%s"]}\n' "$PLUGIN_SPEC" > "$target/tui.json"

  # Given the exact TUI registration predates installer ownership
  # When meta is installed and uninstalled
  # Then the manifest never claims or removes that user value
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null
  assert_count "$target/.agents-orchestrator-manifest" 'managed-array' 0 "installer claimed a preexisting TUI value"
  "$INSTALLER" uninstall --target "$target" >/dev/null
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 ||
    fail "uninstall removed a preexisting TUI value"
  rm -rf "$scratch"
  pass "shouldPreservePreexistingTuiRegistration"
}

shouldAbortBeforeMutationOnInvalidPreconditions() {
  local scratch target artifacts old_binary current_binary before
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-preflight.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  before="$scratch/before"
  mkdir -p "$target"
  make_external_artifacts "$artifacts"
  old_binary="$(make_fake_opencode "$scratch/old-bin" "1.17.14")"
  current_binary="$(make_fake_opencode "$scratch/current-bin" "$MIN_OPENCODE_VERSION")"
  printf '{"plugin":[]}\n' > "$target/tui.json"
  cp -R "$target" "$before"

  # Given an incompatible runtime, malformed JSONC, or a foreign bundle destination
  # When installation is attempted
  # Then every failure occurs before target mutation
  if AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$old_binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
    fail "installer accepted an old OpenCode version"
  fi
  diff -qr "$before" "$target" >/dev/null || fail "version rejection mutated the target"

  printf '{ invalid\n' > "$target/tui.json"
  rm -rf "$before"
  cp -R "$target" "$before"
  if AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$current_binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
    fail "installer accepted invalid tui.json"
  fi
  diff -qr "$before" "$target" >/dev/null || fail "JSONC rejection mutated the target"

  printf '{"plugin":[]}\n' > "$target/tui.json"
  mkdir -p "$target/plugins"
  printf 'foreign\n' > "$target/plugins/skill-registry.js"
  rm -rf "$before"
  cp -R "$target" "$before"
  if AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$current_binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
    fail "installer replaced a foreign external plugin without --force"
  fi
  diff -qr "$before" "$target" >/dev/null || fail "foreign destination rejection mutated the target"
  rm -rf "$scratch"
  pass "shouldAbortBeforeMutationOnInvalidPreconditions"
}

shouldRollbackExternalPluginTransaction() {
  local scratch target artifacts binary before step
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-rollback.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  before="$scratch/before"
  mkdir -p "$target"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  cp "$FIXTURES/tui-comments-before.jsonc" "$target/tui.json"

  # Given injected failures at each commit boundary
  # When a meta install aborts
  # Then bundles, profiles, config, backups, and manifest return to the exact prior state
  for step in after-links after-managed-array before-manifest after-manifest; do
    rm -rf "$before"
    cp -R "$target" "$before"
    if AGENTS_ORCHESTRATOR_TEST_FAIL_STEP="$step" \
      AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
      "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
      fail "installer did not inject failure at $step"
    fi
    diff -qr "$before" "$target" >/dev/null || fail "installer did not roll back $step"
  done
  rm -rf "$scratch"
  pass "shouldRollbackExternalPluginTransaction"
}

shouldSyncAwayDeselectedExternalPlugins() {
  local scratch target artifacts binary
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-sync.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"

  # Given the meta external plugins are installed
  # When a later sync selects only common
  # Then model/registry artifacts and TUI config leave while Graphify is installed
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain common --target "$target" >/dev/null
  [ ! -e "$target/plugins/model-configurator" ] || fail "sync retained deselected model configurator"
  [ ! -e "$target/plugins/skill-registry.js" ] || fail "sync retained deselected skill registry"
  [ -f "$target/plugins/graphify-init.js" ] || fail "sync did not install Graphify"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "sync retained stale TUI registration"
  rm -rf "$scratch"
  pass "shouldSyncAwayDeselectedExternalPlugins"
}

seed_internal_plugin_layout() {
  local target="$1"
  local manifest="$target/.agents-orchestrator-manifest"
  mkdir -p "$target/plugins/model-configurator/profiles"
  printf 'old tui\n' > "$target/plugins/model-configurator.tsx"
  printf 'old support\n' > "$target/plugins/model-configurator/domain.ts"
  cp "$ROOT/profiles/default.json" "$target/plugins/model-configurator/profiles/default.json"
  ln -s "$ROOT/domains/meta/plugins/skill-registry.ts" "$target/plugins/skill-registry.ts"
  ln -s "$ROOT/domains/common/plugins/graphify-init.ts" "$target/plugins/graphify-init.ts"
  printf '{"plugin":["%s"],"theme":"system"}\n' "$OLD_PLUGIN_SPEC" > "$target/tui.json"
  printf '{"dependencies":{"jsonc-parser":"3.3.1"},"foreign":true}\n' > "$target/package.json"
  {
    printf 'dir\t%s\n' "$target/plugins/model-configurator"
    printf 'dir\t%s\n' "$target/plugins/model-configurator/profiles"
    printf 'file\t%s\n' "$target/plugins/model-configurator.tsx"
    printf 'file\t%s\n' "$target/plugins/model-configurator/domain.ts"
    printf 'file\t%s\n' "$target/plugins/model-configurator/profiles/default.json"
    printf 'link\t%s\n' "$target/plugins/skill-registry.ts"
    printf 'link\t%s\n' "$target/plugins/graphify-init.ts"
    printf 'managed-array\t%s\tplugin\t%s\n' "$target/tui.json" "$OLD_PLUGIN_SPEC"
    printf 'managed-object\t%s\tdependencies.jsonc-parser\t3.3.1\n' "$target/package.json"
  } > "$manifest"
}

shouldMigrateInternalPluginInstallToExternalBundles() {
  local scratch target artifacts binary user_config
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-migration.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  mkdir -p "$target/plugins"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  seed_internal_plugin_layout "$target"
  user_config="$target/opencode.jsonc"
  printf '{"agent":{"orchestraitor":{"model":"provider/model"}}}\n' > "$user_config"
  cp "$user_config" "$scratch/config-before"

  # Given a manifest from the former in-repository plugin layout
  # When all domains are synchronized through the external descriptors
  # Then old sources/dependency disappear and user assignments remain byte-identical
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --target "$target" >/dev/null
  [ ! -e "$target/plugins/model-configurator.tsx" ] || fail "migration retained old TUI source"
  [ ! -e "$target/plugins/model-configurator/domain.ts" ] || fail "migration retained old TUI support source"
  [ ! -L "$target/plugins/skill-registry.ts" ] || fail "migration retained old skill registry link"
  [ ! -L "$target/plugins/graphify-init.ts" ] || fail "migration retained old Graphify link"
  [ -f "$target/plugins/model-configurator/tui.js" ] || fail "migration missed external model bundle"
  [ -f "$target/plugins/skill-registry.js" ] || fail "migration missed external skill bundle"
  [ -f "$target/plugins/graphify-init.js" ] || fail "migration missed external Graphify bundle"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null ||
    fail "migration did not register the external TUI entry"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$OLD_PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "migration retained old TUI registration"
  assert_json_value "$target/package.json" '.dependencies["jsonc-parser"] // "absent"' "absent" "migration retained jsonc-parser"
  assert_json_value "$target/package.json" '.foreign' "true" "migration changed foreign package data"
  assert_file_equals "$user_config" "$scratch/config-before" "migration changed user agent assignments"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-object' 0 "new manifest retained old dependency ownership"
  rm -rf "$scratch"
  pass "shouldMigrateInternalPluginInstallToExternalBundles"
}

shouldInstallOnlyInsideProjectTarget() {
  local scratch project artifacts binary
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-project.XXXXXX")"
  project="$scratch/project"
  artifacts="$scratch/artifacts"
  mkdir -p "$project"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"

  # Given project mode in an isolated working directory
  # When meta is installed
  # Then bundles, profile, and TUI config stay under .opencode
  (cd "$project" && AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta --project >/dev/null)
  [ -f "$project/.opencode/plugins/model-configurator/tui.js" ] || fail "project TUI bundle missing"
  [ -f "$project/.opencode/plugins/skill-registry.js" ] || fail "project server bundle missing"
  [ -f "$project/.opencode/tui.json" ] || fail "project tui.json missing"
  [ ! -e "$project/tui.json" ] || fail "project install escaped .opencode"
  rm -rf "$scratch"
  pass "shouldInstallOnlyInsideProjectTarget"
}

shouldMatchPinnedRemoteArtifacts() {
  local descriptor repository commit artifact expected scratch downloaded actual
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-remote.XXXXXX")"

  # Given every production descriptor
  # When its commit-pinned raw artifact is downloaded
  # Then the bytes match the reviewed SHA-256 lock
  for descriptor in "$ROOT"/domains/*/external-plugins/*.json; do
    [ -f "$descriptor" ] || continue
    repository="$(jq -er .repository "$descriptor")"
    commit="$(jq -er .commit "$descriptor")"
    artifact="$(jq -er .artifact "$descriptor")"
    expected="$(jq -er .sha256 "$descriptor")"
    downloaded="$scratch/$(basename "$descriptor").js"
    curl -fsSL --retry 2 --connect-timeout 10 --max-time 90 \
      "https://raw.githubusercontent.com/$repository/$commit/$artifact" -o "$downloaded"
    actual="$(sha256_file "$downloaded")"
    [ "$actual" = "$expected" ] || fail "$descriptor checksum mismatch"
  done
  rm -rf "$scratch"
  pass "shouldMatchPinnedRemoteArtifacts"
}

run_contracts() {
  shouldPreserveJsoncManagedEntry
  shouldHandleMissingPropertyAndTrailingComment
  shouldInstallRepairStatusAndUninstallExternalPlugins
  shouldPreservePreexistingTuiRegistration
  shouldAbortBeforeMutationOnInvalidPreconditions
  shouldRollbackExternalPluginTransaction
  shouldSyncAwayDeselectedExternalPlugins
  shouldMigrateInternalPluginInstallToExternalBundles
  shouldInstallOnlyInsideProjectTarget
}

case "${1:-contracts}" in
  contracts) run_contracts ;;
  remote) shouldMatchPinnedRemoteArtifacts ;;
  project) shouldInstallOnlyInsideProjectTarget ;;
  *) fail "unknown suite: $1" ;;
esac

printf 'PASS: %d external plugin installer checks.\n' "$PASSES"
