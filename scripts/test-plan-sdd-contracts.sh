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

assert_relative_symlink() {
  local path="$1" expected="$2"
  CHECKS=$((CHECKS + 1))
  [ -L "$path" ] || { fail "$path" 'expected a shared-skill symlink'; return; }
  [ "$(readlink "$path")" = "$expected" ] || fail "$path" "expected relative target $expected"
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

assert_first_line() {
  local file="$1" expected="$2"
  CHECKS=$((CHECKS + 1))
  [ "$(sed -n '1p' "$file")" = "$expected" ] ||
    fail "$file" "expected first line: $expected"
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

assert_frontmatter_not_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  ! frontmatter "$file" | grep -Fq "$text" || fail "$file" "frontmatter retains: $text"
}

# One drafting contract replaces the retired phase fan-out.
assert_exists skills/sdd-draft-change/SKILL.md
assert_exists skills/sdd-draft-change/assets/change-template.md
assert_exists skills/sdd-cold-verification/SKILL.md
assert_exists skills/sdd-execution-skills/SKILL.md
assert_exists skills/sdd-execution-skills/assets/routing-cases.tsv
for owner in plan architecture common sdd; do
  assert_relative_symlink "domains/$owner/skills/sdd-draft-change" '../../../skills/sdd-draft-change'
  assert_relative_symlink "domains/$owner/skills/sdd-execution-skills" '../../../skills/sdd-execution-skills'
done
assert_relative_symlink domains/sdd-lite/skills/sdd-execution-skills '../../../skills/sdd-execution-skills'
for skill in behavior-characterization java-testing legacy-code-safety; do
  for owner in plan sdd; do
    assert_relative_symlink "domains/$owner/skills/$skill" "../../../skills/$skill"
  done
done
for owner in common sdd; do
  assert_relative_symlink "domains/$owner/skills/systematic-debugging" '../../../skills/systematic-debugging'
done
assert_absent domains/plan/skills/systematic-debugging
assert_relative_symlink domains/sdd/skills/cognitive-doc-design '../../../skills/cognitive-doc-design'
for skill in behavior-characterization code-conventions cognitive-doc-design java-testing legacy-code-safety systematic-debugging; do
  assert_relative_symlink "domains/sdd-lite/skills/$skill" "../../../skills/$skill"
done
for owner in sdd sdd-lite; do
  assert_relative_symlink "domains/$owner/skills/sdd-cold-verification" '../../../skills/sdd-cold-verification'
done
for retired in \
  sdd-draft-proposal sdd-draft-spec sdd-draft-design sdd-draft-tasks sdd-draft-light; do
  assert_absent "skills/$retired"
  assert_absent "domains/sdd/skills/$retired"
done
for retired in sdd-proposal sdd-spec sdd-design sdd-tasks; do
  assert_absent "domains/sdd/agents/$retired.md"
done

template=skills/sdd-draft-change/assets/change-template.md
for heading in '# Change:' '## Outcome' '## Scope' '## Behavior' '## Approach' '## Work' '## Verify'; do
  assert_contains "$template" "$heading"
done
assert_contains "$template" 'Status: draft | ready-for-sdd | active | Source: <producer>'
assert_first_line "$template" 'Status: draft | ready-for-sdd | active | Source: <producer>'
assert_contains "$template" '<capability>/<requirement>'
assert_contains "$template" 'RENAME <old-capability>/<old-requirement> -> <new-capability>/<new-requirement>'
assert_contains "$template" 'WHEN <condition>'
assert_contains "$template" 'THEN <observable result>'
assert_contains "$template" 'Files: <paths>'
assert_contains "$template" 'Skills: <comma-separated skill names or none>'
assert_contains skills/sdd-draft-change/SKILL.md 'at most 900 words'
assert_contains skills/sdd-draft-change/SKILL.md 'never edit production code, commit, or push'
assert_contains skills/sdd-draft-change/SKILL.md 'omits execution choices'
assert_contains skills/sdd-draft-change/SKILL.md 'preserves marker lines'
assert_frontmatter_contains skills/sdd-draft-change/SKILL.md 'version: "2.0.1"'
assert_contains skills/sdd-draft-change/SKILL.md 'Roadmap: <goal> | Slice: <n>/<total>'
assert_contains skills/sdd-draft-change/SKILL.md 'canonical merge never guesses a capability'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains skills/sdd-draft-change/SKILL.md 'Missing fields are invalid'
assert_not_contains skills/sdd-draft-change/SKILL.md 'legacy fields'
assert_frontmatter_contains skills/sdd-cold-verification/SKILL.md 'version: "1.0.0"'
assert_contains skills/sdd-cold-verification/SKILL.md 'A green but tautological test is a failure'
assert_contains skills/sdd-cold-verification/SKILL.md "Judgment owns broader correctness"
assert_contains domains/common/skills/grill/SKILL.md 'Mode, TDD, Judgment, and Delivery'

# One routing contract selects implementation skills without loading them in producers.
routing_skill=skills/sdd-execution-skills/SKILL.md
routing_cases=skills/sdd-execution-skills/assets/routing-cases.tsv
assert_frontmatter_contains "$routing_skill" 'version: "1.0.1"'
for skill in code-conventions java-testing behavior-characterization legacy-code-safety systematic-debugging cognitive-doc-design; do
  assert_contains "$routing_skill" "\`$skill\`"
done
assert_contains "$routing_skill" 'more than three names are invalid'
assert_contains "$routing_skill" 'producers never load the selected implementation skill bodies'
assert_contains "$routing_skill" 'Registry paths resolve availability only'
assert_frontmatter_contains skills/code-conventions/SKILL.md 'version: "2.0.0"'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains skills/code-conventions/SKILL.md 'Executable-change producers select its name through `sdd-execution-skills`'
assert_not_contains skills/code-conventions/SKILL.md 'writing or planning production code'
assert_contains global/AGENTS.md 'routing-only parents load neither skill body'
assert_not_contains global/AGENTS.md 'When writing or planning code or tests'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains global/AGENTS.md 'never bypass denied skill access by reading a `SKILL.md` path'
assert_first_line "$routing_cases" $'case\tproducer\twork signal\texpected Skills'
for producer in deep-planner architect orchestraitor grill-sdd orchestralite; do
  assert_contains "$routing_cases" $'\t'"$producer"$'\t'
done
CHECKS=$((CHECKS + 1))
awk -F '\t' '
  NR == 1 { next }
  {
    if ($4 == "none") next
    count = split($4, names, /, /)
    if (count > 3) exit 1
    for (i = 1; i <= count; i++) {
      if (names[i] !~ /^(code-conventions|java-testing|behavior-characterization|legacy-code-safety|systematic-debugging|cognitive-doc-design)$/) exit 1
    }
  }
' "$routing_cases" || fail "$routing_cases" 'contains an unknown or overloaded skill selection'

# One model-neutral planning skill owns decisions, discovery, and roadmaps.
planning_skill=domains/plan/skills/evidence-first-planning
assert_exists "$planning_skill/SKILL.md"
assert_exists "$planning_skill/assets/plan-template.md"
assert_exists "$planning_skill/assets/roadmap-template.md"
assert_frontmatter_contains "$planning_skill/SKILL.md" 'name: evidence-first-planning'
assert_frontmatter_contains "$planning_skill/SKILL.md" 'version: "3.0.0"'
assert_absent domains/plan/skills/fable-planning
assert_absent domains/plan/skills/wayfinder
assert_first_line "$planning_skill/assets/plan-template.md" 'Status: discovery | final | Source: deep-planner'
for heading in '## Destination' '## Evidence' '## Decisions' '## Open questions' '## Edge cases' '## Verification' '## Out of scope' '## Next'; do
  assert_contains "$planning_skill/assets/plan-template.md" "$heading"
done
assert_first_line "$planning_skill/assets/roadmap-template.md" 'Status: active | done | abandoned | Source: deep-planner'
for field in \
  '| # | Slice | Scope | Depends on | Status | Change |' \
  pending planned adopted 'done' dropped; do
  assert_contains "$planning_skill/assets/roadmap-template.md" "$field"
done

# Every current producer/consumer uses change.md and compact returns.
for file in \
  domains/plan/agents/deep-planner.md \
  domains/architecture/agents/architect.md; do
  assert_frontmatter_contains "$file" 'mode: primary'
  assert_frontmatter_contains "$file" 'question: allow'
  assert_contains "$file" 'change.md'
  assert_contains "$file" 'Status: ready-for-sdd'
  assert_not_contains "$file" 'sdlc-coordinator-receipt/v1'
done

assert_contains domains/plan/agents/deep-planner.md '.ai/deep-planner/changes/'
assert_frontmatter_contains domains/plan/agents/deep-planner.md 'evidence-first-planning: allow'
assert_frontmatter_contains domains/plan/agents/deep-planner.md 'sdd-execution-skills: allow'
for skill in behavior-characterization code-conventions java-testing legacy-code-safety systematic-debugging cognitive-doc-design; do
  assert_frontmatter_not_contains domains/plan/agents/deep-planner.md "$skill: allow"
done
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains domains/plan/agents/deep-planner.md 'Load `sdd-execution-skills` before drafting any executable change'
assert_contains domains/plan/agents/deep-planner.md 'never load or read implementation skill bodies'
assert_frontmatter_not_contains domains/plan/agents/deep-planner.md 'fable-planning: allow'
assert_frontmatter_not_contains domains/plan/agents/deep-planner.md 'wayfinder: allow'
assert_frontmatter_not_contains domains/plan/agents/deep-planner.md '".ai/wayfinder/**": allow'
assert_contains domains/plan/agents/deep-planner.md 'operation=deep-plan intent=auto|discovery'
assert_contains domains/plan/agents/deep-planner.md 'operation=refactor intent=auto|hardening'
assert_contains domains/plan/agents/deep-planner.md 'Medium/high risk permits one'
assert_contains domains/plan/agents/deep-planner.md 'critical risk permits at most two'
assert_contains domains/plan/agents/deep-planner.md 'continúa el roadmap <goal>'
assert_contains domains/plan/agents/deep-planner.md '.ai/roadmaps/<goal>.md'
assert_contains domains/plan/agents/deep-planner.md 'planned|adopted'
assert_contains domains/plan/agents/deep-planner.md 'first unblocked'
assert_contains domains/plan/agents/deep-planner.md 'On completion, lead with the planning outcome'
assert_frontmatter_contains domains/plan/agents/deep-planner.md 'refactor-analyzer: allow'
assert_exists domains/plan/agents/refactor-analyzer.md
assert_absent domains/refactor
assert_contains domains/architecture/README.md 'Class-level refactors belong to Plan'
assert_contains domains/architecture/README.md 'product requirements belong to Docs'
assert_absent domains/plan/agents/refactor-planner.md
assert_contains domains/architecture/agents/architect.md '.ai/architect/changes/'
assert_frontmatter_contains domains/architecture/agents/architect.md 'sdd-execution-skills: allow'
assert_frontmatter_not_contains domains/architecture/agents/architect.md 'code-conventions: allow'
assert_contains domains/architecture/agents/architect.md 'Every Work group records the routing result'
assert_contains domains/architecture/agents/architect.md 'never load or read implementation skill bodies'
assert_frontmatter_contains domains/architecture/skills/architecture-ideation/SKILL.md 'version: "3.0.2"'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains domains/architecture/skills/architecture-ideation/SKILL.md 'Load `sdd-execution-skills`'
assert_frontmatter_contains domains/common/skills/grill/SKILL.md 'version: "4.0.0"'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains domains/common/skills/grill/SKILL.md 'Load `sdd-execution-skills`'
assert_contains domains/common/skills/grill/SKILL.md 'never load or read implementation skill bodies'

orchestrator=domains/sdd/agents/orchestraitor.md
assert_frontmatter_contains "$orchestrator" 'mode: primary'
assert_frontmatter_contains "$orchestrator" 'question: allow'
for operation in direct-sdd execute-handoff resume; do
  assert_contains "$orchestrator" "$operation"
done
assert_frontmatter_contains "$orchestrator" 'sdd-canonical-merge: allow'
assert_contains "$orchestrator" 'change.md'
assert_contains "$orchestrator" 'state.md'
assert_contains "$orchestrator" '.ai/<producer>/changes/<change>/'
assert_contains "$orchestrator" 'Status: active'
assert_not_contains "$orchestrator" 'sdlc-coordinator-receipt/v1'
assert_regex "$orchestrator" 'adopt.*in place|in-place'
assert_regex "$orchestrator" '(keep|preserve).*producer marker'
assert_regex "$orchestrator" 'canonical spec'
assert_contains "$orchestrator" 'Roadmap: <goal> | Slice: <n>/<total>'
assert_contains "$orchestrator" '.ai/atl/skill-registry.md'
assert_contains "$orchestrator" 'fall back to the runtime skill catalog'
assert_contains "$orchestrator" 'skills=<csv|none>'
assert_frontmatter_contains "$orchestrator" 'sdd-execution-skills: allow'
assert_frontmatter_not_contains "$orchestrator" 'code-conventions: allow'
assert_contains "$orchestrator" 'missing or invalid fields block before implementation'
assert_contains "$orchestrator" 'never load or read implementation skill bodies'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$orchestrator" 'planned` to `adopted'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$orchestrator" 'set the matching slice `done`'

# Separate workers own implementation and canonical merge; neither owns Git publication.
implement=domains/sdd/agents/sdd-implement.md
assert_contains "$implement" 'change.md'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$implement" 'Never edit `change.md`, `state.md`, or canonical specs'
assert_regex "$implement" 'never .*commit.*push|never .*stage.*commit'
assert_not_contains "$implement" 'commit: "<sha> | none"'
assert_not_contains "$implement" 'tcr: allow'
assert_not_contains "$implement" 'work-unit-commits: allow'
assert_not_contains "$implement" 'MERGED <kind>'
for skill in behavior-characterization code-conventions cognitive-doc-design java-testing legacy-code-safety systematic-debugging; do
  assert_frontmatter_contains "$implement" "$skill: allow"
done
CHECKS=$((CHECKS + 1))
implementation_skill_count="$(frontmatter "$implement" | awk '
  /^  skill:/ { inside=1; next }
  inside && /^  [a-z_]+:/ { exit }
  inside && /^    [a-z0-9-]+: allow$/ { count++ }
  END { print count+0 }
')"
[ "$implementation_skill_count" -eq 6 ] ||
  fail "$implement" "expected exactly 6 implementation skills, found $implementation_skill_count"
assert_contains "$implement" 'Load every named allowlisted skill and no others'
spec_merge=domains/sdd/agents/sdd-canonical-merge.md
assert_exists "$spec_merge"
assert_frontmatter_contains "$spec_merge" 'mode: subagent'
assert_frontmatter_contains "$spec_merge" 'question: deny'
assert_frontmatter_contains "$spec_merge" 'bash: deny'
assert_frontmatter_contains "$spec_merge" 'skill: deny'
assert_frontmatter_contains "$spec_merge" '".ai/orchestrator/specs/**": allow'
assert_contains "$spec_merge" 'skills=none'
assert_contains "$spec_merge" 'MERGED <ADD|MODIFY|REMOVE|RENAME>'
assert_contains "$spec_merge" 'OK merge count=<n> stale=0'
assert_contains "$spec_merge" 'Never block an ADD only because the canonical root is absent'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$spec_merge" 'Never edit implementation, tests, `change.md`, or `state.md`'
verify=domains/sdd/agents/sdd-verify.md
assert_frontmatter_contains "$verify" 'edit: deny'
assert_frontmatter_contains "$verify" 'write: deny'
assert_contains "$verify" 'change.md'
assert_contains "$verify" 'explicit diff range'
assert_frontmatter_contains "$verify" 'sdd-cold-verification: allow'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$verify" 'Load `sdd-cold-verification`'
assert_frontmatter_contains domains/sdd-lite/agents/lite-verify.md 'sdd-cold-verification: allow'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains domains/sdd-lite/agents/lite-verify.md 'Load `sdd-cold-verification`'

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
  assert_contains "$change_dir/change.md" 'Skills:'
  assert_absent "$change_dir/proposal.md"
  assert_absent "$change_dir/design.md"
  assert_absent "$change_dir/tasks.md"
  CHECKS=$((CHECKS + 1))
  [ -z "$(find "$change_dir/specs" -type f -print -quit 2>/dev/null)" ] ||
    fail "$change_dir/specs" 'retired delta-spec files remain'
done

for command in deep-plan harden-plan refactor-plan wayfinder; do
  file="domains/plan/commands/$command.md"
  assert_frontmatter_contains "$file" 'agent: deep-planner'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
done
assert_contains domains/plan/commands/deep-plan.md 'operation=deep-plan intent=auto'
assert_contains domains/plan/commands/wayfinder.md 'operation=deep-plan intent=discovery'
assert_contains domains/plan/commands/refactor-plan.md 'operation=refactor intent=auto'
assert_contains domains/plan/commands/harden-plan.md 'operation=refactor intent=hardening'

# Human documentation records compact routes, artifact contracts, and eight prompts.
plan_readme=domains/plan/README.md
scenario_doc=docs/plan-flow-test-scenarios.md
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$plan_readme" '| `/deep-plan` | `deep-plan`, `intent=auto` |'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$plan_readme" '| `/wayfinder` | `deep-plan`, `intent=discovery` |'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$plan_readme" '| `/refactor-plan` | `refactor`, `intent=auto` |'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$plan_readme" '| `/harden-plan` | `refactor`, `intent=hardening` |'
assert_contains "$plan_readme" '.ai/deep-planner/changes/<change>/change.md'
assert_contains "$plan_readme" '.ai/deep-planner/plans/<slug>.md'
assert_contains "$plan_readme" '.ai/roadmaps/<goal>.md'
assert_contains "$plan_readme" 'Status: ready-for-sdd | Source: deep-planner'
assert_contains "$plan_readme" 'Roadmap: <goal> | Slice: <n>/<total>'
assert_contains "$plan_readme" 'continúa el roadmap <goal>'
assert_not_contains "$plan_readme" '```mermaid'
assert_exists "$scenario_doc"
for scenario in \
  PLAN-BOUNDED-01 PLAN-DECISION-01 PLAN-DISCOVERY-01 PLAN-ROADMAP-01 \
  PLAN-REFACTOR-01 PLAN-HARDEN-AUTO-01 PLAN-HARDEN-ALIAS-01 PLAN-REFACTOR-GUARD-01; do
  assert_contains "$scenario_doc" "$scenario"
done
for heading in '**Prompt:**' '**Expected artifacts/outcome:**' '**Forbidden behavior:**'; do
  assert_contains "$scenario_doc" "$heading"
done
assert_not_contains "$scenario_doc" 'OK plan/'
assert_not_contains "$scenario_doc" 'ASK plan/'
assert_not_contains "$scenario_doc" 'next='
assert_not_contains "$scenario_doc" 'planner child'
assert_not_contains "$scenario_doc" 'A2A'

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d plan/SDD contract violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d plan/SDD contract checks OK.\n' "$CHECKS"
