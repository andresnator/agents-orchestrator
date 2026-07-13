#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/scripts/fixtures/model-configurator"
INSTALLER="$ROOT/installers/opencode.sh"
PLUGIN_SPEC="./tui-plugins/model-configurator.tsx"
JSONC_VERSION="3.3.1"
MIN_OPENCODE_VERSION="1.17.15"
OPENCODE_PLUGIN_VERSION="1.17.15"
OPENTUI_VERSION="0.4.3"
TYPESCRIPT_VERSION="5.9.3"
TSX_VERSION="4.20.6"
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

shouldPreserveJsoncWhenAddingAndRemovingManagedEntry() {
  local scratch rendered removed
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-contract.XXXXXX")"
  rendered="$scratch/rendered.jsonc"
  removed="$scratch/removed.jsonc"

  # Given a user-owned JSONC document with comments, trailing commas, and Unicode
  # When the exact plugin entry is added and then removed
  # Then additions match the whole expected document and foreign content survives removal
  python3 "$ROOT/scripts/jsonc-array.py" add "$FIXTURES/tui-comments-before.jsonc" plugin "$PLUGIN_SPEC" > "$rendered"
  assert_file_equals "$rendered" "$FIXTURES/tui-comments-after-add.jsonc" "JSONC add changed unexpected bytes"
  python3 "$ROOT/scripts/jsonc-array.py" remove "$rendered" plugin "$PLUGIN_SPEC" > "$removed"
  python3 "$ROOT/scripts/jsonc-array.py" has "$removed" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "JSONC remove retained the managed entry"
  assert_contains "$removed" "// Keep this inline comment." "JSONC remove dropped a foreign comment"
  assert_contains "$removed" '"./foreign.tsx"' "JSONC remove dropped a foreign plugin"
  assert_contains "$removed" '"label": "Configuración ágil"' "JSONC remove damaged Unicode"
  rm -rf "$scratch"
  pass "shouldPreserveJsoncWhenAddingAndRemovingManagedEntry"
}

shouldAddPluginPropertyWhenMissing() {
  local scratch rendered
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-contract.XXXXXX")"
  rendered="$scratch/rendered.jsonc"

  # Given a valid JSONC object without plugin
  # When the managed entry is added
  # Then the complete result matches the approved fixture
  python3 "$ROOT/scripts/jsonc-array.py" add "$FIXTURES/tui-missing-plugin-before.jsonc" plugin "$PLUGIN_SPEC" > "$rendered"
  assert_file_equals "$rendered" "$FIXTURES/tui-missing-plugin-after-add.jsonc" "missing plugin property rendered unexpectedly"
  rm -rf "$scratch"
  pass "shouldAddPluginPropertyWhenMissing"
}

shouldRejectInvalidOrWrongShapeJsonc() {
  local scratch invalid wrong status
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-contract.XXXXXX")"
  invalid="$scratch/invalid.jsonc"
  wrong="$scratch/wrong.jsonc"
  printf '{ invalid\n' > "$invalid"
  printf '{"plugin": true}\n' > "$wrong"

  status=0
  python3 "$ROOT/scripts/jsonc-array.py" has "$invalid" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "invalid JSONC did not return status 2"
  status=0
  python3 "$ROOT/scripts/jsonc-array.py" has "$wrong" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] || fail "non-array plugin property did not return status 2"
  rm -rf "$scratch"
  pass "shouldRejectInvalidOrWrongShapeJsonc"
}

shouldAvoidAddingThirdEntryWhenJsoncAlreadyContainsDuplicates() {
  local scratch duplicate rendered status
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-contract.XXXXXX")"
  duplicate="$scratch/duplicate.jsonc"
  rendered="$scratch/rendered.jsonc"
  printf '{\n  "plugin": [\n    "%s",\n    "./foreign.tsx",\n    "%s",\n  ],\n}\n' "$PLUGIN_SPEC" "$PLUGIN_SPEC" > "$duplicate"

  # Given a malformed-by-ownership but parseable list with duplicate exact entries
  # When add is requested
  # Then no third entry is introduced and the document is emitted unchanged
  status=0
  python3 "$ROOT/scripts/jsonc-array.py" add "$duplicate" plugin "$PLUGIN_SPEC" > "$rendered" || status=$?
  [ "$status" -eq 3 ] || fail "duplicate JSONC add did not report no change"
  assert_file_equals "$duplicate" "$rendered" "duplicate JSONC add changed the document"
  assert_count "$rendered" "$PLUGIN_SPEC" 2 "duplicate JSONC add introduced another entry"
  rm -rf "$scratch"
  pass "shouldAvoidAddingThirdEntryWhenJsoncAlreadyContainsDuplicates"
}

shouldExposePinnedPluginContracts() {
  local entry="$ROOT/domains/meta/tui-plugins/model-configurator.tsx"
  assert_contains "$entry" 'agents-orchestrator.model-configurator"' "plugin id changed"
  assert_contains "$entry" 'agents-orchestrator.model-configurator.open"' "command id changed"
  assert_contains "$entry" 'model-configurator"' "slash command changed"
  assert_contains "$entry" "$MIN_OPENCODE_VERSION\"" "minimum OpenCode version changed"
  assert_contains "$entry" "$JSONC_VERSION\"" "jsonc-parser version changed"
  pass "shouldExposePinnedPluginContracts"
}

shouldInstallReinstallStatusAndUninstallWithoutOwningForeignConfig() {
  local scratch target binary old_binary status_output
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-installer.XXXXXX")"
  target="$scratch/target"
  mkdir -p "$target"
  cp "$FIXTURES/tui-comments-before.jsonc" "$target/tui.json"
  printf '{"name":"foreign-package","devDependencies":{"foreign":"1.0.0"}}\n' > "$target/package.json"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  old_binary="$(make_fake_opencode "$scratch/old-bin" "1.17.14")"

  # Given foreign target configuration and a compatible OpenCode binary
  # When install, reinstall, status, and uninstall run
  # Then only exact installer-owned values and links are managed
  OPENCODE_BIN="$binary" "$INSTALLER" install --domain meta --target "$target" >/dev/null
  OPENCODE_BIN="$binary" "$INSTALLER" install --domain meta --target "$target" >/dev/null
  [ -f "$target/tui-plugins/model-configurator.tsx" ] && [ ! -L "$target/tui-plugins/model-configurator.tsx" ] ||
    fail "TUI entrypoint was not generated locally"
  [ -d "$target/tui-plugins/model-configurator" ] && [ ! -L "$target/tui-plugins/model-configurator" ] ||
    fail "TUI companion directory was not generated locally"
  assert_json_value "$target/tui-plugins/model-configurator/agents.json" \
    '.[0] | (has("name") and has("domain") and has("mode"))' "true" "agent catalog entries lost the domain shape"
  [ -f "$target/tui.json.bak" ] || fail "install did not keep a single fixed tui.json backup"
  if ls "$target"/tui.json.bak.* >/dev/null 2>&1; then fail "install accumulated timestamped tui.json backups"; fi
  if ls "$target"/package.json.bak.* >/dev/null 2>&1; then fail "install accumulated timestamped package.json backups"; fi
  assert_count "$target/tui.json" "$PLUGIN_SPEC" 1 "reinstall duplicated the plugin entry"
  assert_json_value "$target/package.json" '.dependencies["jsonc-parser"]' "$JSONC_VERSION" "dependency was not pinned"
  assert_json_value "$target/package.json" '.devDependencies.foreign' "1.0.0" "foreign package data changed"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-array' 1 "manifest did not narrowly own the TUI entry"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-object' 1 "manifest did not narrowly own the dependency"

  status_output="$scratch/status.txt"
  OPENCODE_BIN="$binary" "$INSTALLER" status --domain meta --target "$target" > "$status_output"
  assert_contains "$status_output" $'meta\ttui-plugins\tmodel-configurator.tsx\t-\tgenerated+registered' "status did not report TUI registration"
  OPENCODE_BIN="$old_binary" "$INSTALLER" status --domain meta --target "$target" > "$status_output"
  assert_contains "$status_output" "opencode >= $MIN_OPENCODE_VERSION is required" "status did not report runtime incompatibility"

  "$INSTALLER" uninstall --target "$target" >/dev/null
  [ ! -e "$target/tui-plugins/model-configurator.tsx" ] || fail "uninstall retained the TUI entrypoint"
  [ ! -e "$target/tui-plugins/model-configurator" ] || fail "uninstall retained the TUI companion"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "uninstall retained the owned TUI entry"
  assert_contains "$target/tui.json" '"./foreign.tsx"' "uninstall removed a foreign TUI plugin"
  assert_contains "$target/tui.json" '// Keep this inline comment.' "uninstall removed a foreign comment"
  assert_json_value "$target/package.json" '.dependencies["jsonc-parser"] // "absent"' "absent" "uninstall retained owned dependency"
  assert_json_value "$target/package.json" '.devDependencies.foreign' "1.0.0" "uninstall changed foreign package data"
  rm -rf "$scratch"
  pass "shouldInstallReinstallStatusAndUninstallWithoutOwningForeignConfig"
}

shouldPreservePreexistingExactValuesOnUninstall() {
  local scratch target binary
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-installer.XXXXXX")"
  target="$scratch/target"
  mkdir -p "$target"
  printf '{"plugin":["%s"]}\n' "$PLUGIN_SPEC" > "$target/tui.json"
  printf '{"dependencies":{"jsonc-parser":"%s"},"foreign":true}\n' "$JSONC_VERSION" > "$target/package.json"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"

  # Given exact values that predate installer ownership
  # When the component is installed and uninstalled
  # Then the manifest does not claim or remove those values
  OPENCODE_BIN="$binary" "$INSTALLER" install --domain meta --target "$target" >/dev/null
  assert_count "$target/.agents-orchestrator-manifest" 'managed-array' 0 "installer claimed a preexisting TUI value"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-object' 0 "installer claimed a preexisting dependency"
  "$INSTALLER" uninstall --target "$target" >/dev/null
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 ||
    fail "uninstall removed a preexisting TUI value"
  assert_json_value "$target/package.json" '.dependencies["jsonc-parser"]' "$JSONC_VERSION" "uninstall removed a preexisting dependency"
  rm -rf "$scratch"
  pass "shouldPreservePreexistingExactValuesOnUninstall"
}

shouldAbortBeforeMutationWhenVersionOrConfigIsInvalid() {
  local scratch target old_binary new_binary before
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-installer.XXXXXX")"
  target="$scratch/target"
  mkdir -p "$target"
  printf '{"foreign":true}\n' > "$target/package.json"
  printf '{"plugin":[]}\n' > "$target/tui.json"
  before="$scratch/before"
  cp -R "$target" "$before"
  old_binary="$(make_fake_opencode "$scratch/old-bin" "1.17.14")"
  new_binary="$(make_fake_opencode "$scratch/new-bin" "$MIN_OPENCODE_VERSION")"

  # Given an incompatible runtime or a foreign dependency conflict
  # When installation is attempted
  # Then target bytes remain unchanged
  if OPENCODE_BIN="$old_binary" "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
    fail "installer accepted an old OpenCode version"
  fi
  diff -qr "$before" "$target" >/dev/null || fail "version rejection mutated the target"

  printf '{"dependencies":{"jsonc-parser":"9.9.9"},"foreign":true}\n' > "$target/package.json"
  rm -rf "$before"
  cp -R "$target" "$before"
  if OPENCODE_BIN="$new_binary" "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
    fail "installer accepted a foreign jsonc-parser version"
  fi
  diff -qr "$before" "$target" >/dev/null || fail "dependency conflict mutated the target"
  rm -rf "$scratch"
  pass "shouldAbortBeforeMutationWhenVersionOrConfigIsInvalid"
}

shouldRollbackInstallerWhenCommitStepFails() {
  local scratch target binary before step
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-installer.XXXXXX")"
  target="$scratch/target"
  before="$scratch/before"
  mkdir -p "$target"
  cp "$FIXTURES/tui-comments-before.jsonc" "$target/tui.json"
  printf '{"name":"foreign-package","foreign":true}\n' > "$target/package.json"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"

  # Given a valid target and an injected failure at each commit boundary
  # When installation exits unsuccessfully
  # Then links, managed files, backups, and the prior manifest are restored
  for step in after-links after-managed-array after-managed-object before-manifest after-manifest; do
    rm -rf "$before"
    cp -R "$target" "$before"
    if AGENTS_ORCHESTRATOR_TEST_FAIL_STEP="$step" OPENCODE_BIN="$binary" \
      "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
      fail "installer did not inject failure at $step"
    fi
    diff -qr "$before" "$target" >/dev/null || fail "installer did not roll back $step"
  done
  rm -rf "$scratch"
  pass "shouldRollbackInstallerWhenCommitStepFails"
}

shouldRollbackStaleRemovalWhenSyncFails() {
  local scratch target binary before
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-installer.XXXXXX")"
  target="$scratch/target"
  before="$scratch/before"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  OPENCODE_BIN="$binary" "$INSTALLER" install --domain meta --target "$target" >/dev/null
  cp -R "$target" "$before"

  # Given a prior manifest that owns TUI links and managed values
  # When a deselecting sync fails after stale removal
  # Then the complete prior installation is restored
  if AGENTS_ORCHESTRATOR_TEST_FAIL_STEP=before-manifest \
    "$INSTALLER" install --domain common --target "$target" >/dev/null 2>&1; then
    fail "sync did not inject failure after stale removal"
  fi
  diff -qr "$before" "$target" >/dev/null || fail "failed sync did not restore stale-owned artifacts"
  rm -rf "$scratch"
  pass "shouldRollbackStaleRemovalWhenSyncFails"
}

shouldSyncAwayManagedTuiValuesWhenMetaIsDeselected() {
  local scratch target binary
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-installer.XXXXXX")"
  target="$scratch/target"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"

  # Given an installed meta-domain TUI plugin
  # When a later sync selects only common
  # Then stale links and narrowly owned config values are removed
  OPENCODE_BIN="$binary" "$INSTALLER" install --domain meta --target "$target" >/dev/null
  "$INSTALLER" install --domain common --target "$target" >/dev/null
  [ ! -e "$target/tui-plugins/model-configurator.tsx" ] || fail "sync retained stale TUI entrypoint"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "sync retained stale managed TUI value"
  assert_json_value "$target/package.json" '.dependencies["jsonc-parser"] // "absent"' "absent" "sync retained stale dependency"
  rm -rf "$scratch"
  pass "shouldSyncAwayManagedTuiValuesWhenMetaIsDeselected"
}

shouldUpgradeFromLegacyManifestWithoutTouchingAssignments() {
  local scratch target binary user_config
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-legacy.XXXXXX")"
  target="$scratch/target"
  mkdir -p "$target/plugins"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  user_config="$target/opencode.jsonc"
  printf '{\n  // User assignments must survive the upgrade.\n  "agent": {\n    "orchestraitor": {"model": "anthropic/claude", "variant": "high"}\n  },\n}\n' > "$user_config"
  cp "$user_config" "$scratch/config-before"
  ln -s "$scratch/old-repo/retired-exporter.ts" "$target/plugins/retired-exporter.ts"
  printf 'link\t%s\n' "$target/plugins/retired-exporter.ts" > "$target/.agents-orchestrator-manifest"

  # Given a legacy manifest owning a retired plugin link beside user assignments
  # When the new installer syncs the meta domain
  # Then the retired link disappears and user configuration stays byte-identical
  OPENCODE_BIN="$binary" "$INSTALLER" install --domain meta --target "$target" >/dev/null
  [ ! -e "$target/plugins/retired-exporter.ts" ] && [ ! -L "$target/plugins/retired-exporter.ts" ] ||
    fail "legacy-owned retired plugin link survived the sync"
  [ -f "$target/tui-plugins/model-configurator.tsx" ] || fail "upgrade did not install the TUI entrypoint"
  assert_file_equals "$user_config" "$scratch/config-before" "upgrade touched user agent assignments"
  rm -rf "$scratch"
  pass "shouldUpgradeFromLegacyManifestWithoutTouchingAssignments"
}

shouldInstallOnlyInsideProjectTarget() {
  local scratch project binary
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-project.XXXXXX")"
  project="$scratch/project"
  mkdir -p "$project"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"

  # Given project mode in an isolated working directory
  # When meta is installed
  # Then all runtime artifacts stay under .opencode
  (cd "$project" && OPENCODE_BIN="$binary" "$INSTALLER" install --domain meta --project >/dev/null)
  [ -f "$project/.opencode/tui-plugins/model-configurator.tsx" ] || fail "project entrypoint missing"
  [ -f "$project/.opencode/tui.json" ] || fail "project tui.json missing"
  [ ! -e "$project/tui.json" ] || fail "project install escaped .opencode"
  rm -rf "$scratch"
  pass "shouldInstallOnlyInsideProjectTarget"
}

run_contracts() {
  run_shell_contracts
  run_typescript_contracts
}

run_shell_contracts() {
  shouldPreserveJsoncWhenAddingAndRemovingManagedEntry
  shouldAddPluginPropertyWhenMissing
  shouldRejectInvalidOrWrongShapeJsonc
  shouldAvoidAddingThirdEntryWhenJsoncAlreadyContainsDuplicates
  shouldExposePinnedPluginContracts
  shouldInstallReinstallStatusAndUninstallWithoutOwningForeignConfig
  shouldPreservePreexistingExactValuesOnUninstall
  shouldAbortBeforeMutationWhenVersionOrConfigIsInvalid
  shouldRollbackInstallerWhenCommitStepFails
  shouldRollbackStaleRemovalWhenSyncFails
  shouldSyncAwayManagedTuiValuesWhenMetaIsDeselected
  shouldUpgradeFromLegacyManifestWithoutTouchingAssignments
  shouldInstallOnlyInsideProjectTarget
}

run_typescript_contracts() {
  local scratch
  command -v npm >/dev/null 2>&1 || fail "npm is required for isolated TypeScript contracts"
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-typescript.XXXXXX")"
  mkdir -p "$scratch/scripts/fixtures/model-configurator" "$scratch/domains/meta/tui-plugins"
  cp "$ROOT/scripts/model-configurator-contracts.ts" "$scratch/scripts/"
  cp "$FIXTURES/config-before.jsonc" "$FIXTURES/config-after.jsonc" "$scratch/scripts/fixtures/model-configurator/"
  cp -R "$ROOT/domains/meta/tui-plugins/model-configurator" "$scratch/domains/meta/tui-plugins/"
  cp "$ROOT/domains/meta/tui-plugins/model-configurator.tsx" "$scratch/domains/meta/tui-plugins/"
  printf '%s\n' '{"name":"model-configurator-contracts","private":true,"type":"module"}' > "$scratch/package.json"
  printf '%s\n' '{"compilerOptions":{"target":"ES2022","module":"ESNext","moduleResolution":"Bundler","strict":true,"noEmit":true,"jsx":"preserve","jsxImportSource":"@opentui/solid","types":["node"],"skipLibCheck":true},"include":["scripts/**/*.ts","domains/**/*.ts","domains/**/*.tsx"]}' > "$scratch/tsconfig.json"
  npm install --prefix "$scratch" --no-package-lock --ignore-scripts --silent \
    "typescript@$TYPESCRIPT_VERSION" \
    "tsx@$TSX_VERSION" \
    "@types/node@24.0.0" \
    "@opencode-ai/plugin@$OPENCODE_PLUGIN_VERSION" \
    "@opentui/core@$OPENTUI_VERSION" \
    "@opentui/solid@$OPENTUI_VERSION" \
    "@opentui/keymap@$OPENTUI_VERSION" \
    "jsonc-parser@$JSONC_VERSION"
  "$scratch/node_modules/.bin/tsc" -p "$scratch/tsconfig.json"
  "$scratch/node_modules/.bin/tsx" "$scratch/scripts/model-configurator-contracts.ts"
  rm -rf "$scratch"
  pass "typescript-contracts"
}

inspect_install() {
  local target="$1"
  [ -f "$target/tui-plugins/model-configurator.tsx" ] || fail "installed entrypoint missing"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 || fail "installed TUI value missing"
  assert_json_value "$target/package.json" '.dependencies["jsonc-parser"]' "$JSONC_VERSION" "installed dependency missing"
  pass "inspect-install"
}

inspect_uninstall() {
  local target="$1"
  [ ! -e "$target/tui-plugins/model-configurator.tsx" ] || fail "uninstalled entrypoint remains"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_SPEC" >/dev/null 2>&1 && fail "uninstalled TUI value remains"
  pass "inspect-uninstall"
}

run_smoke() {
  local scratch binary
  binary="${OPENCODE_BIN:-}"
  [ -n "$binary" ] && [ -x "$binary" ] || fail "smoke requires executable OPENCODE_BIN"
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/model-configurator-smoke.XXXXXX")"
  mkdir -p "$scratch/project" "$scratch/home" "$scratch/config" "$scratch/data" "$scratch/cache" "$scratch/state"
  OPENCODE_BIN="$binary" "$INSTALLER" install --domain meta --target "$scratch/config/opencode" >/dev/null
  HOME="$scratch/home" \
    XDG_CONFIG_HOME="$scratch/config" \
    XDG_DATA_HOME="$scratch/data" \
    XDG_CACHE_HOME="$scratch/cache" \
    XDG_STATE_HOME="$scratch/state" \
    python3 "$ROOT/scripts/model-configurator-smoke.py" "$binary" "$scratch/project" "$scratch/terminal.log"
  "$INSTALLER" uninstall --target "$scratch/config/opencode" >/dev/null
  rm -rf "$scratch"
  pass "smoke"
}

case "${1:-contracts}" in
  contracts) run_contracts ;;
  shell-contracts) run_shell_contracts ;;
  typescript-contracts) run_typescript_contracts ;;
  installer-project) shouldInstallOnlyInsideProjectTarget ;;
  installer-upgrade-from-legacy) shouldUpgradeFromLegacyManifestWithoutTouchingAssignments ;;
  inspect-install) [ "$#" -eq 2 ] || fail "inspect-install requires TARGET"; inspect_install "$2" ;;
  inspect-uninstall) [ "$#" -eq 2 ] || fail "inspect-uninstall requires TARGET"; inspect_uninstall "$2" ;;
  smoke) run_smoke ;;
  *) fail "unknown suite: $1" ;;
esac

printf 'PASS: %d model configurator checks.\n' "$PASSES"
