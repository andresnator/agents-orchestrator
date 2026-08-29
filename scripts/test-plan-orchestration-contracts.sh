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
assert_absent domains/orchestration/skills/work-unit-commits
assert_absent skills/work-unit-commits
assert_contains domains/common/skills/work-unit-commits/SKILL.md 'name: work-unit-commits'

execution_skill=skills/execution-plan/SKILL.md
execution_template=skills/execution-plan/assets/plan-template.md
routing_skill=skills/implementation-skill-routing/SKILL.md
assert_frontmatter_contains "$execution_skill" 'version: "1.0.1"'
assert_frontmatter_contains "$routing_skill" 'version: "3.0.0"'
assert_contains "$execution_skill" 'Update an existing plan only when the user supplied its exact path or the active conversation already created or selected it.'
assert_contains "$execution_skill" 'reuse the existing plan or generate a new slug'
assert_contains "$execution_skill" 'Never overwrite implicitly.'
assert_contains "$routing_skill" 'Read `.ai/atl/skill-registry.md` by its literal path'
assert_contains "$routing_skill" '`## OpenCode Skills`, `## Agent Skills`, and `## Claude Skills`'
assert_contains "$routing_skill" '`Description | Skill | Location` columns'
assert_contains "$routing_skill" 'Match work signals only against `Description` and return only names from `Skill`.'
assert_contains "$routing_skill" 'Treat `Location` as diagnostic information only.'
assert_contains "$routing_skill" "bypass the runtime's native skill loader"
assert_contains "$routing_skill" 'registry is absent, malformed, has no matching description, or a selected skill is no longer available'
assert_contains "$routing_skill" 'Do not accept the legacy `## Skills` section or `Trigger` column.'
assert_contains "$routing_skill" 'planning, discovery, review, delivery, or Git'
assert_contains "$routing_skill" 'Return at most three names.'
assert_contains "$routing_skill" 'Return names, never paths.'
assert_contains "$routing_skill" 'an unavailable name or a description that contradicts the assigned work is `BLOCK skill-routing <reason>`'
assert_not_contains "$routing_skill" 'the `Trigger` and `Skill` columns from the `## Skills` table'
assert_not_contains "$routing_skill" 'trigger directly matches an assigned work signal'
assert_not_contains "$routing_skill" 'eligible trigger matches'
assert_not_contains "$routing_skill" '| Trigger | Skill |'
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
assert_contains "$orchestraitor" 'Git delivery is outside this primary and every worker.'
assert_contains "$orchestraitor" 'Never stage, commit, or push.'
assert_contains "$orchestraitor" 'finish the verified changes and explain that Git delivery must happen outside Orchestraitor'
assert_contains "$orchestraitor" 'Route all implementation skill selection and validation through `implementation-skill-routing`.'
assert_contains "$orchestraitor" 'Review is a separate primary, not an SDD phase or completion gate.'
assert_contains "$orchestraitor" '.ai/orchestration/runs/<slug>/run.md'
assert_contains "$orchestraitor" 'never copy, rewrite, or mark it'
assert_contains "$orchestraitor" 'Verify the original plan hash before and after every wave.'
assert_contains "$orchestraitor" 'plan path and recorded SHA-256 when present, every source scenario, the complete `Files:` scope, every source `Verify` item, and the explicit diff baseline'
assert_contains "$orchestraitor" 'Complete and archive SDD after its own verification.'
assert_contains "$orchestraitor" 'tell them to select `review-coordinator`'
assert_contains "$orchestraitor" '.ai/orchestration/runs/archive/<YYYY-MM-DD>-<slug>/'
assert_contains "$orchestraitor" 'Report progress in natural language.'
assert_not_contains "$orchestraitor" 'Judgment'
assert_not_contains "$orchestraitor" '/judgment'
assert_not_contains "$orchestraitor" 'judgment.md'
assert_not_contains "$orchestraitor" 'work-unit-commits: allow'
assert_frontmatter_contains "$orchestraitor" 'implementation-skill-routing: allow'
assert_frontmatter_contains "$orchestraitor" '"*": allow'
assert_frontmatter_contains "$orchestraitor" 'judgment-day: deny'
assert_frontmatter_contains "$orchestraitor" 'work-unit-commits: deny'
assert_not_contains "$orchestraitor" 'Resolve skill names from `.ai/atl/skill-registry.md`'
assert_not_contains "$orchestraitor" 'fall back to the runtime skill catalog'
assert_frontmatter_order "$orchestraitor" '"*": allow' 'judgment-day: deny'
assert_frontmatter_order "$orchestraitor" '"*": allow' 'work-unit-commits: deny'

for worker in sdd-implement sdd-verify sdd-canonical-merge; do
  assert_contains "domains/orchestration/agents/$worker.md" '.ai/orchestration/'
  assert_contains "domains/orchestration/agents/$worker.md" 'stage, commit, or push'
done
assert_contains domains/orchestration/agents/sdd-explore.md 'stage, commit, or push'
assert_contains "$orchestraitor" 'Never ask it to mutate Git.'
assert_contains domains/orchestration/agents/sdd-implement.md 'Never edit the plan, `run.md`, or canonical specs'
assert_contains domains/orchestration/agents/sdd-implement.md 'every named registered skill assigned by `implementation-skill-routing`'
assert_frontmatter_contains domains/orchestration/agents/sdd-implement.md '"*": allow'
assert_frontmatter_contains domains/orchestration/agents/sdd-implement.md 'judgment-day: deny'
assert_frontmatter_contains domains/orchestration/agents/sdd-implement.md 'work-unit-commits: deny'
assert_frontmatter_order domains/orchestration/agents/sdd-implement.md '"*": allow' 'judgment-day: deny'
assert_frontmatter_order domains/orchestration/agents/sdd-implement.md '"*": allow' 'work-unit-commits: deny'
assert_contains domains/orchestration/agents/sdd-verify.md 'immutable plan path and recorded SHA-256 when present'
assert_contains domains/orchestration/agents/sdd-verify.md 'every source scenario with its id and `WHEN`/`THEN`'
assert_contains domains/orchestration/agents/sdd-verify.md 'the complete `Files:` scope, every source `Verify` item'
assert_contains domains/orchestration/agents/sdd-verify.md 'Omitted, duplicated, added, or changed scenarios or checks block verification.'
assert_contains domains/orchestration/agents/sdd-verify.md 'PASS scenarios=<passed>/<total> checks=<passed>/<total> evidence=<pointer>'
assert_contains domains/orchestration/agents/sdd-verify.md 'FAIL scenarios=<passed>/<total> checks=<passed>/<total> evidence=<pointer>'
assert_not_contains domains/orchestration/agents/sdd-verify.md 'PASS <passed>/<total>'
assert_contains domains/orchestration/agents/sdd-canonical-merge.md '.ai/orchestration/specs/'

review_coordinator=domains/review/agents/review-coordinator.md
assert_contains "$review_coordinator" 'For `judgment`, load `judgment-day`.'
assert_not_contains "$review_coordinator" 'active SDD root'
assert_not_contains "$review_coordinator" 'judgment.md'
assert_not_contains "$review_coordinator" 'SDD reconciliation'
assert_not_contains "$review_coordinator" 'SDD primary'

assert_contains README.md 'Install `orchestration` and `review` independently.'
assert_contains domains/orchestration/README.md 'Review is independent.'
assert_not_contains domains/orchestration/README.md 'Judgment'
assert_not_contains domains/orchestration/README.md 'work-unit-commits'
assert_contains installers/opencode.sh 'install --domain orchestration --target /tmp/opencode-test --dry-run'
assert_contains installers/opencode.sh 'install --domain review --target /tmp/opencode-review --dry-run'

global_rules=global/AGENTS.md
assert_contains "$global_rules" '`## OpenCode Skills`, `## Agent Skills`, and `## Claude Skills`'
assert_contains "$global_rules" '`Description | Skill | Location` columns'
assert_contains "$global_rules" 'Match assigned work against `Description` and select only names from `Skill`.'
assert_contains "$global_rules" 'Treat `Location` as diagnostic information only'
assert_contains "$global_rules" 'registry is absent, malformed, has no matching description, or a selected skill is no longer available'
assert_contains "$global_rules" 'Do not accept the legacy `## Skills` section or `Trigger` column.'
assert_not_contains "$global_rules" 'match a trigger in its `## Skills` table'
assert_not_contains "$global_rules" 'at the listed path for the full contract'
assert_not_contains "$global_rules" '| Trigger | Skill |'

cold_verification=domains/orchestration/skills/sdd-cold-verification/SKILL.md
assert_frontmatter_contains "$cold_verification" 'version: "2.0.0"'
assert_contains "$cold_verification" 'Exact `.ai/orchestration/runs/<slug>/` root and its `run.md`.'
assert_contains "$cold_verification" 'Exact immutable plan path and the SHA-256 recorded in `run.md` when it references one.'
assert_contains "$cold_verification" 'Complete source scenario list, including every id and `WHEN`/`THEN` pair.'
assert_contains "$cold_verification" 'Complete source `Files:` scope.'
assert_contains "$cold_verification" 'Complete source `Verify` checklist.'
assert_contains "$cold_verification" '`working-tree` or an explicit diff range as the baseline.'
assert_contains "$cold_verification" 'Every source scenario and `Verify` item must appear exactly once, with no additions.'
assert_contains "$cold_verification" 'Any omitted, duplicated, added, or changed item is `BLOCK sdd/verify <reason>`.'
assert_contains "$cold_verification" 'Run every applicable read-only `Verify` item fresh.'
assert_contains "$cold_verification" 'Count every scenario and every `Verify` item separately.'
assert_contains "$cold_verification" 'PASS scenarios=<passed>/<total> checks=<passed>/<total> evidence=<pointer>'
assert_contains "$cold_verification" 'FAIL scenarios=<passed>/<total> checks=<passed>/<total> evidence=<pointer>'
assert_not_contains "$cold_verification" 'Judgment'
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
assert_absent docs/architecture/adr/0001-adaptive-planning-and-orchestration.md
assert_contains domains/orchestration/README.md '```mermaid'
assert_contains domains/orchestration/README.md 'change[Clear change] --> direct[Direct execution]'
assert_contains domains/orchestration/README.md 'route -->|No| direct'
assert_contains domains/orchestration/README.md 'route -->|Yes| confirm[Confirm SDD]'
assert_contains domains/orchestration/README.md 'resume[Resume exact run] --> run'
assert_contains domains/orchestration/README.md 'direct --> verify[Fresh verification]'
assert_contains domains/orchestration/README.md 'cold --> archive[Archive run]'

flow_runner=scripts/test-orchestration-flows.sh
assert_contains "$flow_runner" 'install_current_profile'
assert_contains "$flow_runner" 'BigDecimal orderSubtotal = order.subtotal();'
assert_contains "$flow_runner" 'select(.part?.tool == "question")'
assert_not_contains "$flow_runner" 'no Judgment'
paid_flow=scripts/test-multi-primary-e2e.sh
assert_contains "$paid_flow" '"$PROFILE" install --project-root "$PROJECT" --no-install-brew-tools'
assert_contains "$paid_flow" 'TIMEOUT_SECONDS="${MULTI_PRIMARY_E2E_TIMEOUT:-2400}"'
assert_contains "$paid_flow" 'if ((SECONDS - started >= TIMEOUT_SECONDS)); then'
assert_contains "$paid_flow" 'kill -TERM "$RUN_PID"'
assert_contains "$paid_flow" 'kill -KILL "$RUN_PID"'
assert_contains "$paid_flow" 'run_model_call deep-planner "$SCRATCH/plan.events.jsonl"'
assert_contains "$paid_flow" 'run_model_call orchestraitor "$SCRATCH/execute.events.jsonl"'
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
