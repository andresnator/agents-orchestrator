#!/usr/bin/env bash
# Deterministic contracts for the SDLC orchestrator POC.

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

frontmatter() {
  awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    /^---[[:space:]]*$/ { found = 1; exit }
    { print }
    END { exit found ? 0 : 1 }
  ' "$1"
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

assert_frontmatter_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  frontmatter "$file" | grep -Fq "$text" || fail "$file" "frontmatter missing: $text"
}

assert_frontmatter_not_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  ! frontmatter "$file" | grep -Fq "$text" || fail "$file" "frontmatter retains: $text"
}

assert_receipt_schema() {
  local file="$1" field
  for field in contract status domain operation summary artifacts decisions scope acceptance_criteria risks open_questions next handoff; do
    assert_contains "$file" "$field:"
  done
  assert_contains "$file" 'sdlc-coordinator-receipt/v1'
  assert_contains "$file" 'complete | needs_input | blocked | failed'
}

primary="domains/sdlc/agents/sdlc-orchestrator.md"
assert_frontmatter_contains "$primary" 'mode: primary'
assert_frontmatter_contains "$primary" 'question: allow'
assert_frontmatter_contains "$primary" 'edit: deny'
assert_frontmatter_contains "$primary" 'write: deny'
assert_frontmatter_contains "$primary" 'bash: deny'
assert_frontmatter_contains "$primary" 'lsp: deny'
assert_frontmatter_contains "$primary" 'todowrite: deny'
assert_frontmatter_contains "$primary" 'skill: deny'
assert_frontmatter_contains "$primary" 'webfetch: deny'
assert_frontmatter_contains "$primary" 'websearch: deny'
assert_frontmatter_contains "$primary" 'external_directory: deny'
assert_frontmatter_contains "$primary" 'doom_loop: deny'
assert_frontmatter_not_contains "$primary" 'sdd-proposal: allow'
assert_frontmatter_not_contains "$primary" 'jd-judge-a: allow'

for coordinator in deep-planner refactor-planner architect orchestraitor orchestralite review-coordinator; do
  assert_frontmatter_contains "$primary" "$coordinator: allow"
done

assert_contains "$primary" 'Do not show a menu when one route is clearly safest.'
assert_contains "$primary" '[Beta] Refactor'
assert_contains "$primary" '[Beta] SDD Lite'
assert_contains "$primary" 'task_id'
assert_contains "$primary" 'same child'
assert_contains "$primary" 'operation: execute-handoff'
assert_contains "$primary" 'must not redraft proposal, design, specifications, or tasks'
assert_contains "$primary" 'operation: direct-sdd'
assert_receipt_schema "$primary"

review="domains/sdlc/agents/review-coordinator.md"
assert_frontmatter_contains "$review" 'mode: subagent'
assert_frontmatter_contains "$review" 'question: deny'
for phase_agent in jd-judge-a jd-judge-b jd-solo jd-fix; do
  assert_frontmatter_contains "$review" "$phase_agent: allow"
done
assert_contains "$review" 'Supported operations are'
assert_contains "$review" 'judgment'
assert_contains "$review" 'defend'
assert_contains "$review" 'same child through Task'
assert_contains "$review" 'task_id'
assert_receipt_schema "$review"

architect="domains/architecture/agents/architect.md"
assert_frontmatter_contains "$architect" 'mode: subagent'
assert_frontmatter_contains "$architect" 'question: deny'
assert_frontmatter_contains "$architect" 'arch-analyzer: allow'
assert_frontmatter_contains "$architect" 'boundary-inspector: allow'
assert_frontmatter_contains "$architect" '"npm audit*": allow'
assert_contains "$architect" 'raw user request in the coordinator brief'
assert_not_contains "$architect" "$RUNTIME_ARGUMENTS"
for operation in map review prd ideate audit boundary; do
  assert_contains "$architect" "$operation"
done
assert_contains "$architect" 'producer: architect'
assert_receipt_schema "$architect"

refactor="domains/refactor/agents/refactor-planner.md"
assert_frontmatter_contains "$refactor" 'mode: subagent'
assert_frontmatter_contains "$refactor" 'question: deny'
assert_frontmatter_contains "$refactor" 'refactor-analyzer: allow'
assert_frontmatter_contains "$refactor" '"git log*": allow'
assert_contains "$refactor" 'raw user request in the coordinator brief'
assert_not_contains "$refactor" "$RUNTIME_ARGUMENTS"
assert_contains "$refactor" 'operation: refactor | hardening'
assert_contains "$refactor" 'producer: refactor-planner'
assert_receipt_schema "$refactor"

for command in deep-plan wayfinder judgment defend; do
  case "$command" in
    deep-plan|wayfinder) file="domains/plan/commands/$command.md" ;;
    judgment) file="domains/sdd/commands/$command.md" ;;
    defend) file="domains/common/commands/$command.md" ;;
  esac
  assert_frontmatter_contains "$file" 'agent: sdlc-orchestrator'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
  assert_contains "$file" 'Explicit SDLC route:'
done

for command in arch-audit arch-ideate arch-map arch-prd arch-review boundary-inspector; do
  file="domains/architecture/commands/$command.md"
  assert_frontmatter_contains "$file" 'agent: sdlc-orchestrator'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
  assert_contains "$file" 'Explicit SDLC route:'
done

for command in harden-plan refactor-plan; do
  file="domains/refactor/commands/$command.md"
  assert_frontmatter_contains "$file" 'agent: sdlc-orchestrator'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
  assert_contains "$file" 'Explicit SDLC route:'
done

CHECKS=$((CHECKS + 1))
command_count="$(find domains -path '*/commands/*.md' -type f | wc -l | tr -d ' ')"
[ "$command_count" = "21" ] || fail domains "expected 21 commands, found $command_count"

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d SDLC orchestrator contract violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d SDLC orchestrator contract checks OK.\n' "$CHECKS"
