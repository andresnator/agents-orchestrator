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
summarizer=domains/learning/agents/learning-summarizer.md
learn_command=domains/learning/commands/learn.md
learning_loop=domains/learning/skills/learning-loop/SKILL.md
learning_session=domains/learning/skills/learning-session/SKILL.md
cornell_notes=domains/learning/skills/cornell-notes/SKILL.md
standalone_cornell_template=domains/learning/skills/cornell-notes/assets/standalone-summary-template.md
spaced_recall=domains/learning/skills/spaced-recall/SKILL.md
learning_scope='    "*": deny
    ".ai/learning/**": allow
    "**/.ai/learning/**": allow'
summary_scope='    "*": deny
    ".ai/learning/summaries/**": allow
    "**/.ai/learning/summaries/**": allow'
summary_bash_scope='    "*": deny
    "date +%Y-%m-%d-%H%M%S": allow
    "mkdir -p .ai/learning/summaries": allow'
summary_skill_scope='    "*": deny
    cornell-notes: allow
    cognitive-doc-design: allow'

assert_primary "$mentor"
assert_permission_rule_block "$mentor" edit "$learning_scope"
assert_permission_rule_block "$mentor" write "$learning_scope"
assert_permission_rule_block "$mentor" task '    "*": deny
    learning-recorder: allow
    learning-summarizer: allow'
assert_frontmatter_not_contains "$mentor" 'general: allow'
assert_contains "$mentor" 'Classify the raw request before loading any skill, calling any tool, or reading `.ai/learning/`.'
assert_contains "$mentor" 'Load exactly one initial methodology skill:'
assert_contains "$mentor" '`learning-session` for a request clearly answerable in the current interaction with no requested follow-up.'
assert_contains "$mentor" '`learning-loop` for a route, progress, several sessions, review, repetition, ongoing follow-up, empty input, or any existing durable mode.'
assert_contains "$mentor" 'Explicit `/learn session <request>` forces `learning-session`'
assert_contains "$mentor" 'Explicit `/learn path <topic>` forces `learning-loop`'
assert_contains "$mentor" 'Preserve `review`, `quiz`, `map`, `teach`, `vocab`, `drill`, and `status` as durable modes.'
assert_contains "$mentor" 'A bare or otherwise ambiguous topic such as `/learn pizza` requires one closed `question` choice between a one-off session and a durable path.'
assert_contains "$mentor" 'Render both user-facing option labels in the conversation language while keeping the internal route values `learning-session` and `learning-loop`.'
assert_contains "$mentor" 'Ask it before any skill, date, due-check, list, grep, glob, read, or other state discovery'
assert_contains "$mentor" 'Run this protocol only after durable classification and loading `learning-loop`; never run any step for `learning-session`.'
assert_contains "$mentor" 'The exact `summaries` slug is reserved infrastructure: never treat it as a topic or generate it for one.'
assert_contains "$mentor" 'Treat a child directory as a durable topic only when it is not the exact reserved `summaries` directory and contains `mission.md`'
assert_contains "$mentor" 'never read topic files from `summaries/`.'
assert_contains "$mentor" 'Before any durable create/edit/append, send `learning-recorder` only exact target paths, mutations, complete content, and anchors.'
assert_contains "$mentor" 'explicit positive request to save authorizes a summary.'
assert_contains "$mentor" 'Launch one fresh `learning-summarizer` with `background: true`; omit `task_id`—never pass or reuse one.'
assert_contains "$mentor" 'Pass only the pertinent segment of the one-off session, its conversation language, and sources actually used.'
assert_contains "$mentor" 'After an accepted launch, continue responding to the learner immediately; do not wait for completion.'
assert_contains "$mentor" '`OK summary=<path>`, `BLOCK`, and `FAIL` are internal receipts and remain unchanged.'
assert_contains "$mentor" 'Localize only the queued user-facing notice described below.'
assert_contains "$mentor" 'Correlate automatic notifications only by the pending summary task ID.'
assert_contains "$mentor" 'A valid `OK summary=<path>` must name `.ai/learning/summaries/<YYYY-MM-DD>-<HHMMSS>-<slug>.md`'
assert_contains "$mentor" 'queues exactly one brief parenthetical success notice in the pending request'
assert_contains "$mentor" 'queues exactly one brief parenthetical failure notice in the pending request'
assert_contains "$mentor" 'Never retry, resume, poll, delegate again, or fall back to foreground or direct writing.'
assert_contains "$mentor" 'Automatic notifications never produce a standalone response, interrupt teaching, answer or advance an open question, or alter durable learning.'
assert_contains "$mentor" 'Append one queued localized result parenthesis to the next normal response and no other persistence commentary.'
assert_not_contains "$mentor" 'Sesión puntual'
assert_not_contains "$mentor" 'Ruta durable'
assert_not_contains "$mentor" 'Resumen guardado'
assert_not_contains "$mentor" 'No se pudo guardar'
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

assert_contains "$learn_command" 'Classify the raw request before loading any skill, calling any tool, or reading `.ai/learning/`.'
assert_contains "$learn_command" '`session <request>` | One-off session'
assert_contains "$learn_command" '`path <topic>` | Durable path'
assert_contains "$learn_command" 'ask one closed choice whose two user-facing labels follow the conversation language.'
assert_contains "$learn_command" 'Map the one-off selection internally to `learning-session` and the durable selection to `learning-loop`'
assert_not_contains "$learn_command" 'Sesión puntual'
assert_not_contains "$learn_command" 'Ruta durable'
assert_contains "$learn_command" 'One-off sessions never run a due-check, inspect `.ai/learning/`'
assert_contains "$learn_command" 'Run the `spaced-recall` due-check first in every durable mode'
assert_contains "$learn_command" '`summaries` is a reserved infrastructure slug, never a durable topic.'

assert_frontmatter_contains "$learning_session" '  version: "1.0.0"'
assert_contains "$learning_session" 'Lead with the direct answer in the user'
assert_contains "$learning_session" 'Ask no more than two questions before stopping for the learner'
assert_contains "$learning_session" 'Do not run a due-check or inspect `.ai/learning/`.'
assert_contains "$learning_session" 'Do not persist automatically or merely because the session ends.'
assert_contains "$learning_session" 'explicit positive request to save may start Mentor'
assert_frontmatter_contains "$learning_loop" '  version: "2.1.1"'
assert_contains "$learning_loop" 'Classify from the raw request before loading this skill or reading `.ai/learning/`'
assert_contains "$learning_loop" 'Resolve a bare or ambiguous topic through a closed choice whose two user-facing labels follow the conversation language.'
assert_contains "$learning_loop" 'Map the one-off selection internally to `learning-session` and the durable selection to `learning-loop` before loading either skill.'
assert_not_contains "$learning_loop" 'Sesión puntual'
assert_not_contains "$learning_loop" 'Ruta durable'
assert_contains "$learning_loop" '`.ai/learning/summaries/` is reserved standalone-summary infrastructure, never a durable topic.'
assert_contains "$learning_loop" 'The exact `summaries` topic slug is reserved.'
assert_contains "$learning_loop" 'resume only if `<topic-slug>/mission.md` exists and the slug is not `summaries`'

assert_frontmatter_contains "$summarizer" 'mode: subagent'
assert_frontmatter_contains "$summarizer" 'temperature: 0.1'
assert_frontmatter_not_contains "$summarizer" 'model:'
assert_frontmatter_contains "$summarizer" '  "*": deny'
assert_frontmatter_not_contains "$summarizer" '  write:'
assert_frontmatter_contains "$summarizer" '  question: deny'
assert_frontmatter_contains "$summarizer" '  task: deny'
assert_frontmatter_contains "$summarizer" '  webfetch: deny'
assert_frontmatter_contains "$summarizer" '  external_directory: deny'
assert_permission_rule_block "$summarizer" read "$summary_scope"
assert_permission_rule_block "$summarizer" edit "$summary_scope"
assert_permission_rule_block "$summarizer" bash "$summary_bash_scope"
assert_permission_rule_block "$summarizer" skill "$summary_skill_scope"
CHECKS=$((CHECKS + 1))
summarizer_permission_keys="$(permission_keys "$summarizer")"
[ "$summarizer_permission_keys" = '"*"
read
edit
bash
skill
question
task
webfetch
external_directory' ] ||
  fail "$summarizer" 'effective tool permissions exceed summary read/edit, exact bash, and two skills'
assert_contains "$summarizer" 'read only that exact target to confirm it does not exist.'
assert_contains "$summarizer" 'A collision is `BLOCK`; never choose an overwrite or edit an existing file.'
assert_contains "$summarizer" 'Write the complete standalone summary in one `write` operation.'
assert_contains "$summarizer" 'complete standalone-summary profile embedded in that skill.'
assert_contains "$summarizer" 'Do not resolve any separate template or asset.'
assert_contains "$summarizer" 'never infer route state, fetch sources, inspect other directories, ask questions, delegate, or access anything external.'
assert_contains "$summarizer" 'OK summary=<path>'
assert_contains "$summarizer" 'BLOCK reason=<short>'
assert_contains "$summarizer" 'FAIL file=<path|none> reason=<short>'

assert_frontmatter_contains "$cornell_notes" '  version: "1.1.1"'
assert_contains "$cornell_notes" '**Route lesson:** the 10% formal step of `learning-loop`'
assert_contains "$cornell_notes" 'The **Summary is the learner'
assert_contains "$cornell_notes" 'Every cue is handed to `spaced-recall` as a new card'
assert_contains "$cornell_notes" 'Notes are Markdown in English; never HTML.'
assert_contains "$cornell_notes" '**Standalone summary:** a saved one-off `learning-session`'
assert_contains "$cornell_notes" 'This profile is independent: never create or update a topic, mission, path, route note, cards, review queue, quiz bank, dashboard, or recall hand-off.'
assert_contains "$cornell_notes" 'Mermaid is optional and appears only when it materially reduces cognitive load.'
assert_contains "$cornell_notes" 'Do not schedule cues or request any route-state mutation.'
assert_contains "$cornell_notes" '### Complete Format'
assert_contains "$cornell_notes" '## {Localized synthesis heading}'
assert_contains "$cornell_notes" '## {Localized key questions heading}'
assert_contains "$cornell_notes" '## {Localized application or example heading}'
assert_contains "$cornell_notes" '## {Localized sources heading}'
assert_contains "$cornell_notes" '## {Optional localized map heading}'
assert_not_contains "$cornell_notes" 'assets/standalone-summary-template.md'
assert_absent "$standalone_cornell_template"
CHECKS=$((CHECKS + 1))
[ -L domains/learning/skills/cognitive-doc-design ] &&
  [ "$(readlink domains/learning/skills/cognitive-doc-design)" = '../../../skills/cognitive-doc-design' ] ||
  fail domains/learning/skills/cognitive-doc-design 'shared skill link is missing or incorrect'

assert_contains domains/learning/README.md '| Agent (subagent) | `learning-recorder` | Persists exact learning-state mutations |'
assert_contains domains/learning/README.md '| Agent (subagent) | `learning-summarizer` | Creates isolated one-off summaries |'
assert_contains domains/learning/README.md 'Topic discovery excludes that directory and resumes only directories containing `mission.md`'
assert_contains domains/learning/README.md 'Both choice labels and summary notices follow the conversation language'
assert_contains domains/learning/README.md 'Internal `OK summary=<path>`, `BLOCK`, and `FAIL` receipts remain unchanged.'
assert_not_contains domains/learning/README.md 'Sesión puntual'
assert_not_contains domains/learning/README.md 'Ruta durable'
assert_not_contains domains/learning/README.md 'Resumen guardado'
assert_not_contains domains/learning/README.md 'No se pudo guardar'
assert_contains docs/agent-models.md 'Assign `learning-recorder` individually with `/models-profiles`'
assert_contains docs/agent-models.md 'Assign `learning-summarizer` individually with `/models-profiles`'
assert_contains docs/learning-domain.md 'OpenCode gates its file tools through `permission.edit`, scoped only to `summaries/**`'
assert_contains docs/learning-domain.md 'using labels in the conversation language'
assert_contains docs/learning-domain.md 'The internal `OK summary=<path>`, `BLOCK`, and `FAIL` receipts are never translated.'
assert_not_contains docs/learning-domain.md 'Sesión puntual'
assert_not_contains docs/learning-domain.md 'Ruta durable'
assert_not_contains docs/learning-domain.md 'Resumen guardado'
assert_not_contains docs/learning-domain.md 'No se pudo guardar'
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
