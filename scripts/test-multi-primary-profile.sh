#!/usr/bin/env bash
# Deterministic contracts for the project-local multi-primary profile.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="$ROOT/scripts/multi-primary-profile.sh"
JSONC_EDITOR="$ROOT/scripts/jsonc-array.py"
GRAPHIFY_SPEC="opencode-graphify-init@0.1.4"
PREVIOUS_GRAPHIFY_SPEC="opencode-graphify-init@0.1.3"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/multi-primary-profile-test.XXXXXX")"
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
if [ "${1:-}" = "--version" ]; then printf '1.18.20\n'; else exit 1; fi
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

replace_manifest_value() {
  local file="$1" key="$2" value="$3" tmp
  tmp="$file.tmp"
  awk -F '\t' -v key="$key" -v value="$value" '
    BEGIN { OFS = "\t" }
    $1 == key { $2 = value }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

simulate_previous_component_inventory() {
  local project="$1" target installer_manifest profile_manifest manifest_sha
  target="$(cd "$project" && pwd -P)/.opencode"
  installer_manifest="$target/.agents-orchestrator-manifest"
  profile_manifest="$target/.multi-primary-profile-manifest"

  rm "$target/skills/evidence-first-planning"
  awk -F '\t' -v path="$target/skills/evidence-first-planning" \
    '!($1 == "link" && $2 == path)' "$installer_manifest" > "$installer_manifest.tmp"
  mv "$installer_manifest.tmp" "$installer_manifest"
  ln -s "$ROOT/domains/plan/skills/wayfinder" "$target/skills/wayfinder"
  printf 'link\t%s\n' "$target/skills/wayfinder" >> "$installer_manifest"
  manifest_sha="$(shasum -a 256 "$installer_manifest" | awk '{print $1}')"
  replace_manifest_value "$profile_manifest" installer-manifest-sha256 "$manifest_sha"
}

allowed_skills_for_domain() {
  local domain="$1" agent
  for agent in "$ROOT/domains/$domain/agents/"*.md; do
    [ -e "$agent" ] || continue
    awk '
      NR == 1 && $0 == "---" { frontmatter = 1; next }
      frontmatter && $0 == "---" { exit }
      frontmatter && /^  skill:/ { skills = 1; next }
      skills && /^  [^ ]/ { skills = 0 }
      skills && /^    [A-Za-z0-9_-]+: allow$/ {
        skill = $0
        sub(/^    /, "", skill)
        sub(/: allow$/, "", skill)
        print skill
      }
    ' "$agent"
  done | sort -u
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

  run_profile install --project-root "$project" --no-install-brew-tools >/dev/null
  [ "$(scalar "$config" default_agent)" = '"mentor"' ] || fail "install: default_agent changed"
  [ "$(scalar "$config" subagent_depth)" = 1 ] || fail "install: wrong subagent_depth"
  python3 "$JSONC_EDITOR" has "$config" plugin "$GRAPHIFY_SPEC" >/dev/null ||
    fail "install: Graphify registration did not coexist with profile settings"
  grep -Fq '// keep profile owner context' "$config" || fail "install: top comment lost"
  grep -Fq '// restore this value' "$config" || fail "install: inline comment lost"
  grep -Fq '"foreign": {"keep": true}' "$config" || fail "install: foreign key lost"
  run_profile status --project-root "$project" | grep -Fq 'repo-owned primaries: 5' ||
    fail "status: primary invariant missing"
  run_profile status --project-root "$project" | grep -Fq 'question owners: 5' ||
    fail "status: question-owner invariant missing"

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
  python3 "$JSONC_EDITOR" has "$config" plugin "$GRAPHIFY_SPEC" >/dev/null 2>&1 &&
    fail "uninstall: Graphify registration remains"
  grep -Fq '// keep profile owner context' "$config" || fail "uninstall: top comment lost"
  grep -Fq '// restore this value' "$config" || fail "uninstall: inline comment lost"
  grep -Fq '"foreign": {"keep": true}' "$config" || fail "uninstall: foreign key lost"
  [ ! -e "$project/.opencode/.agents-orchestrator-manifest" ] || fail "uninstall: installer manifest remains"
  [ ! -e "$project/.opencode/.multi-primary-profile-manifest" ] || fail "uninstall: profile manifest remains"
  pass shouldInstallStatusAndRestoreExistingJsonc
}

shouldInstallStatusAndRestoreExistingJson() {
  local project config manifest
  project="$(make_project existing-json)"
  project="$(cd "$project" && pwd -P)"
  mkdir -p "$project/.opencode"
  config="$project/.opencode/opencode.json"
  manifest="$project/.opencode/.multi-primary-profile-manifest"
  cat > "$config" <<'EOF'
{
  "default_agent": "mentor",
  "subagent_depth": 3,
  "foreign": {"keep": true}
}
EOF

  # Given a project whose only OpenCode config uses the JSON filename
  # When the profile completes its install, status, and uninstall lifecycle
  run_profile install --project-root "$project" >/dev/null
  grep -Fq $'config-file\t'"$config" "$manifest" ||
    fail "existing JSON: selected config path was not persisted"
  run_profile status --project-root "$project" | grep -Fq "config-file: $config" ||
    fail "existing JSON: status did not use the persisted config path"
  run_profile uninstall --project-root "$project" >/dev/null

  # Then that file retains all foreign settings and no shadowing JSONC appears
  [ ! -e "$project/.opencode/opencode.jsonc" ] || fail "existing JSON: profile created a shadowing JSONC file"
  [ "$(scalar "$config" default_agent)" = '"mentor"' ] || fail "existing JSON: default_agent changed"
  [ "$(scalar "$config" subagent_depth)" = 3 ] || fail "existing JSON: subagent_depth not restored"
  grep -Fq '"foreign": {"keep": true}' "$config" || fail "existing JSON: foreign config changed"
  [ ! -e "$manifest" ] || fail "existing JSON: profile manifest remains"
  pass shouldInstallStatusAndRestoreExistingJson
}

shouldMigrateManagedNpmServerVersion() {
  local project config installer_manifest profile_manifest rewritten manifest_sha
  project="$(make_project npm-server-version-migration)"
  run_profile install --project-root "$project" >/dev/null
  config="$project/.opencode/opencode.jsonc"
  installer_manifest="$project/.opencode/.agents-orchestrator-manifest"
  profile_manifest="$project/.opencode/.multi-primary-profile-manifest"
  rewritten="$project/rewritten.jsonc"

  python3 "$JSONC_EDITOR" remove "$config" plugin "$GRAPHIFY_SPEC" > "$rewritten"
  python3 "$JSONC_EDITOR" add "$rewritten" plugin "$PREVIOUS_GRAPHIFY_SPEC" > "$config"
  awk -F '\t' -v current="$GRAPHIFY_SPEC" -v previous="$PREVIOUS_GRAPHIFY_SPEC" '
    BEGIN { OFS = "\t" }
    $1 == "managed-array" && $4 == current { $4 = previous }
    { print }
  ' "$installer_manifest" > "$installer_manifest.tmp"
  mv "$installer_manifest.tmp" "$installer_manifest"
  manifest_sha="$(shasum -a 256 "$installer_manifest" | awk '{print $1}')"
  replace_manifest_value "$profile_manifest" installer-manifest-sha256 "$manifest_sha"

  # Given a valid profile manifest from the preceding pinned server version
  # When the profile is reinstalled from the current checkout
  # Then the installer migrates the owned package entry without force
  run_profile install --project-root "$project" >/dev/null
  python3 "$JSONC_EDITOR" has "$config" plugin "$GRAPHIFY_SPEC" >/dev/null ||
    fail "npm server migration: current Graphify version is missing"
  python3 "$JSONC_EDITOR" has "$config" plugin "$PREVIOUS_GRAPHIFY_SPEC" >/dev/null 2>&1 &&
    fail "npm server migration: previous Graphify version remains"
  run_profile uninstall --project-root "$project" >/dev/null
  pass shouldMigrateManagedNpmServerVersion
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
  manifest="$project/.opencode/.multi-primary-profile-manifest"
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
  manifest="$project/.opencode/.multi-primary-profile-manifest"
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
  manifest="$project/.opencode/.multi-primary-profile-manifest"
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
  set_scalar "$config" subagent_depth '2'
  expect_failure 'managed subagent_depth changed' run_profile uninstall --project-root "$project"
  [ -L "$project/.opencode/agents/deep-planner.md" ] || fail "tamper: components were removed"
  [ -f "$project/.opencode/.agents-orchestrator-manifest" ] || fail "tamper: installer manifest was removed"
  set_scalar "$config" subagent_depth '1'
  run_profile uninstall --project-root "$project" >/dev/null
  pass shouldAbortUninstallWhenManagedConfigChanges
}

shouldRejectForeignAndBroadManifests() {
  local foreign broad manifest backup
  foreign="$(make_project foreign-manifest)"
  mkdir -p "$foreign/.opencode"
  printf 'link\t%s\n' "$HOME/.config/opencode/agents/foreign.md" > "$foreign/.opencode/.agents-orchestrator-manifest"
  expect_failure 'foreign installer manifest already exists' run_profile install --project-root "$foreign"
  [ ! -e "$foreign/.opencode/agents/deep-planner.md" ] || fail "foreign manifest: profile mutated target"

  broad="$(make_project broad-manifest)"
  run_profile install --project-root "$broad" >/dev/null
  manifest="$broad/.opencode/.agents-orchestrator-manifest"
  backup="$broad/installer-manifest.backup"
  cp "$manifest" "$backup"
  printf 'link\t%s\n' "$broad/.opencode/agents/broad.md" >> "$manifest"
  expect_failure 'installer manifest changed or became broad/foreign' run_profile status --project-root "$broad"
  expect_failure 'installer manifest changed or became broad/foreign' run_profile uninstall --project-root "$broad"
  [ -L "$broad/.opencode/agents/deep-planner.md" ] || fail "broad manifest: failed uninstall mutated target"
  cp "$backup" "$manifest"
  run_profile uninstall --project-root "$broad" >/dev/null
  pass shouldRejectForeignAndBroadManifests
}

shouldRejectForeignDestinationAndInvalidJsoncBeforeInstall() {
  local foreign invalid
  foreign="$(make_project foreign-destination)"
  mkdir -p "$foreign/.opencode/agents"
  printf 'foreign\n' > "$foreign/.opencode/agents/deep-planner.md"
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
  [ ! -e "$external/.multi-primary-profile-manifest" ] || fail "symlinked target: profile manifest escaped project"
  [ ! -e "$external/opencode.jsonc" ] || fail "symlinked target: config escaped project"
  pass shouldRejectSymlinkedProjectTargetBeforeMutation
}

shouldRejectSymlinkedManagedDirectoriesBeforeMutation() {
  local directory project external

  # Given each managed child redirects outside the project
  for directory in agents commands skills plugins; do
    project="$(make_project "symlinked-$directory")"
    external="$SCRATCH/external-$directory"
    mkdir -p "$project/.opencode" "$external"
    printf 'keep me\n' > "$external/foreign.txt"
    ln -s "$external" "$project/.opencode/$directory"

    # When installation sees a managed directory that escapes the project
    expect_failure 'refusing symlinked managed directory' run_profile install --project-root "$project"

    # Then it stops before the generic installer mutates either location
    grep -Fq 'keep me' "$external/foreign.txt" || fail "symlinked $directory: foreign content changed"
    [ "$(find "$external" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" -eq 1 ] ||
      fail "symlinked $directory: managed content escaped project"
    [ ! -e "$project/.opencode/.agents-orchestrator-manifest" ] ||
      fail "symlinked $directory: installer manifest created"
    [ ! -e "$project/.opencode/.multi-primary-profile-manifest" ] ||
      fail "symlinked $directory: profile manifest created"
  done

  pass shouldRejectSymlinkedManagedDirectoriesBeforeMutation
}

shouldInstallOnlySelectedDomainsAndRejectSourceWorktree() {
  local project direct_commands primary
  project="$(make_project selected-domains)"
  run_profile install --project-root "$project" >/dev/null
  for primary in deep-planner architect orchestraitor orchestralite review-coordinator; do
    [ -L "$project/.opencode/agents/$primary.md" ] || fail "selection: primary $primary missing"
  done
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
  direct_commands="$(find "$project/.opencode/commands" -maxdepth 1 -type l -exec grep -El '^agent: (deep-planner|architect|orchestraitor|orchestralite|review-coordinator)$' {} + | wc -l | tr -d ' ')"
  [ "$direct_commands" -eq 12 ] || fail "selection: expected 12 direct commands, found $direct_commands"
  run_profile uninstall --project-root "$project" >/dev/null

  expect_failure 'refusing to install the profile into this repository' run_profile status --project-root "$ROOT"
  [ ! -e "$ROOT/.opencode/.agents-orchestrator-manifest" ] ||
    fail "source rejection: installer manifest was created"
  [ ! -e "$ROOT/.opencode/.multi-primary-profile-manifest" ] ||
    fail "source rejection: profile manifest was created"
  pass shouldInstallOnlySelectedDomainsAndRejectSourceWorktree
}

shouldSyncAndUninstallWhenComponentInventoryChanges() {
  local sync_project uninstall_project target old_skill_source skill
  sync_project="$(make_project changed-inventory-sync)"

  # Given a valid profile created by a checkout with a different component set
  run_profile install --project-root "$sync_project" >/dev/null
  simulate_previous_component_inventory "$sync_project"
  target="$sync_project/.opencode"
  old_skill_source="$ROOT/domains/plan/skills/java-testing"
  ln -sfn "$old_skill_source" "$target/skills/java-testing"

  # When status and reinstall run from the current checkout
  run_profile status --project-root "$sync_project" >/dev/null
  run_profile install --project-root "$sync_project" >/dev/null

  # Then the installer syncs the new set and the profile remains removable
  [ -L "$target/skills/evidence-first-planning" ] || fail "changed inventory: new skill was not installed"
  [ "$(readlink "$target/skills/java-testing")" = "$ROOT/skills/java-testing" ] ||
    fail "changed inventory: manifest-owned skill was not relinked to its current source"
  [ ! -e "$target/skills/wayfinder" ] && [ ! -L "$target/skills/wayfinder" ] ||
    fail "changed inventory: retired skill remains"
  run_profile uninstall --project-root "$sync_project" >/dev/null

  uninstall_project="$(make_project changed-inventory-uninstall)"
  run_profile install --project-root "$uninstall_project" >/dev/null
  simulate_previous_component_inventory "$uninstall_project"
  run_profile uninstall --project-root "$uninstall_project" >/dev/null
  [ ! -e "$uninstall_project/.opencode" ] || fail "changed inventory: stale profile target remains"

  for skill in evidence-first-planning wayfinder; do
    [ ! -e "$uninstall_project/.opencode/skills/$skill" ] &&
      [ ! -L "$uninstall_project/.opencode/skills/$skill" ] ||
      fail "changed inventory: uninstall retained $skill"
  done
  pass shouldSyncAndUninstallWhenComponentInventoryChanges
}

shouldInstallEveryAllowedSkillWhenFilteringOneDomain() {
  local domain project target skill

  for domain in plan architecture sdd sdd-lite review; do
    project="$(make_project "filtered-$domain")"
    target="$project/.opencode"

    # Given a one-domain installation
    "$ROOT/installers/opencode.sh" install --domain "$domain" --target "$target" >/dev/null

    # When each agent skill permission is inspected
    # Then every allowlisted skill is present without relying on another domain
    while IFS= read -r skill; do
      [ -n "$skill" ] || continue
      [ -L "$target/skills/$skill" ] || fail "filtered $domain: allowlisted skill is missing: $skill"
    done < <(allowed_skills_for_domain "$domain")

    "$ROOT/installers/opencode.sh" uninstall --target "$target" >/dev/null
  done
  pass shouldInstallEveryAllowedSkillWhenFilteringOneDomain
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

shouldInstallStatusAndRestoreExistingJsonc
shouldInstallStatusAndRestoreExistingJson
shouldMigrateManagedNpmServerVersion
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
shouldRejectSymlinkedManagedDirectoriesBeforeMutation
shouldInstallOnlySelectedDomainsAndRejectSourceWorktree
shouldSyncAndUninstallWhenComponentInventoryChanges
shouldInstallEveryAllowedSkillWhenFilteringOneDomain

printf 'PASS: %d multi-primary profile contracts OK.\n' "$PASSES"
