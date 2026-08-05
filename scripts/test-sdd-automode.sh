#!/usr/bin/env bash
# Deterministic contracts for scripts/sdd-automode.sh (SDD-AUTO-01 in
# docs/sdd-test-plan.md). No LLM, no network, no real opencode binary: every
# case runs against a scratch --target, and cases that need a different agent
# set mirror the repo layout into a scratch root so the real
# domains/sdd/agents/ is never touched.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTOMODE="$ROOT/scripts/sdd-automode.sh"
SDD_AGENTS_DIR="$ROOT/domains/sdd/agents"
PERMISSION_KEYS=(
  read edit write glob grep list bash task external_directory
  todowrite webfetch websearch lsp skill question doom_loop
)
PASSES=0
SCRATCHES=()

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

pass() {
  PASSES=$((PASSES + 1))
  printf 'PASS %s\n' "$1"
}

cleanup() {
  local dir
  for dir in ${SCRATCHES+"${SCRATCHES[@]}"}; do
    [ -n "$dir" ] && rm -rf "$dir"
  done
}
trap cleanup EXIT INT TERM

make_scratch() {
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/sdd-automode-test.XXXXXX")"
  SCRATCHES+=("$dir")
  printf '%s\n' "$dir"
}

# Mirror the pieces of the repo that sdd-automode.sh resolves relative to its
# own location, so a case can vary the agent set without touching the repo.
mirror_repo() {
  local dest="$1"
  mkdir -p "$dest/scripts" "$dest/domains/sdd/agents"
  cp "$AUTOMODE" "$dest/scripts/sdd-automode.sh"
  cp "$SDD_AGENTS_DIR"/*.md "$dest/domains/sdd/agents/"
  printf '%s\n' "$dest/scripts/sdd-automode.sh"
}

assert_json_value() {
  local actual
  actual="$(jq -r "$2" "$1")"
  [ "$actual" = "$3" ] || fail "$4 (expected $3, found $actual)"
}

assert_status() {
  local expected="$1" actual="$2" label="$3"
  [ "$expected" = "$actual" ] || fail "$label (expected exit $expected, got $actual)"
}

checksum() { shasum -a 256 "$1" | cut -d' ' -f1; }

seed_config() {
  # shellcheck disable=SC2016  # $schema is a literal JSON key, not a variable
  printf '%s\n' '{"$schema":"https://opencode.ai/config.json","agent":{"mentor":{"model":"openai/gpt-5.6-sol"}}}' > "$1"
}

# The agent names sdd-automode.sh discovers, plus the built-in general.
target_names() {
  local file
  for file in "$SDD_AGENTS_DIR"/*.md; do
    basename "$file" .md
  done
  printf 'general\n'
}

# --- Cases -------------------------------------------------------------------

shouldWriteCompleteBlocksPreservingFrontmatterDenies() {
  local scratch target config name
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  seed_config "$target/opencode.json"
  "$AUTOMODE" on --target "$target" >/dev/null
  config="$target/opencode.json"

  # Every discovered sdd agent plus general gets a block with every key.
  while IFS= read -r name; do
    assert_json_value "$config" ".agent[\"$name\"].permission | type" object \
      "on: $name has no permission object"
    local key
    for key in "${PERMISSION_KEYS[@]}"; do
      [ "$(jq -r --arg k "$key" --arg n "$name" \
        '.agent[$n].permission | has($k)' "$config")" = true ] ||
        fail "on: $name is missing permission key $key"
    done
  done < <(target_names)

  # Read-only agents keep their frontmatter denies.
  for name in jd-judge-a jd-judge-b jd-solo sdd-explore sdd-verify; do
    assert_json_value "$config" ".agent[\"$name\"].permission.edit" deny \
      "on: $name lost its edit deny"
    assert_json_value "$config" ".agent[\"$name\"].permission.write" deny \
      "on: $name lost its write deny"
  done
  # Drafting agents keep bash deny.
  for name in sdd-proposal sdd-spec sdd-tasks; do
    assert_json_value "$config" ".agent[\"$name\"].permission.bash" deny \
      "on: $name lost its bash deny"
  done
  # Drafting agents keep their nested planning-artifact write boundary.
  for name in sdd-proposal sdd-spec sdd-design sdd-tasks; do
    assert_json_value "$config" ".agent[\"$name\"].permission.edit[\"*\"]" deny \
      "on: $name lost its edit wildcard deny"
    assert_json_value "$config" ".agent[\"$name\"].permission.edit[\".ai/*/changes/**\"]" allow \
      "on: $name lost its planning edit allow"
    assert_json_value "$config" ".agent[\"$name\"].permission.write[\"*\"]" deny \
      "on: $name lost its write wildcard deny"
    assert_json_value "$config" ".agent[\"$name\"].permission.write[\".ai/*/changes/**\"]" allow \
      "on: $name lost its planning write allow"
  done
  # Subagents never ask; the orchestraitor always may.
  for name in sdd-explore sdd-implement sdd-verify jd-fix jd-solo; do
    assert_json_value "$config" ".agent[\"$name\"].permission.question" deny \
      "on: $name lost its question deny"
  done
  assert_json_value "$config" '.agent.orchestraitor.permission.question' allow \
    "on: orchestraitor lost question allow"
  # The nested task allowlist is copied verbatim over the flat allow.
  assert_json_value "$config" '.agent.orchestraitor.permission.task | type' object \
    "on: orchestraitor task map collapsed to a scalar"
  assert_json_value "$config" '.agent.orchestraitor.permission.task["*"]' deny \
    "on: orchestraitor task wildcard is not deny"
  assert_json_value "$config" '.agent.orchestraitor.permission.task["sdd-explore"]' allow \
    "on: orchestraitor task allowlist lost sdd-explore"
  # Unrelated config is untouched.
  assert_json_value "$config" '.agent.mentor.model' openai/gpt-5.6-sol \
    "on: clobbered an unrelated agent's model"
  pass shouldWriteCompleteBlocksPreservingFrontmatterDenies
}

shouldBeIdempotentWhenAlreadyOn() {
  local scratch target config before out
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  seed_config "$target/opencode.json"
  config="$target/opencode.json"
  "$AUTOMODE" on --target "$target" >/dev/null
  before="$(checksum "$config")"
  out="$("$AUTOMODE" on --target "$target")"
  case "$out" in
    *"auto mode is already on"*) ;;
    *) fail "on twice: missing the already-on message (got: $out)" ;;
  esac
  [ "$before" = "$(checksum "$config")" ] ||
    fail "on twice: config changed on the second run"
  pass shouldBeIdempotentWhenAlreadyOn
}

shouldReportNothingToRemoveWhenNotOn() {
  local scratch target config before out
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  seed_config "$target/opencode.json"
  config="$target/opencode.json"
  before="$(checksum "$config")"
  out="$("$AUTOMODE" off --target "$target")"
  case "$out" in
    *"auto mode is not on"*) ;;
    *) fail "off when off: missing the not-on message (got: $out)" ;;
  esac
  [ "$before" = "$(checksum "$config")" ] ||
    fail "off when off: config changed"
  pass shouldReportNothingToRemoveWhenNotOn
}

shouldWriteNothingOnDryRun() {
  local scratch target config before
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  seed_config "$target/opencode.json"
  config="$target/opencode.json"
  before="$(checksum "$config")"
  "$AUTOMODE" on --target "$target" --dry-run >/dev/null 2>&1
  [ "$before" = "$(checksum "$config")" ] ||
    fail "dry-run: config was modified"
  [ -z "$(find "$target" -name 'opencode.json.bak.*' -print -quit)" ] ||
    fail "dry-run: wrote a backup"
  pass shouldWriteNothingOnDryRun
}

shouldBackUpBeforeMutating() {
  local scratch target backup
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  seed_config "$target/opencode.json"
  "$AUTOMODE" on --target "$target" >/dev/null
  backup="$(find "$target" -name 'opencode.json.bak.*' -print -quit)"
  [ -n "$backup" ] || fail "on: no timestamped backup was written"
  jq -e '.agent | has("orchestraitor") | not' "$backup" >/dev/null ||
    fail "on: the backup already contains the new blocks"
  pass shouldBackUpBeforeMutating
}

shouldDieOnJsoncComments() {
  local scratch target status out
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  printf '%s\n' '// user comment' '{"agent":{}}' > "$target/opencode.jsonc"
  set +e
  out="$("$AUTOMODE" on --target "$target" 2>&1)"
  status=$?
  set -e
  assert_status 1 "$status" "jsonc comments: expected a hard failure"
  case "$out" in
    *"not valid JSON"*) ;;
    *) fail "jsonc comments: unclear error (got: $out)" ;;
  esac
  pass shouldDieOnJsoncComments
}

shouldPreferJsoncOverJsonWhenBothExist() {
  local scratch target
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  printf '%s\n' '{"agent":{}}' > "$target/opencode.jsonc"
  printf '%s\n' '{"agent":{}}' > "$target/opencode.json"
  "$AUTOMODE" on --target "$target" >/dev/null
  jq -e '.agent | has("orchestraitor")' "$target/opencode.jsonc" >/dev/null ||
    fail "both configs: .jsonc was not the one written"
  jq -e '.agent | has("orchestraitor") | not' "$target/opencode.json" >/dev/null ||
    fail "both configs: .json was written too"
  pass shouldPreferJsoncOverJsonWhenBothExist
}

shouldDieWithoutJq() {
  local scratch target status out stub tool
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  stub="$scratch/bin"
  mkdir -p "$target" "$stub"
  # A PATH carrying every external the script shells out to, except jq.
  # bash itself is on the list because the shebang resolves through env.
  for tool in bash awk basename cat cp date diff dirname grep mkdir mktemp rm sort; do
    ln -s "$(command -v "$tool")" "$stub/$tool"
  done
  set +e
  out="$(PATH="$stub" "$AUTOMODE" on --target "$target" 2>&1)"
  status=$?
  set -e
  assert_status 1 "$status" "without jq: expected a hard failure"
  case "$out" in
    *"jq is required"*) ;;
    *) fail "without jq: unclear error (got: $out)" ;;
  esac
  pass shouldDieWithoutJq
}

shouldRemoveGeneralEvenWithNoGeneral() {
  local scratch target config
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  seed_config "$target/opencode.json"
  config="$target/opencode.json"
  "$AUTOMODE" on --target "$target" >/dev/null
  jq -e '.agent.general.permission' "$config" >/dev/null ||
    fail "off/no-general: setup did not write a general block"
  "$AUTOMODE" off --target "$target" --no-general >/dev/null
  jq -e '.agent | has("general") | not' "$config" >/dev/null ||
    fail "off --no-general: the general block survived"
  jq -e '.agent | has("orchestraitor") | not' "$config" >/dev/null ||
    fail "off: an sdd block survived"
  assert_json_value "$config" '.agent.mentor.model' openai/gpt-5.6-sol \
    "off: removed an unrelated agent"
  pass shouldRemoveGeneralEvenWithNoGeneral
}

shouldSkipGeneralOnWithNoGeneral() {
  local scratch target config
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  config="$target/opencode.json"
  "$AUTOMODE" on --target "$target" --no-general >/dev/null
  jq -e '.agent | has("general") | not' "$config" >/dev/null ||
    fail "on --no-general: wrote a general block anyway"
  jq -e '.agent.orchestraitor.permission' "$config" >/dev/null ||
    fail "on --no-general: skipped the sdd agents too"
  pass shouldSkipGeneralOnWithNoGeneral
}

shouldDiscoverNewlyAddedAgents() {
  local scratch script target config
  scratch="$(make_scratch)"
  script="$(mirror_repo "$scratch/repo")"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  config="$target/opencode.json"
  cat > "$scratch/repo/domains/sdd/agents/sdd-brandnew.md" <<'EOF'
---
description: "Scratch agent used to prove glob discovery"
mode: subagent
permission:
  edit: deny
  question: deny
---
# Scratch
EOF
  "$script" on --target "$target" >/dev/null
  assert_json_value "$config" '.agent["sdd-brandnew"].permission.edit' deny \
    "glob discovery: the new agent was not picked up"
  assert_json_value "$config" '.agent["sdd-brandnew"].permission.read' allow \
    "glob discovery: the new agent got no base allow keys"
  pass shouldDiscoverNewlyAddedAgents
}

shouldDieOnUnknownPermissionValue() {
  local scratch script target status out
  scratch="$(make_scratch)"
  script="$(mirror_repo "$scratch/repo")"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  cat > "$scratch/repo/domains/sdd/agents/sdd-bogus.md" <<'EOF'
---
description: "Scratch agent with an invalid permission value"
mode: subagent
permission:
  edit: maybe
---
# Scratch
EOF
  set +e
  out="$("$script" on --target "$target" 2>&1)"
  status=$?
  set -e
  assert_status 1 "$status" "bad permission value: expected a hard failure"
  case "$out" in
    *"unrecognized permission value"*) ;;
    *) fail "bad permission value: unclear error (got: $out)" ;;
  esac
  pass shouldDieOnUnknownPermissionValue
}

shouldReportPerAgentAndAggregateState() {
  local scratch target config out
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  seed_config "$target/opencode.json"
  config="$target/opencode.json"

  out="$("$AUTOMODE" show --target "$target")"
  case "$out" in
    *"auto mode: off"*) ;;
    *) fail "show before on: expected the off aggregate (got: $out)" ;;
  esac

  "$AUTOMODE" on --target "$target" >/dev/null
  out="$("$AUTOMODE" show --target "$target")"
  case "$out" in
    *"auto mode: on"*) ;;
    *) fail "show after on: expected the on aggregate (got: $out)" ;;
  esac
  grep -Eq '^orchestraitor +on$' <<<"$out" ||
    fail "show after on: orchestraitor is not reported on"

  # Tamper with one block: it becomes custom and the aggregate becomes partial.
  jq '.agent.orchestraitor.permission.bash = "ask"' "$config" > "$config.tmp"
  mv "$config.tmp" "$config"
  out="$("$AUTOMODE" show --target "$target")"
  grep -Eq '^orchestraitor +custom$' <<<"$out" ||
    fail "show after tamper: orchestraitor is not reported custom"
  case "$out" in
    *"auto mode: partial"*) ;;
    *) fail "show after tamper: expected the partial aggregate (got: $out)" ;;
  esac
  pass shouldReportPerAgentAndAggregateState
}

shouldRejectUnknownActionAndArgument() {
  local scratch target status
  scratch="$(make_scratch)"
  target="$scratch/config/opencode"
  mkdir -p "$target"
  set +e
  "$AUTOMODE" sideways --target "$target" >/dev/null 2>&1
  status=$?
  set -e
  assert_status 1 "$status" "unknown action: expected a hard failure"
  set +e
  "$AUTOMODE" on --target "$target" --wat >/dev/null 2>&1
  status=$?
  set -e
  assert_status 1 "$status" "unknown argument: expected a hard failure"
  pass shouldRejectUnknownActionAndArgument
}

command -v jq >/dev/null 2>&1 || {
  printf 'SKIP: sdd-automode contracts need jq\n'
  exit 0
}

shouldWriteCompleteBlocksPreservingFrontmatterDenies
shouldBeIdempotentWhenAlreadyOn
shouldReportNothingToRemoveWhenNotOn
shouldWriteNothingOnDryRun
shouldBackUpBeforeMutating
shouldDieOnJsoncComments
shouldPreferJsoncOverJsonWhenBothExist
shouldDieWithoutJq
shouldRemoveGeneralEvenWithNoGeneral
shouldSkipGeneralOnWithNoGeneral
shouldDiscoverNewlyAddedAgents
shouldDieOnUnknownPermissionValue
shouldReportPerAgentAndAggregateState
shouldRejectUnknownActionAndArgument

printf 'PASS: %d sdd-automode contracts OK.\n' "$PASSES"
