#!/usr/bin/env bash
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
# Deterministic contracts for direct primaries and repository entry points.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

FAILS=0
CHECKS=0

fail() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; FAILS=$((FAILS + 1)); }

frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit 1; next }
       /^---[[:space:]]*$/ { found = 1; exit }
       { print }
       END { exit found ? 0 : 1 }' "$1"
}

assert_contains() {
  CHECKS=$((CHECKS + 1))
  grep -Fq -- "$2" "$1" || fail "$1" "missing contract text: $2"
}

assert_not_contains() {
  CHECKS=$((CHECKS + 1))
  ! grep -Fq -- "$2" "$1" || fail "$1" "retains forbidden text: $2"
}

assert_frontmatter_contains() {
  CHECKS=$((CHECKS + 1))
  frontmatter "$1" | grep -Fq -- "$2" || fail "$1" "frontmatter missing: $2"
}

assert_absent() {
  CHECKS=$((CHECKS + 1))
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "$1" 'retired component remains'
}

assert_primary() {
  assert_frontmatter_contains "$1" 'mode: primary'
  assert_frontmatter_contains "$1" 'question: allow'
}

planner=domains/plan/agents/deep-planner.md
architect=domains/architecture/agents/architect.md
orchestraitor=domains/orchestration/agents/orchestraitor.md
review=domains/review/agents/review-coordinator.md

for primary in "$planner" "$architect" "$orchestraitor" "$review"; do
  assert_primary "$primary"
done

assert_contains "$planner" 'Wayfinder discovers. Deep Plan plans.'
assert_contains "$planner" '`Create a plan`'
assert_contains "$planner" '`Explore an idea`'
assert_contains "$planner" 'normal chat, one at a time'
assert_contains "$orchestraitor" 'A change request uses direct execution.'
assert_contains "$orchestraitor" '`Make a change`, `Execute a plan`, or `Resume work`'
assert_contains "$orchestraitor" 'Do not create `.ai/` state'
assert_contains "$architect" 'one `.ai/architect/plans/<slug>.md`'

for worker in sdd-explore sdd-implement sdd-canonical-merge sdd-verify; do
  file="domains/orchestration/agents/$worker.md"
  assert_frontmatter_contains "$file" 'mode: subagent'
  assert_frontmatter_contains "$file" 'question: deny'
done
for worker in jd-fix jd-judge-a jd-judge-b jd-solo; do
  file="domains/review/agents/$worker.md"
  assert_frontmatter_contains "$file" 'mode: subagent'
  assert_frontmatter_contains "$file" 'question: deny'
done

for removed in deep-plan wayfinder refactor-plan harden-plan; do
  assert_absent "domains/plan/commands/$removed.md"
done
assert_absent domains/orchestration/commands/sdd.md
assert_absent domains/sdd

CHECKS=$((CHECKS + 1))
primary_count="$(grep -l '^mode: primary$' domains/{plan,architecture,orchestration,review}/agents/*.md | wc -l | tr -d ' ')"
[ "$primary_count" -eq 4 ] || fail domains "expected 4 primaries, found $primary_count"

CHECKS=$((CHECKS + 1))
command_count="$(find domains -path '*/commands/*.md' -type f | wc -l | tr -d ' ')"
[ "$command_count" -eq 15 ] || fail domains "expected 15 commands, found $command_count"

CHECKS=$((CHECKS + 1))
direct_commands="$(find domains/{plan,orchestration,architecture,review} -path '*/commands/*.md' -type f -exec grep -El '^agent: (deep-planner|architect|orchestraitor|review-coordinator)$' {} + | wc -l | tr -d ' ')"
[ "$direct_commands" -eq 6 ] || fail domains "expected 6 primary commands, found $direct_commands"

for domain in architecture common docs learning meta orchestration plan review; do
  readme="domains/$domain/README.md"
  CHECKS=$((CHECKS + 1))
  headings="$(grep '^## ' "$readme" | paste -sd '|' -)"
  [ "$headings" = '## Quick path|## Entry points|## Components' ] ||
    fail "$readme" "wrong H2 sequence: $headings"
done

assert_contains global/AGENTS.md 'free-text questions in normal chat'
assert_contains global/AGENTS.md 'question` tool only for closed choices'
assert_contains domains/common/README.md '`execution-plan`'
assert_contains domains/common/README.md '`implementation-skill-routing`'
assert_contains domains/review/README.md '`review-coordinator`'
assert_contains domains/learning/README.md '`mentor`'
assert_contains domains/docs/README.md '`/adr`'
assert_contains domains/meta/README.md '`/absorb`'

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d primary contract violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d primary agent contracts OK.\n' "$CHECKS"
