#!/usr/bin/env bash
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
# Structural contracts for Wayfinder, Deep Plan, direct execution, and SDD.
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

assert_frontmatter_order() {
  local content before after
  CHECKS=$((CHECKS + 1))
  content="$(frontmatter "$1")"
  before="$(printf '%s\n' "$content" | grep -nF -- "$2" | head -1 | cut -d: -f1)"
  after="$(printf '%s\n' "$content" | grep -nF -- "$3" | head -1 | cut -d: -f1)"
  if [ -z "$before" ] || [ -z "$after" ] || [ "$before" -ge "$after" ]; then
    fail "$1" "frontmatter must place '$2' before '$3'"
  fi
}

assert_absent() {
  CHECKS=$((CHECKS + 1))
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "$1" 'retired path remains'
}

assert_relative_symlink() {
  CHECKS=$((CHECKS + 1))
  [ -L "$1" ] || { fail "$1" 'expected shared-skill symlink'; return; }
  [ "$(readlink "$1")" = "$2" ] || fail "$1" "expected target $2"
}

for owner in plan architecture common; do
  assert_relative_symlink "domains/$owner/skills/execution-plan" '../../../skills/execution-plan'
done
for owner in plan architecture common orchestration; do
  assert_relative_symlink "domains/$owner/skills/implementation-skill-routing" '../../../skills/implementation-skill-routing'
done
assert_absent domains/orchestration/skills/execution-plan

execution_skill=skills/execution-plan/SKILL.md
execution_template=skills/execution-plan/assets/plan-template.md
routing_skill=skills/implementation-skill-routing/SKILL.md
assert_frontmatter_contains "$execution_skill" 'version: "1.0.1"'
assert_frontmatter_contains "$routing_skill" 'version: "2.0.0"'
assert_contains "$execution_skill" 'Update an existing plan only when the user supplied its exact path or the active conversation already created or selected it.'
assert_contains "$execution_skill" 'reuse the existing plan or generate a new slug'
assert_contains "$execution_skill" 'Never overwrite implicitly.'
assert_contains "$routing_skill" 'Read `.ai/atl/skill-registry.md` by its literal path'
assert_contains "$routing_skill" 'the `Trigger` and `Skill` columns from the `## Skills` table'
assert_contains "$routing_skill" 'Use the runtime skill catalog when the registry is absent'
assert_contains "$routing_skill" 'planning, discovery, review, delivery, or Git'
assert_contains "$routing_skill" 'Return at most three names.'
assert_contains "$routing_skill" 'Return names, never paths.'
assert_contains "$routing_skill" 'an unavailable name or a trigger that contradicts the assigned work is `BLOCK skill-routing <reason>`'
assert_not_contains "$routing_skill" '| Work signal | Skill name |'
assert_absent skills/implementation-skill-routing/assets/routing-cases.tsv
for heading in '## Outcome' '## Scope' '## Evidence' '## Behavior' '## Approach' \
  '## Work groups' '## Dependencies' '## Files' '## Skills' '## Verify' \
  '## Risks and open questions' '## Execution guidance'; do
  assert_contains "$execution_template" "$heading"
done
assert_contains "$execution_template" 'Route: direct | SDD'
assert_contains "$execution_template" 'Run: `ejecuta el plan <path>`'

planning_skill=domains/plan/skills/evidence-first-planning/SKILL.md
discovery_template=domains/plan/skills/evidence-first-planning/assets/discovery-template.md
assert_frontmatter_contains "$planning_skill" 'version: "5.0.0"'
assert_contains "$planning_skill" '.ai/deep-planner/discoveries/<slug>.md'
assert_contains "$planning_skill" '.ai/deep-planner/plans/<slug>.md'
assert_contains "$planning_skill" 'Do not create roadmaps, slices, readiness markers'
assert_not_contains "$discovery_template" 'Status:'
assert_contains "$discovery_template" '## Evidence'
assert_contains "$discovery_template" '## Decisions'
assert_contains "$discovery_template" '## Open questions'
assert_contains "$discovery_template" 'convert this discovery into a plan'
assert_absent domains/plan/skills/evidence-first-planning/assets/roadmap-template.md

planner=domains/plan/agents/deep-planner.md
assert_contains "$planner" 'Infer the route when the request is clear.'
assert_contains "$planner" 'use one `question` choice'
assert_contains "$planner" 'Create exactly one `.ai/deep-planner/plans/<slug>.md`'
assert_contains "$planner" 'including when the plan is large'
assert_contains "$planner" 'tooling, minimal seams, focused tests, and revalidation before restructuring'
assert_contains "$planner" 'Recommend `SDD` for dependent groups, public contracts, migrations, high risk, durable resume, parallel coordination, or canonical specs.'
assert_frontmatter_contains "$planner" 'execution-plan: allow'
assert_frontmatter_contains "$planner" 'implementation-skill-routing: allow'

orchestraitor=domains/orchestration/agents/orchestraitor.md
assert_contains "$orchestraitor" 'A change request uses direct execution.'
assert_contains "$orchestraitor" '`ejecuta el plan <path>` executes that exact plan.'
assert_contains "$orchestraitor" '`continúa <run>` resumes that exact SDD run.'
assert_contains "$orchestraitor" 'Do not create `.ai/` state, a plan, canonical specs, or SDD workers.'
assert_contains "$orchestraitor" 'ask one closed confirmation before creating state'
assert_contains "$orchestraitor" 'automatic execution, tests alongside the change, no Judgment, and no commits'
assert_contains "$orchestraitor" '.ai/orchestration/runs/<slug>/run.md'
assert_contains "$orchestraitor" 'never copy, rewrite, or mark it'
assert_contains "$orchestraitor" 'Verify the original plan hash before and after every wave.'
assert_contains "$orchestraitor" 'return `/judgment <run-root>`, and stop'
assert_contains "$orchestraitor" 'require `<run-root>/judgment.md`'
assert_contains "$orchestraitor" '.ai/orchestration/runs/archive/<YYYY-MM-DD>-<slug>/'
assert_contains "$orchestraitor" 'Report progress in natural language.'
assert_frontmatter_contains "$orchestraitor" 'implementation-skill-routing: allow'
assert_frontmatter_contains "$orchestraitor" '"*": allow'
assert_frontmatter_contains "$orchestraitor" 'judgment-day: deny'
assert_frontmatter_contains "$orchestraitor" 'work-unit-commits: deny'
assert_frontmatter_order "$orchestraitor" '"*": allow' 'judgment-day: deny'
assert_frontmatter_order "$orchestraitor" '"*": allow' 'work-unit-commits: deny'

for worker in sdd-implement sdd-verify sdd-canonical-merge; do
  assert_contains "domains/orchestration/agents/$worker.md" '.ai/orchestration/'
done
assert_contains domains/orchestration/agents/sdd-implement.md 'Never edit the plan, `run.md`, or canonical specs'
assert_contains domains/orchestration/agents/sdd-implement.md 'every named registered skill assigned by `implementation-skill-routing`'
assert_frontmatter_contains domains/orchestration/agents/sdd-implement.md '"*": allow'
assert_frontmatter_contains domains/orchestration/agents/sdd-implement.md 'judgment-day: deny'
assert_frontmatter_contains domains/orchestration/agents/sdd-implement.md 'work-unit-commits: deny'
assert_frontmatter_order domains/orchestration/agents/sdd-implement.md '"*": allow' 'judgment-day: deny'
assert_frontmatter_order domains/orchestration/agents/sdd-implement.md '"*": allow' 'work-unit-commits: deny'
assert_contains domains/orchestration/agents/sdd-verify.md 'immutable plan path'
assert_contains domains/orchestration/agents/sdd-canonical-merge.md '.ai/orchestration/specs/'

cold_verification=domains/orchestration/skills/sdd-cold-verification/SKILL.md
assert_frontmatter_contains "$cold_verification" 'version: "1.0.1"'
assert_contains "$cold_verification" 'Exact `.ai/orchestration/runs/<slug>/` root and its `run.md`.'
assert_contains "$cold_verification" 'Immutable plan path when `run.md` references one.'
assert_not_contains "$cold_verification" 'change.md'

architect=domains/architecture/agents/architect.md
assert_contains "$architect" 'For `ideate`, lead with the architecture outcome'
assert_contains "$architect" 'For `map`, `review`, and `boundary`, return only the actual artifact paths'
assert_contains "$architect" 'do not invent a plan or execution handoff'

assert_frontmatter_contains domains/architecture/skills/architecture-ideation/SKILL.md 'version: "4.0.0"'
assert_contains domains/architecture/skills/architecture-ideation/SKILL.md 'one `.ai/architect/plans/<slug>.md`'
assert_frontmatter_contains domains/common/skills/grill/SKILL.md 'version: "6.0.0"'
assert_contains domains/common/skills/grill/SKILL.md 'one approved neutral plan'

for path in \
  domains/plan/commands/deep-plan.md domains/plan/commands/wayfinder.md \
  domains/plan/commands/refactor-plan.md domains/plan/commands/harden-plan.md \
  domains/orchestration/commands/sdd.md skills/sdd-draft-change skills/sdd-execution-skills; do
  assert_absent "$path"
done

scenario_doc=docs/plan-flow-test-scenarios.md
for scenario in ROUTE-CLEAR-01 ROUTE-AMBIGUOUS-01 WAYFINDER-01 DISCOVERY-TO-PLAN-01 \
  LARGE-PLAN-01 DIRECT-RENAME-01 DIRECT-REFACTOR-01 SDD-CONFIRM-01 SDD-COMPLETE-01; do
  assert_contains "$scenario_doc" "$scenario"
done
assert_contains docs/architecture/adr/0001-adaptive-planning-and-orchestration.md 'Accepted'

flow_runner=scripts/test-orchestration-flows.sh
assert_contains "$flow_runner" 'install_current_profile'
assert_contains "$flow_runner" 'BigDecimal orderSubtotal = order.subtotal();'
assert_contains "$flow_runner" 'select(.part?.tool == "question")'
assert_contains scripts/test-multi-primary-e2e.sh '"$PROFILE" install --project-root "$PROJECT" --no-install-brew-tools'
assert_contains docs/orchestration-test-plan.md 'ORCHESTRATION_FLOW_CONFIRM=run-paid-flow'

CHECKS=$((CHECKS + 1))
if rg -n 'LEGACY_[A-Z0-9_]+' . --hidden --glob '!.git/**' >/dev/null 2>&1; then
  fail repository 'LEGACY_* contract remains'
fi

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d plan/orchestration violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d plan/orchestration contract checks OK.\n' "$CHECKS"
