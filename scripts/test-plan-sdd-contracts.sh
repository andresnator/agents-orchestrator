#!/usr/bin/env bash
# Fast contract checks for the plan -> SDD handoff and SDD state machine.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

FAILS=0
CHECKS=0

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  FAILS=$((FAILS + 1))
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

for agent in sdd-proposal sdd-spec sdd-design sdd-tasks; do
  file="domains/sdd/agents/$agent.md"
  assert_contains "$file" 'Draft context: active | handoff'
  assert_contains "$file" 'draft_context: "<active | handoff>"'
  assert_contains "$file" '".ai/*/changes/**": allow'
done

assert_contains domains/plan/agents/deep-planner.md 'Draft context: handoff'
assert_contains domains/plan/agents/deep-planner.md 'draft_context: handoff'
assert_contains domains/sdd/agents/orchestraitor.md 'Draft context: active'
assert_contains domains/sdd/agents/orchestraitor.md '## Durable phase state'
assert_contains domains/sdd/agents/orchestraitor.md "Read \`state.md\` first."
assert_contains domains/sdd/agents/orchestraitor.md 'at most the first five lines'
assert_contains domains/sdd/agents/orchestraitor.md "If no \`Mode:\` line exists"
assert_contains domains/sdd/agents/sdd-proposal.md 'Status: ready-for-sdd | Source: <producer>'

assert_contains domains/sdd/agents/sdd-spec.md "\`REMOVED\`, and \`RENAMED\`"
assert_contains skills/sdd-draft-light/SKILL.md 'always executes as one sequential implementation wave'
assert_contains skills/sdd-draft-light/assets/change-template.md 'Files: {repo-relative files or globs touched by this change}'
assert_contains domains/sdd/agents/sdd-proposal.md "\`task_ids\`"
assert_not_contains domains/sdd/agents/sdd-proposal.md "groups\` (the \`## Tasks\` group count)"

assert_contains domains/sdd/agents/sdd-implement.md 'Never stage, commit, or push.'
assert_not_contains domains/sdd/agents/sdd-implement.md 'Commit instruction'
assert_not_contains domains/sdd/agents/sdd-implement.md 'commit: "<sha> | none"'
assert_not_contains domains/sdd/agents/sdd-implement.md 'tcr: allow'
assert_not_contains domains/sdd/agents/sdd-implement.md 'work-unit-commits: allow'

assert_contains docs/plan-handoff.md 'Draft context: handoff'
assert_contains docs/delegation-receipts.md 'Workers never stage or commit'

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d plan/SDD contract violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d plan/SDD contract checks OK.\n' "$CHECKS"
