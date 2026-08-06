#!/usr/bin/env bash
# Deterministic contracts for the project-local SDLC orchestrator POC profile.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="$ROOT/scripts/sdlc-orchestrator-poc.sh"
JSONC_EDITOR="$ROOT/scripts/jsonc-array.py"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-orchestrator-poc-test.XXXXXX")"
ARTIFACTS="$SCRATCH/artifacts"
STUBS="$SCRATCH/stubs"
PASSES=0

cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT INT TERM

fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
pass() { PASSES=$((PASSES + 1)); printf 'PASS %s\n' "$1"; }

mkdir -p "$ARTIFACTS" "$STUBS"
printf 'deterministic graphify fixture\n' > "$ARTIFACTS/graphify-init.js"
cat > "$STUBS/opencode" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then printf '1.18.10\n'; else exit 1; fi
EOF
chmod +x "$STUBS/opencode"

run_profile() {
  AGENTS_ORCHESTRATOR_TEST_EXTERNAL_ARTIFACTS_DIR="$ARTIFACTS" \
    OPENCODE_BIN="$STUBS/opencode" \
    "$PROFILE" "$@"
}

make_project() {
  local project="$SCRATCH/$1"
  mkdir -p "$project"
  printf '%s\n' "$project"
}

scalar() {
  python3 "$JSONC_EDITOR" get "$1" "$2"
}

set_scalar() {
  local file="$1" property="$2" value="$3"
  local tmp="$file.tmp"
  python3 "$JSONC_EDITOR" set "$file" "$property" "$value" > "$tmp"
  mv "$tmp" "$file"
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

shouldInstallStatusAndRestoreExistingJsonc() {
  local project config before_manifest before_config
  project="$(make_project existing-jsonc)"
  mkdir -p "$project/.opencode"
  config="$project/.opencode/opencode.jsonc"
  cat > "$config" <<'EOF'
{
  // keep profile owner context
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "mentor", // restore this value
  "subagent_depth": 4,
  "foreign": {"keep": true},
}
EOF

  run_profile install --project-root "$project" >/dev/null
  [ "$(scalar "$config" default_agent)" = '"sdlc-orchestrator"' ] || fail "install: wrong default_agent"
  [ "$(scalar "$config" subagent_depth)" = 2 ] || fail "install: wrong subagent_depth"
  grep -Fq '// keep profile owner context' "$config" || fail "install: top comment lost"
  grep -Fq '// restore this value' "$config" || fail "install: inline comment lost"
  grep -Fq '"foreign": {"keep": true}' "$config" || fail "install: foreign key lost"
  run_profile status --project-root "$project" | grep -Fq 'repo-owned primaries: 1' ||
    fail "status: primary invariant missing"

  before_manifest="$(shasum -a 256 "$project/.opencode/.agents-orchestrator-manifest" | awk '{print $1}')"
  before_config="$(shasum -a 256 "$config" | awk '{print $1}')"
  run_profile install --project-root "$project" >/dev/null
  [ "$before_manifest" = "$(shasum -a 256 "$project/.opencode/.agents-orchestrator-manifest" | awk '{print $1}')" ] ||
    fail "reinstall: installer manifest drifted"
  [ "$before_config" = "$(shasum -a 256 "$config" | awk '{print $1}')" ] ||
    fail "reinstall: config drifted"

  run_profile uninstall --project-root "$project" >/dev/null
  [ "$(scalar "$config" default_agent)" = '"mentor"' ] || fail "uninstall: default_agent not restored"
  [ "$(scalar "$config" subagent_depth)" = 4 ] || fail "uninstall: subagent_depth not restored"
  grep -Fq '// keep profile owner context' "$config" || fail "uninstall: top comment lost"
  grep -Fq '// restore this value' "$config" || fail "uninstall: inline comment lost"
  grep -Fq '"foreign": {"keep": true}' "$config" || fail "uninstall: foreign key lost"
  [ ! -e "$project/.opencode/.agents-orchestrator-manifest" ] || fail "uninstall: installer manifest remains"
  [ ! -e "$project/.opencode/.sdlc-orchestrator-poc-manifest" ] || fail "uninstall: profile manifest remains"
  pass shouldInstallStatusAndRestoreExistingJsonc
}

shouldRestoreAbsentValuesWithoutLosingComments() {
  local project config status
  project="$(make_project absent-values)"
  mkdir -p "$project/.opencode"
  config="$project/.opencode/opencode.jsonc"
  cat > "$config" <<'EOF'
{
  // foreign-only config survives the round trip
  "theme": "dark" // keep, please
}
EOF
  run_profile install --project-root "$project" >/dev/null
  run_profile uninstall --project-root "$project" >/dev/null
  set +e
  python3 "$JSONC_EDITOR" get "$config" default_agent >/dev/null
  status=$?
  set -e
  [ "$status" -eq 1 ] || fail "absent restore: default_agent still exists"
  set +e
  python3 "$JSONC_EDITOR" get "$config" subagent_depth >/dev/null
  status=$?
  set -e
  [ "$status" -eq 1 ] || fail "absent restore: subagent_depth still exists"
  grep -Fq '// foreign-only config survives the round trip' "$config" || fail "absent restore: comment lost"
  grep -Fq '// keep, please' "$config" || fail "absent restore: inline comment comma changed"
  grep -Fq '"theme": "dark"' "$config" || fail "absent restore: foreign key lost"
  pass shouldRestoreAbsentValuesWithoutLosingComments
}

shouldRemoveGeneratedConfigAndTargetWhenPreviouslyAbsent() {
  local project manifest
  project="$(make_project generated-target)"

  # Given a project without a local OpenCode target or config
  # When the profile is installed and uninstalled
  # Then both generated paths return to absence
  run_profile install --project-root "$project" >/dev/null
  manifest="$project/.opencode/.sdlc-orchestrator-poc-manifest"
  grep -Fq $'config-existed\t0' "$manifest" || fail "generated config: prior absence was not recorded"
  grep -Fq $'target-existed\t0' "$manifest" || fail "generated target: prior absence was not recorded"
  run_profile uninstall --project-root "$project" >/dev/null
  [ ! -e "$project/.opencode/opencode.jsonc" ] || fail "generated config: uninstall retained config"
  [ ! -e "$project/.opencode" ] || fail "generated target: uninstall retained empty target"
  pass shouldRemoveGeneratedConfigAndTargetWhenPreviouslyAbsent
}

shouldPreservePreexistingTargetWithoutConfig() {
  local project manifest
  project="$(make_project existing-target)"
  mkdir -p "$project/.opencode"

  # Given an existing local OpenCode target without a config
  # When the profile is installed and uninstalled
  # Then the target remains while the generated config is removed
  run_profile install --project-root "$project" >/dev/null
  manifest="$project/.opencode/.sdlc-orchestrator-poc-manifest"
  grep -Fq $'config-existed\t0' "$manifest" || fail "existing target: prior config absence was not recorded"
  grep -Fq $'target-existed\t1' "$manifest" || fail "existing target: prior target presence was not recorded"
  run_profile uninstall --project-root "$project" >/dev/null
  [ -d "$project/.opencode" ] || fail "existing target: uninstall removed target"
  [ ! -e "$project/.opencode/opencode.jsonc" ] || fail "existing target: uninstall retained generated config"
  pass shouldPreservePreexistingTargetWithoutConfig
}

shouldPreserveForeignConfigAddedAfterInstall() {
  local project config status
  project="$(make_project config-added-after-install)"

  # Given a profile-owned config that later gains a foreign property
  # When the profile is uninstalled
  # Then only managed properties are removed and the foreign config survives
  run_profile install --project-root "$project" >/dev/null
  config="$project/.opencode/opencode.jsonc"
  set_scalar "$config" theme '"dark"'
  run_profile uninstall --project-root "$project" >/dev/null
  [ "$(scalar "$config" theme)" = '"dark"' ] || fail "foreign config: added property was not preserved"
  set +e
  python3 "$JSONC_EDITOR" get "$config" default_agent >/dev/null
  status=$?
  set -e
  [ "$status" -eq 1 ] || fail "foreign config: default_agent still exists"
  set +e
  python3 "$JSONC_EDITOR" get "$config" subagent_depth >/dev/null
  status=$?
  set -e
  [ "$status" -eq 1 ] || fail "foreign config: subagent_depth still exists"
  pass shouldPreserveForeignConfigAddedAfterInstall
}

shouldPreserveForeignTargetContentAddedAfterInstall() {
  local project foreign_file
  project="$(make_project target-content-added-after-install)"

  # Given a profile-created target that later gains a foreign file
  # When the profile is uninstalled
  # Then the generated config is removed without pruning foreign content
  run_profile install --project-root "$project" >/dev/null
  foreign_file="$project/.opencode/foreign.txt"
  printf 'keep me\n' > "$foreign_file"
  run_profile uninstall --project-root "$project" >/dev/null
  [ ! -e "$project/.opencode/opencode.jsonc" ] || fail "foreign target: generated config remains"
  grep -Fq 'keep me' "$foreign_file" || fail "foreign target: user file was removed"
  pass shouldPreserveForeignTargetContentAddedAfterInstall
}

shouldAcceptLegacyManifestWithoutTargetOwnership() {
  local project manifest rewritten
  project="$(make_project legacy-profile-manifest)"

  # Given a v1 profile manifest created before target ownership was recorded
  # When status and uninstall read that manifest
  # Then they accept it and conservatively retain the target directory
  run_profile install --project-root "$project" >/dev/null
  manifest="$project/.opencode/.sdlc-orchestrator-poc-manifest"
  rewritten="$project/legacy-profile-manifest"
  awk -F '\t' '$1 != "target-existed"' "$manifest" > "$rewritten"
  mv "$rewritten" "$manifest"
  run_profile status --project-root "$project" >/dev/null
  run_profile uninstall --project-root "$project" >/dev/null
  [ ! -e "$project/.opencode/opencode.jsonc" ] || fail "legacy manifest: generated config remains"
  [ -d "$project/.opencode" ] || fail "legacy manifest: unknown target ownership was pruned"
  pass shouldAcceptLegacyManifestWithoutTargetOwnership
}

shouldAbortUninstallWhenManagedConfigChanges() {
  local project config
  project="$(make_project tampered-config)"
  run_profile install --project-root "$project" >/dev/null
  config="$project/.opencode/opencode.jsonc"
  set_scalar "$config" default_agent '"foreign-primary"'
  expect_failure 'managed default_agent changed' run_profile uninstall --project-root "$project"
  [ -L "$project/.opencode/agents/sdlc-orchestrator.md" ] || fail "tamper: components were removed"
  [ -f "$project/.opencode/.agents-orchestrator-manifest" ] || fail "tamper: installer manifest was removed"
  set_scalar "$config" default_agent '"sdlc-orchestrator"'
  run_profile uninstall --project-root "$project" >/dev/null
  pass shouldAbortUninstallWhenManagedConfigChanges
}

shouldRejectForeignAndBroadManifests() {
  local foreign broad manifest backup
  foreign="$(make_project foreign-manifest)"
  mkdir -p "$foreign/.opencode"
  printf 'link\t%s\n' "$HOME/.config/opencode/agents/foreign.md" > "$foreign/.opencode/.agents-orchestrator-manifest"
  expect_failure 'foreign installer manifest already exists' run_profile install --project-root "$foreign"
  [ ! -e "$foreign/.opencode/agents/sdlc-orchestrator.md" ] || fail "foreign manifest: profile mutated target"

  broad="$(make_project broad-manifest)"
  run_profile install --project-root "$broad" >/dev/null
  manifest="$broad/.opencode/.agents-orchestrator-manifest"
  backup="$broad/installer-manifest.backup"
  cp "$manifest" "$backup"
  printf 'link\t%s\n' "$broad/.opencode/agents/broad.md" >> "$manifest"
  expect_failure 'installer manifest changed or became broad/foreign' run_profile status --project-root "$broad"
  expect_failure 'installer manifest changed or became broad/foreign' run_profile uninstall --project-root "$broad"
  [ -L "$broad/.opencode/agents/sdlc-orchestrator.md" ] || fail "broad manifest: failed uninstall mutated target"
  cp "$backup" "$manifest"
  run_profile uninstall --project-root "$broad" >/dev/null
  pass shouldRejectForeignAndBroadManifests
}

shouldRejectForeignDestinationAndInvalidJsoncBeforeInstall() {
  local foreign invalid
  foreign="$(make_project foreign-destination)"
  mkdir -p "$foreign/.opencode/agents"
  printf 'foreign\n' > "$foreign/.opencode/agents/sdlc-orchestrator.md"
  expect_failure 'foreign profile destination exists' run_profile install --project-root "$foreign"
  [ ! -e "$foreign/.opencode/.agents-orchestrator-manifest" ] || fail "foreign destination: manifest created"

  invalid="$(make_project invalid-jsonc)"
  mkdir -p "$invalid/.opencode"
  printf '{ invalid jsonc\n' > "$invalid/.opencode/opencode.jsonc"
  expect_failure 'cannot read JSONC property' run_profile install --project-root "$invalid"
  [ ! -e "$invalid/.opencode/.agents-orchestrator-manifest" ] || fail "invalid JSONC: installer ran"
  pass shouldRejectForeignDestinationAndInvalidJsoncBeforeInstall
}

shouldRejectSymlinkedProjectTargetBeforeMutation() {
  local project external action
  project="$(make_project symlinked-target)"
  external="$SCRATCH/external-opencode"
  mkdir -p "$external"
  printf 'keep me\n' > "$external/foreign.txt"
  ln -s "$external" "$project/.opencode"

  for action in install status uninstall; do
    expect_failure 'refusing symlinked project target' run_profile "$action" --project-root "$project"
  done
  grep -Fq 'keep me' "$external/foreign.txt" || fail "symlinked target: foreign content changed"
  [ ! -e "$external/.agents-orchestrator-manifest" ] || fail "symlinked target: installer manifest escaped project"
  [ ! -e "$external/.sdlc-orchestrator-poc-manifest" ] || fail "symlinked target: profile manifest escaped project"
  [ ! -e "$external/opencode.jsonc" ] || fail "symlinked target: config escaped project"
  pass shouldRejectSymlinkedProjectTargetBeforeMutation
}

shouldInstallOnlySelectedDomainsAndRejectSourceWorktree() {
  local project aliases
  project="$(make_project selected-domains)"
  run_profile install --project-root "$project" >/dev/null
  [ -L "$project/.opencode/agents/sdlc-orchestrator.md" ] || fail "selection: SDLC primary missing"
  [ -L "$project/.opencode/agents/architect.md" ] || fail "selection: architecture coordinator missing"
  [ -L "$project/.opencode/skills/sdd-draft-change" ] || fail "selection: one-document SDD skill missing"
  [ -L "$project/.opencode/skills/evidence-first-planning" ] || fail "selection: evidence-first planning skill missing"
  local removed
  for removed in sdd-proposal sdd-spec sdd-design sdd-tasks; do
    [ ! -e "$project/.opencode/agents/$removed.md" ] || fail "selection: removed agent $removed leaked"
  done
  for removed in fable-planning wayfinder; do
    [ ! -e "$project/.opencode/skills/$removed" ] || fail "selection: retired skill $removed leaked"
  done
  [ ! -e "$project/.opencode/agents/mentor.md" ] || fail "selection: learning domain leaked"
  [ ! -e "$project/.opencode/commands/absorb.md" ] || fail "selection: meta domain leaked"
  aliases="$(find "$project/.opencode/commands" -maxdepth 1 -type l -exec grep -l '^agent: sdlc-orchestrator$' {} + | wc -l | tr -d ' ')"
  [ "$aliases" -eq 12 ] || fail "selection: expected 12 aliases, found $aliases"
  run_profile uninstall --project-root "$project" >/dev/null

  expect_failure 'refusing to install the POC into this repository' run_profile status --project-root "$ROOT"
  [ ! -e "$ROOT/.opencode" ] || fail "source rejection: source worktree was modified"
  pass shouldInstallOnlySelectedDomainsAndRejectSourceWorktree
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

shouldInstallStatusAndRestoreExistingJsonc
shouldRestoreAbsentValuesWithoutLosingComments
shouldRemoveGeneratedConfigAndTargetWhenPreviouslyAbsent
shouldPreservePreexistingTargetWithoutConfig
shouldPreserveForeignConfigAddedAfterInstall
shouldPreserveForeignTargetContentAddedAfterInstall
shouldAcceptLegacyManifestWithoutTargetOwnership
shouldAbortUninstallWhenManagedConfigChanges
shouldRejectForeignAndBroadManifests
shouldRejectForeignDestinationAndInvalidJsoncBeforeInstall
shouldRejectSymlinkedProjectTargetBeforeMutation
shouldInstallOnlySelectedDomainsAndRejectSourceWorktree

printf 'PASS: %d SDLC orchestrator profile contracts OK.\n' "$PASSES"
