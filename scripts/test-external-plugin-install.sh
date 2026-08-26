#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/scripts/fixtures/external-plugins"
INSTALLER="$ROOT/installers/opencode.sh"
PLUGIN_PACKAGE="opencode-models-presets"
PLUGIN_VERSION="0.3.1"
PLUGIN_SPEC="$PLUGIN_PACKAGE@$PLUGIN_VERSION"
OLD_EXTERNAL_PLUGIN_SPEC="./plugins/model-configurator/tui.js"
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

plugin_entry() {
  local profiles_dir="$1"
  jq -cn --arg spec "$PLUGIN_SPEC" --arg profilesDir "$profiles_dir" '[$spec, {profilesDir: $profilesDir}]'
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

make_fake_curl() {
  local binary="$1"
  cat > "$binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) shift; output="$1" ;;
    https://*) url="$1" ;;
  esac
  shift
done
case "$url" in
  */server.js) cp "$FAKE_SERVER_ARTIFACT" "$output" ;;
  */tui.js) cp "$FAKE_TUI_ARTIFACT" "$output" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$binary"
}

make_external_artifacts() {
  local root="$1"
  mkdir -p "$root"
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
  python3 "$ROOT/scripts/jsonc-array.py" add "$FIXTURES/tui-comments-before.jsonc" plugin "$OLD_EXTERNAL_PLUGIN_SPEC" > "$rendered"
  assert_file_equals "$rendered" "$FIXTURES/tui-comments-after-add.jsonc" "JSONC add changed unexpected bytes"
  python3 "$ROOT/scripts/jsonc-array.py" remove "$rendered" plugin "$OLD_EXTERNAL_PLUGIN_SPEC" > "$removed"
  python3 "$ROOT/scripts/jsonc-array.py" has "$removed" plugin "$OLD_EXTERNAL_PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "JSONC remove retained the managed entry"
  assert_contains "$removed" "// Keep this inline comment." "JSONC remove dropped a foreign comment"
  assert_contains "$removed" '"./foreign.tsx"' "JSONC remove dropped a foreign plugin"
  assert_contains "$removed" '"label": "Configuración ágil"' "JSONC remove damaged Unicode"
  rm -rf "$scratch"
  pass "shouldPreserveJsoncManagedEntry"
}

shouldPreserveStructuredJsoncManagedEntry() {
  local scratch original rendered removed entry package_removed
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-jsonc-structured.XXXXXX")"
  original="$scratch/original.jsonc"
  rendered="$scratch/rendered.jsonc"
  removed="$scratch/removed.jsonc"
  package_removed="$scratch/package-removed.jsonc"
  entry="$(plugin_entry "/tmp/model-profiles")"

  cat > "$original" <<'EOF'
{
  "plugin": [
    "./foreign.tsx" // Keep this comment.
  ],
  "theme": "system"
}
EOF

  # Given user-owned JSONC and a structured npm plugin entry
  # When the exact entry is added, found, and removed
  # Then formatting and foreign values return byte-identically
  python3 "$ROOT/scripts/jsonc-array.py" add-json "$original" plugin "$entry" > "$rendered"
  python3 "$ROOT/scripts/jsonc-array.py" has-json "$rendered" plugin "$entry" >/dev/null ||
    fail "structured JSONC add did not register the exact entry"
  python3 "$ROOT/scripts/jsonc-array.py" has-npm "$rendered" plugin "$PLUGIN_PACKAGE" >/dev/null ||
    fail "structured JSONC entry was not recognized by npm package"
  python3 "$ROOT/scripts/jsonc-array.py" remove-json "$rendered" plugin "$entry" > "$removed"
  assert_file_equals "$removed" "$original" "structured JSONC remove changed foreign content"

  printf '{"plugin":["%s",["%s",{"profilesDir":"/tmp/other"}],"./foreign.tsx"]}\n' \
    "$PLUGIN_PACKAGE" "$PLUGIN_SPEC" > "$rendered"
  python3 "$ROOT/scripts/jsonc-array.py" remove-npm "$rendered" plugin "$PLUGIN_PACKAGE" > "$package_removed"
  python3 "$ROOT/scripts/jsonc-array.py" has-npm "$package_removed" plugin "$PLUGIN_PACKAGE" >/dev/null 2>&1 &&
    fail "npm package removal retained a string or tuple entry"
  assert_contains "$package_removed" '"./foreign.tsx"' "npm package removal changed a foreign entry"
  rm -rf "$scratch"
  pass "shouldPreserveStructuredJsoncManagedEntry"
}

shouldHandleMissingPropertyAndTrailingComment() {
  local scratch rendered
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-jsonc.XXXXXX")"
  rendered="$scratch/rendered.jsonc"

  # Given valid JSONC shapes that previously exposed separator bugs
  # When the managed value is added
  # Then both complete documents match their approved fixtures
  python3 "$ROOT/scripts/jsonc-array.py" add "$FIXTURES/tui-missing-plugin-before.jsonc" plugin "$OLD_EXTERNAL_PLUGIN_SPEC" > "$rendered"
  assert_file_equals "$rendered" "$FIXTURES/tui-missing-plugin-after-add.jsonc" "missing plugin property rendered unexpectedly"
  python3 "$ROOT/scripts/jsonc-array.py" add "$FIXTURES/tui-trailing-comment-before.jsonc" plugin "$OLD_EXTERNAL_PLUGIN_SPEC" > "$rendered"
  assert_file_equals "$rendered" "$FIXTURES/tui-trailing-comment-after-add.jsonc" "trailing-comment add rendered unexpectedly"
  rm -rf "$scratch"
  pass "shouldHandleMissingPropertyAndTrailingComment"
}

shouldIgnoreCommentCommasWhenRemovingJsoncSeparators() {
  local scratch scalar_source scalar_removed array_source array_removed
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-jsonc-comment-comma.XXXXXX")"
  scalar_source="$scratch/scalar-source.jsonc"
  scalar_removed="$scratch/scalar-removed.jsonc"
  array_source="$scratch/array-source.jsonc"
  array_removed="$scratch/array-removed.jsonc"
  cat > "$scalar_source" <<'EOF'
{
  "theme": "dark", // keep, please
  "subagent_depth": 2
}
EOF
  cat > "$array_source" <<EOF
{
  "plugin": [
    "./foreign.tsx", // keep, please
    "$OLD_EXTERNAL_PLUGIN_SPEC"
  ]
}
EOF

  # Given scalar and array separators followed by comments containing commas
  # When the final managed property and array value are removed
  # Then only syntactic separator tokens are deleted
  python3 "$ROOT/scripts/jsonc-array.py" remove-property "$scalar_source" subagent_depth > "$scalar_removed"
  python3 "$ROOT/scripts/jsonc-array.py" remove "$array_source" plugin "$OLD_EXTERNAL_PLUGIN_SPEC" > "$array_removed"
  assert_contains "$scalar_removed" "// keep, please" "scalar remove changed a comment comma"
  assert_contains "$array_removed" "// keep, please" "array remove changed a comment comma"
  python3 "$ROOT/scripts/jsonc-array.py" has "$array_removed" plugin "$OLD_EXTERNAL_PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "array remove retained the managed value"
  rm -rf "$scratch"
  pass "shouldIgnoreCommentCommasWhenRemovingJsoncSeparators"
}

shouldPreserveJsoncScalarProperties() {
  local scratch original managed depth restored removed status
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-jsonc-scalar.XXXXXX")"
  original="$scratch/original.jsonc"
  managed="$scratch/managed.jsonc"
  depth="$scratch/depth.jsonc"
  restored="$scratch/restored.jsonc"
  removed="$scratch/removed.jsonc"
  cat > "$original" <<'EOF'
{
  // Keep this profile comment.
  "default_agent": "mentor", // Keep this inline comment.
  "subagent_depth": 4,
  "foreign": {"keep": true},
}
EOF

  python3 "$ROOT/scripts/jsonc-array.py" set "$original" default_agent '"custom-primary"' > "$managed"
  python3 "$ROOT/scripts/jsonc-array.py" set "$managed" subagent_depth 2 > "$depth"
  [ "$(python3 "$ROOT/scripts/jsonc-array.py" get "$depth" default_agent)" = '"custom-primary"' ] ||
    fail "JSONC scalar set/get lost default_agent"
  [ "$(python3 "$ROOT/scripts/jsonc-array.py" get "$depth" subagent_depth)" = 2 ] ||
    fail "JSONC scalar set/get lost subagent_depth"
  assert_contains "$depth" "// Keep this profile comment." "JSONC scalar set dropped a comment"
  assert_contains "$depth" '"foreign": {"keep": true}' "JSONC scalar set dropped a foreign key"

  python3 "$ROOT/scripts/jsonc-array.py" set "$depth" default_agent '"mentor"' > "$restored"
  python3 "$ROOT/scripts/jsonc-array.py" remove-property "$restored" subagent_depth > "$removed"
  set +e
  python3 "$ROOT/scripts/jsonc-array.py" get "$removed" subagent_depth >/dev/null
  status=$?
  set -e
  [ "$status" -eq 1 ] || fail "JSONC scalar remove retained subagent_depth"
  assert_contains "$removed" "// Keep this inline comment." "JSONC scalar restore dropped inline comment"
  assert_contains "$removed" '"foreign": {"keep": true}' "JSONC scalar remove dropped a foreign key"
  rm -rf "$scratch"
  pass "shouldPreserveJsoncScalarProperties"
}

shouldInstallRepairStatusAndUninstallExternalPlugins() {
  local scratch target artifacts binary status_output before_package entry preset_store
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
  entry="$(plugin_entry "$target/model-profiles")"
  preset_store="$target/model-configurator-presets.json"
  printf '{"presets":{"keep":true}}\n' > "$preset_store"

  # Given a compatible runtime, foreign config, and deterministic external artifacts
  # When install, repair, status, reinstall, and uninstall run
  # Then only pinned server bundles, profile snapshots, and the exact npm tuple are owned
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta,common --target "$target" >/dev/null
  [ ! -e "$target/plugins/model-configurator" ] || fail "npm install retained a copied model configurator bundle"
  [ -f "$target/model-profiles/default.json" ] || fail "model profile snapshot missing"
  [ -f "$target/plugins/skill-registry.js" ] || fail "skill registry bundle missing"
  [ -f "$target/plugins/graphify-init.js" ] || fail "Graphify bundle missing"
  assert_file_equals "$target/package.json" "$before_package" "fresh install changed package.json"
  python3 "$ROOT/scripts/jsonc-array.py" has-json "$target/tui.json" plugin "$entry" >/dev/null ||
    fail "install missed the pinned npm tuple"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-array-json' 1 "manifest did not narrowly own the npm tuple"
  assert_count "$target/.agents-orchestrator-manifest" $'managed-array\t' 0 "manifest retained a legacy string TUI entry"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-object' 0 "fresh manifest still owns an npm dependency"

  printf 'corrupt\n' > "$target/plugins/skill-registry.js"
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta,common --target "$target" >/dev/null
  assert_file_equals "$target/plugins/skill-registry.js" "$artifacts/skill-registry.js" "reinstall did not repair a stale bundle"

  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" status --domain meta,common --target "$target" > "$status_output"
  assert_contains "$status_output" $'meta\tnpm-tui-plugins\topencode-models-presets\t-\tregistered@0.3.1' "status missed Models Presets"
  assert_contains "$status_output" $'meta\texternal-server-plugins\tskill-registry\t-\tinstalled@0.1.0' "status missed skill registry"
  assert_contains "$status_output" $'common\texternal-server-plugins\tgraphify-init\t-\tinstalled@0.1.0' "status missed Graphify"

  printf 'corrupt\n' > "$target/model-profiles/default.json"
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" status --domain meta --target "$target" > "$status_output"
  assert_contains "$status_output" $'meta\tnpm-tui-plugins\topencode-models-presets\t-\tstale' "status hid a stale npm TUI profile"
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta,common --target "$target" >/dev/null
  assert_file_equals "$target/model-profiles/default.json" "$ROOT/profiles/default.json" "reinstall did not repair the model profile"

  "$INSTALLER" uninstall --target "$target" >/dev/null
  [ ! -e "$target/model-profiles" ] || fail "uninstall retained model profiles"
  [ ! -e "$target/plugins/skill-registry.js" ] || fail "uninstall retained skill registry"
  [ ! -e "$target/plugins/graphify-init.js" ] || fail "uninstall retained Graphify"
  python3 "$ROOT/scripts/jsonc-array.py" has-json "$target/tui.json" plugin "$entry" >/dev/null 2>&1 &&
    fail "uninstall retained the owned npm tuple"
  assert_contains "$target/tui.json" '"./foreign.tsx"' "uninstall removed a foreign TUI plugin"
  assert_file_equals "$target/package.json" "$before_package" "uninstall changed foreign package.json"
  [ -f "$preset_store" ] || fail "uninstall removed the user preset store"
  rm -rf "$scratch"
  pass "shouldInstallRepairStatusAndUninstallExternalPlugins"
}

shouldStageSameNamedArtifactsByKind() {
  local scratch repo target binary server_artifact tui_artifact server_sha tui_sha
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-kind-stage.XXXXXX")"
  repo="$scratch/repo"
  target="$scratch/target"
  server_artifact="$scratch/server.js"
  tui_artifact="$scratch/tui.js"
  mkdir -p "$repo/installers/lib" "$repo/scripts" "$repo/global"
  mkdir -p "$repo/domains/server/external-plugins" "$repo/domains/tui/external-plugins"
  cp "$ROOT/installers/opencode.sh" "$repo/installers/opencode.sh"
  cp "$ROOT/installers/lib/common.sh" "$repo/installers/lib/common.sh"
  cp "$ROOT/scripts/jsonc-array.py" "$repo/scripts/jsonc-array.py"
  cp "$ROOT/global/AGENTS.md" "$repo/global/AGENTS.md"
  printf 'server bundle\n' > "$server_artifact"
  printf 'tui bundle\n' > "$tui_artifact"
  server_sha="$(sha256_file "$server_artifact")"
  tui_sha="$(sha256_file "$tui_artifact")"
  cat > "$repo/domains/server/external-plugins/shared.server.json" <<EOF
{"schemaVersion":1,"name":"shared","kind":"server","version":"1.0.0","repository":"fixture/shared","commit":"0000000000000000000000000000000000000000","artifact":"dist/server.js","sha256":"$server_sha"}
EOF
  cat > "$repo/domains/tui/external-plugins/shared.tui.json" <<EOF
{"schemaVersion":1,"name":"shared","kind":"tui","version":"1.0.0","repository":"fixture/shared","commit":"0000000000000000000000000000000000000000","artifact":"dist/tui.js","sha256":"$tui_sha"}
EOF
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  make_fake_curl "$scratch/bin/curl"

  # Given server and TUI descriptors with the same type-local name
  # When both artifacts are staged before the transaction
  # Then each destination receives the bundle for its own plugin kind
  FAKE_SERVER_ARTIFACT="$server_artifact" FAKE_TUI_ARTIFACT="$tui_artifact" \
    PATH="$scratch/bin:$PATH" OPENCODE_BIN="$binary" \
    "$repo/installers/opencode.sh" install --target "$target" >/dev/null
  assert_file_equals "$target/plugins/shared.js" "$server_artifact" "same-named TUI bundle replaced the staged server bundle"
  assert_file_equals "$target/plugins/shared/tui.js" "$tui_artifact" "same-named server bundle replaced the staged TUI bundle"
  rm -rf "$scratch"
  pass "shouldStageSameNamedArtifactsByKind"
}

shouldPreservePreexistingTuiRegistration() {
  local scratch target artifacts binary entry
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-preowned.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  mkdir -p "$target"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  entry="$(plugin_entry "$target/model-profiles")"
  printf '{"plugin":[%s]}\n' "$entry" > "$target/tui.json"

  # Given the exact TUI registration predates installer ownership
  # When meta is installed and uninstalled
  # Then the manifest never claims or removes that user value
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null
  assert_count "$target/.agents-orchestrator-manifest" 'managed-array-json' 0 "installer claimed a preexisting npm tuple"
  "$INSTALLER" uninstall --target "$target" >/dev/null
  python3 "$ROOT/scripts/jsonc-array.py" has-json "$target/tui.json" plugin "$entry" >/dev/null 2>&1 ||
    fail "uninstall removed a preexisting npm tuple"
  rm -rf "$scratch"
  pass "shouldPreservePreexistingTuiRegistration"
}

shouldRejectChangedOwnedNpmTupleWithoutForce() {
  local scratch target artifacts binary expected changed intermediate before
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-owned-npm-drift.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  intermediate="$scratch/tui-without-owned.jsonc"
  before="$scratch/before"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"

  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null
  expected="$(plugin_entry "$target/model-profiles")"
  changed="$(plugin_entry "$target/custom-profiles")"
  python3 "$ROOT/scripts/jsonc-array.py" remove-json "$target/tui.json" plugin "$expected" > "$intermediate"
  python3 "$ROOT/scripts/jsonc-array.py" add-json "$intermediate" plugin "$changed" > "$target/tui.json"
  cp -R "$target" "$before"

  # Given an installer-owned tuple whose options were later changed by the user
  # When the same selection is installed without force
  # Then preflight rejects the drift without changing the target
  if AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
    fail "installer replaced a changed owned npm tuple without --force"
  fi
  diff -qr "$before" "$target" >/dev/null || fail "owned npm tuple rejection mutated the target"
  rm -rf "$scratch"
  pass "shouldRejectChangedOwnedNpmTupleWithoutForce"
}

shouldAbortBeforeMutationOnInvalidPreconditions() {
  local scratch target artifacts old_binary current_binary before entry
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

  rm "$target/plugins/skill-registry.js"
  printf '{"plugin":["%s"]}\n' "$PLUGIN_PACKAGE" > "$target/tui.json"
  rm -rf "$before"
  cp -R "$target" "$before"
  if AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$current_binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null 2>&1; then
    fail "installer replaced a foreign npm plugin entry without --force"
  fi
  diff -qr "$before" "$target" >/dev/null || fail "npm conflict rejection mutated the target"

  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$current_binary" \
    "$INSTALLER" install --domain meta --target "$target" --force >/dev/null
  entry="$(plugin_entry "$target/model-profiles")"
  python3 "$ROOT/scripts/jsonc-array.py" has-json "$target/tui.json" plugin "$entry" >/dev/null ||
    fail "--force did not replace the foreign npm plugin entry"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$PLUGIN_PACKAGE" >/dev/null 2>&1 &&
    fail "--force retained the unpinned npm plugin entry"
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
  local scratch target artifacts binary entry
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-sync.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  entry="$(plugin_entry "$target/model-profiles")"

  # Given the meta external plugins are installed
  # When a later sync selects only common
  # Then model/registry artifacts and TUI config leave while Graphify is installed
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta --target "$target" >/dev/null
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain common --target "$target" >/dev/null
  [ ! -e "$target/model-profiles" ] || fail "sync retained deselected model profiles"
  [ ! -e "$target/plugins/skill-registry.js" ] || fail "sync retained deselected skill registry"
  [ -f "$target/plugins/graphify-init.js" ] || fail "sync did not install Graphify"
  python3 "$ROOT/scripts/jsonc-array.py" has-json "$target/tui.json" plugin "$entry" >/dev/null 2>&1 &&
    fail "sync retained the npm TUI registration"
  rm -rf "$scratch"
  pass "shouldSyncAwayDeselectedExternalPlugins"
}

seed_external_model_bundle_layout() {
  local target="$1"
  local manifest="$target/.agents-orchestrator-manifest"
  mkdir -p "$target/plugins/model-configurator/profiles"
  printf 'old bundled tui\n' > "$target/plugins/model-configurator/tui.js"
  cp "$ROOT/profiles/default.json" "$target/plugins/model-configurator/profiles/default.json"
  printf '{"plugin":["%s"],"theme":"system"}\n' "$OLD_EXTERNAL_PLUGIN_SPEC" > "$target/tui.json"
  printf '{"name":"foreign-package","foreign":true}\n' > "$target/package.json"
  {
    printf 'dir\t%s\n' "$target/plugins/model-configurator"
    printf 'dir\t%s\n' "$target/plugins/model-configurator/profiles"
    printf 'file\t%s\n' "$target/plugins/model-configurator/tui.js"
    printf 'file\t%s\n' "$target/plugins/model-configurator/profiles/default.json"
    printf 'managed-array\t%s\tplugin\t%s\n' "$target/tui.json" "$OLD_EXTERNAL_PLUGIN_SPEC"
  } > "$manifest"
}

shouldMigrateManagedModelBundleToNpmPackage() {
  local scratch target artifacts binary user_config entry
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-migration.XXXXXX")"
  target="$scratch/target"
  artifacts="$scratch/artifacts"
  mkdir -p "$target/plugins"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  seed_external_model_bundle_layout "$target"
  entry="$(plugin_entry "$target/model-profiles")"
  user_config="$target/opencode.jsonc"
  printf '{"agent":{"orchestraitor":{"model":"provider/model"}}}\n' > "$user_config"
  cp "$user_config" "$scratch/config-before"

  # Given a manifest-owned copy of the former GitHub TUI bundle
  # When all domains are synchronized through the npm descriptor
  # Then the bundle becomes a pinned npm tuple and user assignments remain byte-identical
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --target "$target" >/dev/null
  [ ! -e "$target/plugins/model-configurator" ] || fail "migration retained the old model bundle"
  [ -f "$target/model-profiles/default.json" ] || fail "migration missed the managed model profile"
  [ -f "$target/plugins/skill-registry.js" ] || fail "migration missed external skill bundle"
  [ -f "$target/plugins/graphify-init.js" ] || fail "migration missed external Graphify bundle"
  python3 "$ROOT/scripts/jsonc-array.py" has-json "$target/tui.json" plugin "$entry" >/dev/null ||
    fail "migration did not register the npm tuple"
  python3 "$ROOT/scripts/jsonc-array.py" has "$target/tui.json" plugin "$OLD_EXTERNAL_PLUGIN_SPEC" >/dev/null 2>&1 &&
    fail "migration retained the bundled TUI registration"
  assert_json_value "$target/package.json" '.foreign' "true" "migration changed foreign package data"
  assert_file_equals "$user_config" "$scratch/config-before" "migration changed user agent assignments"
  assert_count "$target/.agents-orchestrator-manifest" 'managed-array-json' 1 "new manifest missed npm tuple ownership"
  rm -rf "$scratch"
  pass "shouldMigrateManagedModelBundleToNpmPackage"
}

shouldInstallOnlyInsideProjectTarget() {
  local scratch project project_target artifacts binary entry
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-project.XXXXXX")"
  project="$scratch/project"
  artifacts="$scratch/artifacts"
  mkdir -p "$project"
  make_external_artifacts "$artifacts"
  binary="$(make_fake_opencode "$scratch/bin" "$MIN_OPENCODE_VERSION")"
  project_target="$(cd "$project" && pwd -L)/.opencode"
  entry="$(plugin_entry "$project_target/model-profiles")"

  # Given project mode in an isolated working directory
  # When meta is installed
  # Then the server bundle, profile, and npm TUI config stay under .opencode
  (cd "$project" && AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$artifacts" OPENCODE_BIN="$binary" \
    "$INSTALLER" install --domain meta --project >/dev/null)
  [ -f "$project/.opencode/model-profiles/default.json" ] || fail "project model profile missing"
  [ -f "$project/.opencode/plugins/skill-registry.js" ] || fail "project server bundle missing"
  [ -f "$project/.opencode/tui.json" ] || fail "project tui.json missing"
  python3 "$ROOT/scripts/jsonc-array.py" has-json "$project/.opencode/tui.json" plugin "$entry" >/dev/null ||
    fail "project install missed the npm TUI tuple"
  [ ! -e "$project/tui.json" ] || fail "project install escaped .opencode"
  rm -rf "$scratch"
  pass "shouldInstallOnlyInsideProjectTarget"
}

shouldMatchPinnedRemoteArtifacts() {
  local descriptor repository commit artifact expected scratch downloaded actual package version metadata
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/external-plugin-remote.XXXXXX")"

  # Given every production descriptor
  # When its immutable GitHub artifact or exact npm release is resolved
  # Then the reviewed lock and TUI entrypoint are available
  for descriptor in "$ROOT"/domains/*/external-plugins/*.json; do
    [ -f "$descriptor" ] || continue
    if [ "$(jq -r '.source // "github"' "$descriptor")" = "npm" ]; then
      package="$(jq -er .package "$descriptor")"
      version="$(jq -er .version "$descriptor")"
      metadata="$scratch/$(basename "$descriptor").npm.json"
      npm view "$package@$version" --json > "$metadata"
      [ "$(jq -r .name "$metadata")" = "$package" ] || fail "$descriptor npm package name mismatch"
      [ "$(jq -r .version "$metadata")" = "$version" ] || fail "$descriptor npm package version mismatch"
      jq -e '.exports["./tui"].import | type == "string" and length > 0' "$metadata" >/dev/null ||
        fail "$descriptor npm package has no TUI entrypoint"
      continue
    fi
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
  shouldPreserveStructuredJsoncManagedEntry
  shouldHandleMissingPropertyAndTrailingComment
  shouldIgnoreCommentCommasWhenRemovingJsoncSeparators
  shouldPreserveJsoncScalarProperties
  shouldInstallRepairStatusAndUninstallExternalPlugins
  shouldStageSameNamedArtifactsByKind
  shouldPreservePreexistingTuiRegistration
  shouldRejectChangedOwnedNpmTupleWithoutForce
  shouldAbortBeforeMutationOnInvalidPreconditions
  shouldRollbackExternalPluginTransaction
  shouldSyncAwayDeselectedExternalPlugins
  shouldMigrateManagedModelBundleToNpmPackage
  shouldInstallOnlyInsideProjectTarget
}

case "${1:-contracts}" in
  contracts) run_contracts ;;
  remote) shouldMatchPinnedRemoteArtifacts ;;
  project) shouldInstallOnlyInsideProjectTarget ;;
  *) fail "unknown suite: $1" ;;
esac

printf 'PASS: %d external plugin installer checks.\n' "$PASSES"
