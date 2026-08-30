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

assert_frontmatter_not_contains() {
  CHECKS=$((CHECKS + 1))
  ! frontmatter "$1" | grep -Fq -- "$2" || fail "$1" "frontmatter retains: $2"
}

assert_absent() {
  CHECKS=$((CHECKS + 1))
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "$1" 'retired component remains'
}

assert_primary() {
  assert_frontmatter_contains "$1" 'mode: primary'
  assert_frontmatter_contains "$1" 'question: allow'
}

permission_rule_block() {
  local file="$1" rule="$2"
  frontmatter "$file" | awk -v header="  $rule:" '
    $0 == header { inside = 1; next }
    inside && /^  [^ ]/ { exit }
    inside { print }
  '
}

assert_permission_rule_block() {
  local file="$1" rule="$2" expected="$3" actual
  CHECKS=$((CHECKS + 1))
  actual="$(permission_rule_block "$file" "$rule")"
  [ "$actual" = "$expected" ] || fail "$file" "unexpected permission.$rule rules"
}

permission_keys() {
  frontmatter "$1" | awk '
    /^permission:/ { inside = 1; next }
    inside && /^[^ ]/ { exit }
    inside && /^  [^ ]/ {
      key = $0
      sub(/^  /, "", key)
      sub(/:.*/, "", key)
      print key
    }
  '
}

planner=domains/plan/agents/deep-planner.md
architect=domains/architecture/agents/architect.md
orchestraitor=domains/orchestration/agents/orchestraitor.md
review=domains/review/agents/review-coordinator.md
planner_edit_scope='    "*": deny
    ".ai/**": allow'
planner_bash_scope='    "*": deny
    "mkdir -p .ai/deep-planner/discoveries": allow
    "mkdir -p .ai/deep-planner/plans": allow
    "git log*": allow
    "git blame*": allow
    "git shortlog*": allow'

for primary in "$planner" "$architect" "$orchestraitor" "$review"; do
  assert_primary "$primary"
done

assert_contains "$planner" 'Wayfinder discovers. Deep Plan plans.'
assert_contains "$planner" '`Create a plan`'
assert_contains "$planner" '`Explore an idea`'
assert_contains "$planner" 'normal chat, one at a time'
assert_permission_rule_block "$planner" edit "$planner_edit_scope"
assert_permission_rule_block "$planner" bash "$planner_bash_scope"
assert_frontmatter_not_contains "$planner" '  write:'
assert_contains "$planner" 'Before writing a Wayfinder or Deep Plan artifact, create its parent with exactly one of these commands: `mkdir -p .ai/deep-planner/discoveries` or `mkdir -p .ai/deep-planner/plans`.'
assert_contains "$planner" 'Do not alter or combine them.'
assert_contains "$planner" 'Choose only the Wayfinder and Deep Plan paths below; use any other `.ai/**` path only when the user provides that exact path explicitly and its parent already exists.'
assert_contains "$planner" 'one `.ai/deep-planner/discoveries/<slug>.md`'
assert_contains "$planner" 'one `.ai/deep-planner/plans/<slug>.md`'
assert_contains "$orchestraitor" 'A change request uses direct execution.'
assert_contains "$orchestraitor" '`Make a change`, `Execute a plan`, or `Resume work`'
assert_contains "$orchestraitor" 'Do not create `.ai/` state'
assert_contains "$orchestraitor" 'Review is a separate primary'
assert_contains "$review" 'For `judgment`, load `judgment-day`.'
assert_not_contains "$review" 'SDD reconciliation'
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

mentor=domains/learning/agents/mentor.md
recorder=domains/learning/agents/learning-recorder.md
spaced_recall=domains/learning/skills/spaced-recall/SKILL.md
learning_scope='    "*": deny
    ".ai/learning/**": allow
    "**/.ai/learning/**": allow'

assert_primary "$mentor"
assert_permission_rule_block "$mentor" edit "$learning_scope"
assert_permission_rule_block "$mentor" write "$learning_scope"
assert_permission_rule_block "$mentor" task '    "*": deny
    learning-recorder: allow'
assert_frontmatter_not_contains "$mentor" 'general: allow'
assert_contains "$mentor" 'Before any create/edit/append, send `learning-recorder` only exact target paths, mutations, complete content, and anchors.'
assert_contains "$mentor" 'After each grade, immediately launch a fresh `learning-recorder` with `background: true`'
assert_contains "$mentor" 'omit `task_id`—never pass or reuse one.'
assert_contains "$mentor" 'its description must equal `Persist review grade topic=<topic-slug> card=<C-NNNN> review=<ordinal>`.'
assert_contains "$mentor" 'Track the returned runtime task ID as pending with its description, targets, and intended mutation.'
assert_contains "$mentor" 'It is only a notification-correlation handle, never a retry/resume handle.'
assert_contains "$mentor" 'first get the learner'
assert_contains "$mentor" 'then launch one compound handoff with exact anchored queue and path-log mutations, never separate handoffs.'
assert_contains "$mentor" 'After a non-final launch returns its ID, ask the next cue immediately; do not wait for its receipt.'
assert_contains "$mentor" '`OK files=<csv>` settles only that ID: no verification reread; no repeating, answering, or advancing the open cue.'
assert_contains "$mentor" 'On the first `BLOCK`, `FAIL`, timeout, cancellation, or runtime task error, never retry, resume, or delegate again.'
assert_contains "$mentor" 'Freshly re-read every affected target, reconcile partial changes, directly apply only that card'
assert_contains "$mentor" 'intended mutation under `.ai/learning/**`, report the fallback, then settle only that ID.'
assert_contains "$mentor" 'Unrelated/out-of-order notifications never settle another task, change the card index, repeat a cue, or advance an open question.'
assert_contains "$mentor" 'Only learner input advances review.'
assert_contains "$mentor" 'Unsupported background mode or a rejected launch is the first task error: use scoped direct fallback, then ask the next cue.'
assert_contains "$mentor" 'Never substitute a foreground recorder.'
assert_contains "$mentor" 'pending IDs permit only “persistence is finishing.”'
assert_contains "$mentor" 'Withhold the persisted-artifact summary and next-due report until every ID returns `OK` or completes direct fallback.'
assert_contains "$mentor" 'Rely only on automatic notifications; never sleep, poll, request status, or fabricate completion.'

assert_contains "$spaced_recall" 'launch one fresh `learning-recorder` with `background: true`, unique topic/card/review-ordinal description, and no `task_id`'
assert_contains "$spaced_recall" 'immediately ask the next cue without waiting for receipt.'
assert_contains "$spaced_recall" '`OK` settles only its ID, with no reread, repeated cue, or open-cue advance.'
assert_contains "$spaced_recall" '`BLOCK`, `FAIL`, error, cancellation, timeout, or unsupported/rejected background launch triggers Mentor'
assert_contains "$spaced_recall" 'fresh-read, card-scoped direct fallback—never retry, resume, poll, or substitute foreground recording.'
assert_contains "$spaced_recall" 'Notifications alone settle tasks and never alter review progression.'
assert_contains "$spaced_recall" 'withhold persisted artifacts/next due date until all IDs settle by `OK` or fallback'
assert_contains "$spaced_recall" 'meanwhile report only that persistence is finishing.'
assert_contains "$spaced_recall" 'Never sleep, request status, or fabricate completion.'

assert_frontmatter_contains "$recorder" 'mode: subagent'
assert_frontmatter_contains "$recorder" 'temperature: 0.1'
assert_frontmatter_not_contains "$recorder" 'model:'
assert_frontmatter_contains "$recorder" '  "*": deny'
assert_permission_rule_block "$recorder" read "$learning_scope"
assert_permission_rule_block "$recorder" edit "$learning_scope"
assert_permission_rule_block "$recorder" write "$learning_scope"
CHECKS=$((CHECKS + 1))
recorder_permission_keys="$(permission_keys "$recorder")"
[ "$recorder_permission_keys" = '"*"
read
edit
write
external_directory' ] ||
  fail "$recorder" 'effective tool permissions are not limited to read, edit, and write'
assert_contains "$recorder" 'exact target paths, mutations, complete content, and anchors'
assert_contains "$recorder" 'Never calculate dates, cards, grades, progress, or content'
assert_contains "$recorder" 'Never infer, explore, ask, explain, run commands, load skills, or delegate.'
assert_contains "$recorder" 'Existing: only exact anchored `edit`; the anchor must match exactly and unambiguously.'
assert_contains "$recorder" 'Never `write` an existing file.'
assert_contains "$recorder" 'Absent: `write` only supplied complete new-file content; otherwise `BLOCK` before any change.'
assert_contains "$recorder" 'Compound: apply only listed anchored operations.'
assert_contains "$recorder" 'Never broaden anchors or replace unrelated rows when another task may touch the file.'
assert_contains "$recorder" 'Return exactly one line:'
assert_contains "$recorder" 'OK files=<csv>'
assert_contains "$recorder" 'BLOCK reason=<short>'
assert_contains "$recorder" 'FAIL changed=<csv> reason=<short>'

assert_contains domains/learning/README.md '| Agent (subagent) | `learning-recorder` | Persists exact learning-state mutations |'
assert_contains docs/agent-models.md 'Assign `learning-recorder` individually with `/models-profiles`'
assert_frontmatter_contains domains/learning/commands/english.md 'agent: english-tutor'
assert_frontmatter_contains domains/learning/commands/english.md 'subtask: true'

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
assert_contains domains/meta/README.md '`opencode-skill-registry` is the sole owner of `.ai/atl/skill-registry.md`.'
assert_contains domains/meta/README.md 'refreshes when OpenCode restarts'
assert_not_contains domains/meta/README.md '| Skill | `skill-registry` |'
assert_absent domains/meta/skills/skill-registry

if [ "$FAILS" -gt 0 ]; then
  printf 'FAIL: %d primary contract violation(s) across %d checks.\n' "$FAILS" "$CHECKS" >&2
  exit 1
fi

printf 'PASS: %d primary agent contracts OK.\n' "$CHECKS"
