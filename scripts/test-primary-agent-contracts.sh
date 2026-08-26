#!/usr/bin/env bash
# Deterministic contracts for direct primary routing, questions, and worker boundaries.

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
  grep -Fq -- "$text" "$file" || fail "$file" "missing contract text: $text"
}

assert_not_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  ! grep -Fq -- "$text" "$file" || fail "$file" "retains forbidden contract text: $text"
}

assert_regex() {
  local file="$1" pattern="$2"
  CHECKS=$((CHECKS + 1))
  grep -Eq "$pattern" "$file" || fail "$file" "missing contract pattern: $pattern"
}

assert_frontmatter_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  frontmatter "$file" | grep -Fq -- "$text" || fail "$file" "frontmatter missing: $text"
}

assert_frontmatter_not_contains() {
  local file="$1" text="$2"
  CHECKS=$((CHECKS + 1))
  ! frontmatter "$file" | grep -Fq -- "$text" || fail "$file" "frontmatter retains: $text"
}

assert_absent() {
  local file="$1"
  CHECKS=$((CHECKS + 1))
  [ ! -e "$file" ] && [ ! -L "$file" ] || fail "$file" 'retired component still exists'
}

assert_primary_contract() {
  local file="$1"
  assert_frontmatter_contains "$file" 'mode: primary'
  assert_frontmatter_contains "$file" 'question: allow'
  assert_not_contains "$file" 'Never ask directly'
  assert_not_contains "$file" 'return `ASK'
  assert_not_contains "$file" 'sdlc-coordinator-receipt/v1'
}

assert_absent domains/sdlc
CHECKS=$((CHECKS + 1))
[ -z "$(find domains -path '*/agents/sdlc-orchestrator.md' -print -quit)" ] ||
  fail sdlc-orchestrator.md 'retired router remains in a domain'

profile_installer=scripts/multi-primary-profile.sh
assert_contains "$profile_installer" '--install-brew-tools|--no-install-brew-tools'
# shellcheck disable=SC2016 # Literal shell source is part of the contract.
assert_contains "$profile_installer" 'installer_args+=("$BREW_TOOLS_OPTION")'
assert_contains "$profile_installer" "MANAGED_SUBAGENT_DEPTH='1'"
assert_not_contains "$profile_installer" 'MANAGED_DEFAULT_AGENT'

review=domains/review/agents/review-coordinator.md
assert_primary_contract "$review"
for phase_agent in jd-judge-a jd-judge-b jd-solo jd-fix; do
  assert_frontmatter_contains "$review" "$phase_agent: allow"
  assert_frontmatter_contains "domains/review/agents/$phase_agent.md" 'mode: subagent'
  assert_frontmatter_contains "domains/review/agents/$phase_agent.md" 'question: deny'
done
assert_contains "$review" 'judgment'
assert_contains "$review" 'defend'

architect=domains/architecture/agents/architect.md
assert_primary_contract "$architect"
assert_regex "$architect" '^    service-boundary-analysis: allow$'
assert_frontmatter_contains "$architect" 'dependency-security-audit: allow'
assert_frontmatter_contains "$architect" '"govulncheck*": allow'
assert_regex "$architect" '^  task: deny$'
assert_frontmatter_not_contains "$architect" 'skill: allow'
assert_frontmatter_contains "$architect" '"*": deny'
for operation in map review ideate boundary; do
  assert_contains "$architect" "$operation"
done
assert_contains "$architect" 'change.md'
assert_contains "$architect" 'exact target-specific path'
assert_contains "$architect" 'report exists'
assert_not_contains "$architect" "$RUNTIME_ARGUMENTS"

planner=domains/plan/agents/deep-planner.md
assert_primary_contract "$planner"
assert_frontmatter_contains "$planner" 'refactor-analyzer: allow'
assert_frontmatter_not_contains "$planner" 'skill: allow'
assert_frontmatter_contains "$planner" '"*": deny'
assert_contains "$planner" 'operation=deep-plan intent=auto|discovery'
assert_contains "$planner" 'operation=refactor intent=auto|hardening'
assert_contains "$planner" 'When selected directly without an operation pair'
assert_contains "$planner" 'for normal delivery, decision, or roadmap planning'
assert_contains "$planner" 'for an explicitly exploratory request'
assert_contains "$planner" 'for an explicitly behavior-preserving refactor'
assert_contains "$planner" 'for safety-net-only preparation'
assert_not_contains "$planner" 'Invalid or missing pairs stop'
assert_contains "$planner" 'change.md'
assert_regex "$planner" '[Nn]ever combine hardening and restructuring'
assert_not_contains "$planner" "$RUNTIME_ARGUMENTS"
CHECKS=$((CHECKS + 1))
[ ! -e domains/refactor ] || fail domains/refactor 'retired planning domain still exists'

assert_frontmatter_contains domains/plan/agents/refactor-analyzer.md '"*": deny'
for retired in \
  domains/architecture/agents/arch-analyzer.md \
  domains/architecture/agents/boundary-inspector.md \
  domains/architecture/commands/arch-audit.md \
  domains/architecture/commands/arch-prd.md; do
  assert_absent "$retired"
done

assert_contains domains/plan/commands/deep-plan.md 'operation=deep-plan intent=auto'
assert_contains domains/plan/commands/wayfinder.md 'operation=deep-plan intent=discovery'
assert_contains domains/plan/commands/refactor-plan.md 'operation=refactor intent=auto'
assert_contains domains/plan/commands/harden-plan.md 'operation=refactor intent=hardening'
assert_frontmatter_contains "$architect" '".ai/architect/**": allow'
assert_contains "$architect" 'inventory manifests without vulnerability or EOL verdicts'
# shellcheck disable=SC2016 # Literal Markdown backticks are part of the contract.
assert_contains "$architect" 'load `service-boundary-analysis`'

assert_frontmatter_contains domains/architecture/skills/architecture-state/SKILL.md 'version: "2.0.1"'
# shellcheck disable=SC2016 # Literal Markdown backticks are part of the contract.
assert_contains domains/architecture/skills/architecture-state/SKILL.md '`repo-issues` owns judgments and fitness functions'
assert_frontmatter_contains domains/architecture/skills/repo-issues/SKILL.md 'version: "2.1.0"'
assert_contains domains/architecture/skills/repo-issues/SKILL.md 'references/fitness-functions.md'
assert_contains domains/architecture/skills/repo-issues/references/fitness-functions.md '## Go'
assert_contains domains/architecture/skills/repo-issues/references/fitness-functions.md 'go list ./...'
assert_contains domains/architecture/skills/repo-issues/references/fitness-functions.md 'go-arch-lint check'
assert_frontmatter_contains domains/architecture/skills/architecture-map/SKILL.md 'version: "2.0.1"'
# shellcheck disable=SC2016 # Literal Markdown backticks are part of the contract.
assert_contains domains/architecture/skills/architecture-map/SKILL.md 'Default: one `index.md`'
# shellcheck disable=SC2016 # Literal Markdown backticks are part of the contract.
assert_contains domains/architecture/skills/architecture-map/SKILL.md 'Write to `docs/architecture/` when `docs/` exists'
# shellcheck disable=SC2016 # Literal Markdown backticks are part of the contract.
assert_contains domains/architecture/skills/architecture-map/SKILL.md 'Otherwise use existing `doc/architecture/`'
assert_frontmatter_contains domains/architecture/skills/dependency-security-audit/SKILL.md 'version: "2.1.2"'
# shellcheck disable=SC2016 # Literal Markdown backticks are part of the contract.
assert_contains domains/architecture/skills/dependency-security-audit/SKILL.md '`method: inventory-only`'
dependency_audit_reference=domains/architecture/skills/dependency-security-audit/references/ecosystem-commands.md
assert_contains "$dependency_audit_reference" 'osv-scanner scan source -r .'
assert_not_contains "$dependency_audit_reference" 'osv-scanner .'
assert_contains "$dependency_audit_reference" '| Go |'
assert_contains "$dependency_audit_reference" 'govulncheck -json ./...'
# shellcheck disable=SC2016 # Literal Markdown backticks are part of the contract.
assert_contains "$dependency_audit_reference" '`go.sum` is not a lockfile'
assert_contains "$dependency_audit_reference" 'minimum Go version'
assert_frontmatter_contains domains/architecture/skills/service-boundary-analysis/SKILL.md 'version: "2.0.0"'
assert_contains domains/architecture/skills/service-boundary-analysis/SKILL.md '| Category | Mechanism | Source/peer | Evidence | Confidence | Notes |'
for retired_skill in \
  architecture-impact-review cognitive-doc-design cohesion-coupling dependency-inversion \
  domain-modeling god-object-detection input-validation-preconditions java-secure-coding \
  logging-observability native-question-ux prd prd-light tooling-audit tooling-compatibility-matrix; do
  assert_absent "domains/architecture/skills/$retired_skill"
done

assert_primary_contract domains/sdd/agents/orchestraitor.md
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains domains/sdd/agents/orchestraitor.md 'direct the user to `/judgment`'
assert_contains domains/sdd/agents/orchestraitor.md 'Before any operation accepts'
assert_contains domains/sdd/agents/orchestraitor.md 'before writing or updating the change and state'
assert_contains domains/sdd/agents/orchestraitor.md 'ask the user to install'
assert_contains domains/sdd/agents/orchestraitor.md 'Never enter the judgment phase with an unavailable handoff'
assert_contains domains/sdd/README.md 'Standalone'
assert_contains domains/sdd/README.md 'Light and full Judgment require an explicit'
assert_contains "$review" 'even for a clean verdict'
assert_contains installers/opencode.sh 'install --domain sdd,review,common'

lite=domains/sdd-lite/agents/orchestralite.md
assert_primary_contract "$lite"
assert_frontmatter_contains "$lite" 'lite-verify: allow'
for skill in behavior-characterization code-conventions cognitive-doc-design java-testing legacy-code-safety sdd-execution-skills systematic-debugging; do
  assert_frontmatter_contains "$lite" "$skill: allow"
done
assert_contains "$lite" 'sdd-lite'
assert_contains "$lite" 'change.md'
assert_contains "$lite" 'lite-verify'
assert_contains "$lite" 'Judgment: none | Delivery: none'
assert_contains "$lite" '<capability>/<requirement>'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$lite" 'Load `sdd-execution-skills`'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains "$lite" 'code/test work requires `code-conventions`'
assert_not_contains "$lite" "$RUNTIME_ARGUMENTS"

assert_frontmatter_contains domains/sdd-lite/agents/lite-verify.md 'mode: subagent'
assert_frontmatter_contains domains/sdd-lite/agents/lite-verify.md 'question: deny'
assert_frontmatter_contains domains/sdd-lite/agents/lite-verify.md 'sdd-cold-verification: allow'
# shellcheck disable=SC2016 # Markdown backticks are literal contract text.
assert_contains domains/sdd-lite/agents/lite-verify.md 'Load `sdd-cold-verification`'
assert_contains domains/sdd-lite/agents/lite-verify.md 'PASS <passed>/<total> evidence=<path:line or one-line test>'
assert_contains domains/sdd/agents/sdd-implement.md 'OK wave=<id> files=<csv> check=<one-line result>'
assert_frontmatter_contains domains/sdd/agents/sdd-canonical-merge.md 'mode: subagent'
assert_frontmatter_contains domains/sdd/agents/sdd-canonical-merge.md 'question: deny'
assert_contains domains/sdd/agents/sdd-canonical-merge.md 'OK merge count=<n> stale=0'
assert_contains domains/sdd/agents/sdd-canonical-merge.md 'Never block an ADD only because the canonical root is absent'
assert_contains domains/sdd/agents/sdd-canonical-merge.md 'capability-qualified identifier'
assert_contains domains/sdd/agents/sdd-verify.md 'PASS <passed>/<total> evidence=<path:line or one-line test>'

# Exactly five question owners and five primaries in the multi-primary profile.
profile_primary_count=0
profile_question_owner_count=0
for domain in plan sdd architecture sdd-lite review common; do
  for file in "domains/$domain/agents/"*.md; do
    [ -f "$file" ] || continue
    CHECKS=$((CHECKS + 1))
    frontmatter "$file" | grep -Eq '^  question: (allow|deny)$' ||
      fail "$file" 'profile agent must declare question permission explicitly'
    if frontmatter "$file" | grep -Eq '^mode: primary$'; then
      profile_primary_count=$((profile_primary_count + 1))
    fi
    if frontmatter "$file" | grep -Eq '^  question: allow$'; then
      profile_question_owner_count=$((profile_question_owner_count + 1))
    fi
  done
done
CHECKS=$((CHECKS + 1))
[ "$profile_primary_count" -eq 5 ] || fail domains "expected five profile primaries, found $profile_primary_count"
CHECKS=$((CHECKS + 1))
[ "$profile_question_owner_count" -eq 5 ] || fail domains "expected five question owners, found $profile_question_owner_count"

# No subagent may delegate again; the profile has one delegation level.
for file in domains/*/agents/*.md; do
  frontmatter "$file" | grep -Eq '^mode: subagent$' || continue
  CHECKS=$((CHECKS + 1))
  ! frontmatter "$file" | awk '
    /^  task:/ { task = 1; next }
    task && /^  [^ ]/ { task = 0 }
    task && /: allow$/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' || fail "$file" 'subagent retains a task allow and can delegate another level'
done

# Every workflow command selects its owning primary and stays in primary context.
for command in arch-ideate arch-map arch-review boundary-inspector; do
  file="domains/architecture/commands/$command.md"
  assert_frontmatter_contains "$file" 'agent: architect'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
done
for command in deep-plan harden-plan refactor-plan wayfinder; do
  file="domains/plan/commands/$command.md"
  assert_frontmatter_contains "$file" 'agent: deep-planner'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
done
for command in defend judgment; do
  file="domains/review/commands/$command.md"
  assert_frontmatter_contains "$file" 'agent: review-coordinator'
  assert_frontmatter_contains "$file" 'subtask: false'
  assert_contains "$file" "$RUNTIME_ARGUMENTS"
done
assert_frontmatter_contains domains/sdd/commands/sdd.md 'agent: orchestraitor'
assert_frontmatter_contains domains/sdd/commands/sdd.md 'subtask: false'
assert_contains domains/sdd/commands/sdd.md "$RUNTIME_ARGUMENTS"
assert_frontmatter_contains domains/sdd-lite/commands/sdd-lite.md 'agent: orchestralite'
assert_frontmatter_contains domains/sdd-lite/commands/sdd-lite.md 'subtask: false'
assert_contains domains/sdd-lite/commands/sdd-lite.md "$RUNTIME_ARGUMENTS"

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d direct-primary contract violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d direct-primary contract checks OK.\n' "$CHECKS"
