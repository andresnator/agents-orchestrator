#!/usr/bin/env bash
# Deterministic contracts for routing, ownership, and compact SDLC A2A returns.

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

assert_regex() {
  local file="$1" pattern="$2"
  CHECKS=$((CHECKS + 1))
  grep -Eq "$pattern" "$file" || fail "$file" "missing contract pattern: $pattern"
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

assert_compact_coordinator_return() {
  local file="$1"
  assert_regex "$file" 'OK [^[:space:]]+/[^[:space:]]+'
  assert_regex "$file" 'ASK( |`)'
  assert_regex "$file" 'BLOCK( |`)'
  assert_regex "$file" 'FAIL( |`)'
  assert_not_contains "$file" 'sdlc-coordinator-receipt/v1'
  assert_not_contains "$file" 'acceptance_criteria:'
  assert_not_contains "$file" 'open_questions:'
}

primary=domains/sdlc/agents/sdlc-orchestrator.md
assert_frontmatter_contains "$primary" 'mode: primary'
assert_frontmatter_contains "$primary" 'question: allow'
for denied in edit write bash lsp todowrite skill webfetch websearch external_directory doom_loop; do
  assert_frontmatter_contains "$primary" "$denied: deny"
done

# The primary delegates only to domain coordinators.
for coordinator in deep-planner refactor-planner architect orchestraitor orchestralite review-coordinator; do
  assert_frontmatter_contains "$primary" "$coordinator: allow"
done
for worker in \
  sdd-explore sdd-implement sdd-verify lite-verify refactor-analyzer arch-analyzer \
  boundary-inspector jd-judge-a jd-judge-b jd-solo jd-fix general; do
  assert_frontmatter_not_contains "$primary" "$worker: allow"
done
for route in plan refactor architecture sdd sdd-lite review; do
  assert_contains "$primary" "$route"
done
assert_regex "$primary" 'Task id|task_id'
assert_contains "$primary" 'same child'
assert_contains "$primary" 'execute-handoff'
assert_contains "$primary" 'direct-sdd'
assert_compact_coordinator_return "$primary"
assert_regex "$primary" 'normal[- ](human[- ])?language|human-readable|paraphrase.*user'
assert_regex "$primary" 'security|irreversible|destructive'

review=domains/sdlc/agents/review-coordinator.md
assert_frontmatter_contains "$review" 'mode: subagent'
assert_frontmatter_contains "$review" 'question: deny'
for phase_agent in jd-judge-a jd-judge-b jd-solo jd-fix; do
  assert_frontmatter_contains "$review" "$phase_agent: allow"
done
assert_contains "$review" 'judgment'
assert_contains "$review" 'defend'
assert_compact_coordinator_return "$review"

architect=domains/architecture/agents/architect.md
assert_frontmatter_contains "$architect" 'mode: subagent'
assert_frontmatter_contains "$architect" 'question: deny'
assert_frontmatter_contains "$architect" 'arch-analyzer: allow'
assert_frontmatter_contains "$architect" 'boundary-inspector: allow'
assert_frontmatter_not_contains "$architect" 'skill: allow'
assert_frontmatter_contains "$architect" '"*": deny'
for operation in map review prd ideate audit boundary; do
  assert_contains "$architect" "$operation"
done
assert_contains "$architect" 'change.md'
assert_contains "$architect" 'exact target-specific path'
assert_contains "$architect" 'report exists'
assert_not_contains "$architect" "$RUNTIME_ARGUMENTS"
assert_compact_coordinator_return "$architect"

refactor=domains/refactor/agents/refactor-planner.md
assert_frontmatter_contains "$refactor" 'mode: subagent'
assert_frontmatter_contains "$refactor" 'question: deny'
assert_frontmatter_contains "$refactor" 'refactor-analyzer: allow'
assert_frontmatter_not_contains "$refactor" 'skill: allow'
assert_frontmatter_contains "$refactor" '"*": deny'
assert_contains "$refactor" 'refactor'
assert_contains "$refactor" 'hardening'
assert_contains "$refactor" 'change.md'
assert_not_contains "$refactor" "$RUNTIME_ARGUMENTS"
assert_compact_coordinator_return "$refactor"

for analyzer in \
  domains/architecture/agents/arch-analyzer.md \
  domains/architecture/agents/boundary-inspector.md \
  domains/refactor/agents/refactor-analyzer.md; do
  assert_frontmatter_contains "$analyzer" '"*": deny'
done
assert_frontmatter_contains domains/architecture/agents/boundary-inspector.md 'service-boundary-analysis: allow'
assert_frontmatter_contains domains/architecture/agents/boundary-inspector.md '".ai/architect/reports/**": allow'
assert_contains domains/architecture/agents/boundary-inspector.md 'caller-supplied report path'
assert_contains domains/architecture/agents/boundary-inspector.md 'no logs or report body in A2A'

for coordinator in domains/plan/agents/deep-planner.md domains/sdd/agents/orchestraitor.md; do
  assert_frontmatter_contains "$coordinator" 'mode: subagent'
  assert_frontmatter_contains "$coordinator" 'question: deny'
  assert_compact_coordinator_return "$coordinator"
done

lite=domains/sdd-lite/agents/orchestralite.md
assert_frontmatter_contains "$lite" 'mode: subagent'
assert_frontmatter_contains "$lite" 'question: deny'
assert_frontmatter_contains "$lite" 'lite-verify: allow'
assert_contains "$lite" 'sdd-lite'
assert_contains "$lite" 'change.md'
assert_contains "$lite" 'lite-verify'
assert_contains "$lite" 'Judgment: none | Delivery: none'
assert_not_contains "$lite" "$RUNTIME_ARGUMENTS"
assert_compact_coordinator_return "$lite"

assert_frontmatter_contains domains/sdd-lite/agents/lite-verify.md 'mode: subagent'
assert_frontmatter_contains domains/sdd-lite/agents/lite-verify.md 'question: deny'
assert_contains domains/sdd-lite/agents/lite-verify.md 'PASS <passed>/<total> evidence=<path:line or one-line test>'
assert_contains domains/sdd/agents/sdd-implement.md 'OK wave=<id> files=<csv> check=<one-line result>'
assert_contains domains/sdd/agents/sdd-verify.md 'PASS <passed>/<total> evidence=<path:line or one-line test>'

# Exactly one question owner and one primary in the installed SDLC profile.
profile_primary_count=0
profile_question_owner_count=0
for domain in sdlc plan sdd architecture refactor sdd-lite common; do
  for file in "domains/$domain/agents/"*.md; do
    [ -f "$file" ] || continue
    CHECKS=$((CHECKS + 1))
    frontmatter "$file" | grep -Eq '^  question: (allow|deny)$' ||
      fail "$file" 'profile agent must declare question permission explicitly'
    if frontmatter "$file" | grep -Eq '^mode: primary$'; then
      profile_primary_count=$((profile_primary_count + 1))
      [ "$file" = "$primary" ] || fail "$file" 'unexpected repository-owned primary'
    fi
    if frontmatter "$file" | grep -Eq '^  question: allow$'; then
      profile_question_owner_count=$((profile_question_owner_count + 1))
      [ "$file" = "$primary" ] || fail "$file" 'unexpected question owner'
    fi
  done
done
CHECKS=$((CHECKS + 1))
[ "$profile_primary_count" -eq 1 ] || fail domains "expected one profile primary, found $profile_primary_count"
CHECKS=$((CHECKS + 1))
[ "$profile_question_owner_count" -eq 1 ] || fail domains "expected one question owner, found $profile_question_owner_count"

# Routed commands carry only their raw argument and route through the primary.
expected_aliases="$(printf '%s\n' \
  arch-audit arch-ideate arch-map arch-prd arch-review boundary-inspector \
  deep-plan defend harden-plan judgment refactor-plan wayfinder | sort)"
actual_aliases="$(find domains -path '*/commands/*.md' -type f -print | while IFS= read -r file; do
  if frontmatter "$file" | grep -Eq '^agent: sdlc-orchestrator$'; then
    basename "$file" .md
  fi
done | sort)"
CHECKS=$((CHECKS + 1))
[ "$actual_aliases" = "$expected_aliases" ] || fail domains 'SDLC alias set differs from the required 12 commands'

for command in $expected_aliases; do
  case "$command" in
    arch-*) file="domains/architecture/commands/$command.md" ;;
    boundary-inspector) file="domains/architecture/commands/$command.md" ;;
    deep-plan|wayfinder) file="domains/plan/commands/$command.md" ;;
    harden-plan|refactor-plan) file="domains/refactor/commands/$command.md" ;;
    judgment) file="domains/sdd/commands/$command.md" ;;
    defend) file="domains/common/commands/$command.md" ;;
  esac
  assert_frontmatter_contains "$file" 'agent: sdlc-orchestrator'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
done

for command in graphify-index grill; do
  file="domains/common/commands/$command.md"
  CHECKS=$((CHECKS + 1))
  ! frontmatter "$file" | grep -Eq '^agent: sdlc-orchestrator$' ||
    fail "$file" 'must remain outside SDLC alias routing'
done

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d SDLC orchestrator contract violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d SDLC orchestrator contract checks OK.\n' "$CHECKS"
