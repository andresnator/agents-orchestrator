#!/usr/bin/env bash
# Fast structural contracts for the one-document Plan -> SDD handoff.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

FAILS=0
CHECKS=0
# shellcheck disable=SC2016
RUNTIME_ARGUMENTS='$ARGUMENTS'

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  FAILS=$((FAILS + 1))
}

assert_exists() {
  CHECKS=$((CHECKS + 1))
  [ -e "$1" ] || [ -L "$1" ] || fail "$1" 'expected path is absent'
}

assert_absent() {
  CHECKS=$((CHECKS + 1))
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "$1" 'retired path still exists'
}

assert_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  grep -Fq "$text" "$file" || fail "$file" "missing contract text: $text"
}

assert_not_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  ! grep -Fq "$text" "$file" || fail "$file" "retains forbidden contract text: $text"
}

assert_regex() {
  local file="$1" pattern="$2"
  CHECKS=$((CHECKS + 1))
  grep -Eiq "$pattern" "$file" || fail "$file" "missing contract pattern: $pattern"
}

frontmatter() {
  awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    /^---[[:space:]]*$/ { found = 1; exit }
    { print }
    END { exit found ? 0 : 1 }
  ' "$1"
}

assert_frontmatter_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  frontmatter "$file" | grep -Fq "$text" || fail "$file" "frontmatter missing: $text"
}

# One drafting contract replaces the retired phase fan-out.
assert_exists domains/sdd/skills/sdd-draft-change/SKILL.md
assert_exists domains/sdd/skills/sdd-draft-change/assets/change-template.md
for retired in \
  sdd-draft-proposal sdd-draft-spec sdd-draft-design sdd-draft-tasks sdd-draft-light; do
  assert_absent "skills/$retired"
  assert_absent "domains/sdd/skills/$retired"
done
for retired in sdd-proposal sdd-spec sdd-design sdd-tasks; do
  assert_absent "domains/sdd/agents/$retired.md"
done

template=domains/sdd/skills/sdd-draft-change/assets/change-template.md
for heading in '# Change:' '## Outcome' '## Scope' '## Behavior' '## Approach' '## Work' '## Verify'; do
  assert_contains "$template" "$heading"
done
assert_contains "$template" 'Status: draft | ready-for-sdd | active | Source: <producer>'
assert_contains "$template" 'ADD|MODIFY|REMOVE|RENAME'
assert_contains "$template" 'WHEN <condition>'
assert_contains "$template" 'THEN <observable result>'
assert_contains "$template" 'Files: <paths>'
assert_contains domains/sdd/skills/sdd-draft-change/SKILL.md 'at most 900 words'
assert_contains domains/sdd/skills/sdd-draft-change/SKILL.md 'never edit production code, commit, or push'
assert_contains domains/sdd/skills/sdd-draft-change/SKILL.md 'omits the execution-choice line'
assert_contains domains/sdd/skills/sdd-draft-change/SKILL.md 'preserves the producer marker'
assert_contains domains/common/skills/grill/SKILL.md 'Mode, TDD, Judgment, and Delivery'

# Every current producer/consumer uses change.md and compact returns.
for file in \
  domains/plan/agents/deep-planner.md \
  domains/architecture/agents/architect.md; do
  assert_frontmatter_contains "$file" 'mode: subagent'
  assert_frontmatter_contains "$file" 'question: deny'
  assert_contains "$file" 'change.md'
  assert_contains "$file" 'Status: ready-for-sdd'
  assert_not_contains "$file" 'sdlc-coordinator-receipt/v1'
done

assert_contains domains/plan/agents/deep-planner.md '.ai/deep-planner/changes/'
for operation in deep-plan refactor hardening wayfinder; do
  assert_contains domains/plan/agents/deep-planner.md "$operation"
done
assert_frontmatter_contains domains/plan/agents/deep-planner.md 'refactor-analyzer: allow'
assert_exists domains/plan/agents/refactor-analyzer.md
assert_absent domains/refactor
assert_absent domains/plan/agents/refactor-planner.md
assert_contains domains/architecture/agents/architect.md '.ai/architect/changes/'

orchestrator=domains/sdd/agents/orchestraitor.md
assert_frontmatter_contains "$orchestrator" 'mode: subagent'
assert_frontmatter_contains "$orchestrator" 'question: deny'
for operation in direct-sdd execute-handoff resume; do
  assert_contains "$orchestrator" "$operation"
done
assert_contains "$orchestrator" 'change.md'
assert_contains "$orchestrator" 'state.md'
assert_contains "$orchestrator" '.ai/<producer>/changes/<change>/'
assert_contains "$orchestrator" 'Status: active'
assert_not_contains "$orchestrator" 'sdlc-coordinator-receipt/v1'
assert_regex "$orchestrator" 'adopt.*in place|in-place'
assert_contains "$orchestrator" 'keep the producer marker'
assert_regex "$orchestrator" 'canonical spec'

# Implementation owns code and canonical merge, but never Git publication.
implement=domains/sdd/agents/sdd-implement.md
assert_contains "$implement" 'change.md'
assert_contains "$implement" "Never edit \`change.md\` or \`state.md\`"
assert_regex "$implement" 'never .*commit.*push|never .*stage.*commit'
assert_not_contains "$implement" 'commit: "<sha> | none"'
assert_not_contains "$implement" 'tcr: allow'
assert_not_contains "$implement" 'work-unit-commits: allow'
verify=domains/sdd/agents/sdd-verify.md
assert_frontmatter_contains "$verify" 'edit: deny'
assert_frontmatter_contains "$verify" 'write: deny'
assert_contains "$verify" 'change.md'
assert_contains "$verify" 'explicit diff range'

# No runtime/profile/fixture contract may retain the deleted drafting inventory.
inventory_roots=(domains/plan domains/architecture domains/sdd domains/sdd-lite profiles scripts/fixtures/sdd-agent-routes/java-orders)
for retired in \
  sdd-proposal sdd-spec sdd-design sdd-tasks \
  sdd-draft-proposal sdd-draft-spec sdd-draft-design sdd-draft-tasks sdd-draft-light; do
  CHECKS=$((CHECKS + 1))
  if rg -l -F "$retired" "${inventory_roots[@]}" >/dev/null 2>&1; then
    fail "$retired" 'retired name remains in runtime, profile, or fixture inventory'
  fi
done

assert_absent docs/plan-handoff.md
assert_absent docs/delegation-receipts.md

fixture_root=scripts/fixtures/sdd-agent-routes/java-orders/state-seeds
for change_dir in \
  "$fixture_root/ready-plan/ai/deep-planner/changes/enforce-order-limit" \
  "$fixture_root/canonical-spec/ai/orchestrator/changes/adjust-order-pricing" \
  "$fixture_root/legacy/orchestraitor/changes/rename-order-reference"; do
  assert_exists "$change_dir/change.md"
  assert_absent "$change_dir/proposal.md"
  assert_absent "$change_dir/design.md"
  assert_absent "$change_dir/tasks.md"
  CHECKS=$((CHECKS + 1))
  [ -z "$(find "$change_dir/specs" -type f -print -quit 2>/dev/null)" ] ||
    fail "$change_dir/specs" 'retired delta-spec files remain'
done

for command in deep-plan harden-plan refactor-plan wayfinder; do
  file="domains/plan/commands/$command.md"
  assert_frontmatter_contains "$file" 'agent: sdlc-orchestrator'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
done

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d plan/SDD contract violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d plan/SDD contract checks OK.\n' "$CHECKS"
