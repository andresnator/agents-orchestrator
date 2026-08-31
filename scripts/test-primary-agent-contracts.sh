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

assert_exact_block() {
  local file="$1" expected="$2" content
  CHECKS=$((CHECKS + 1))
  content="$(<"$file")"
  [[ "$content" == *"$expected"* ]] || fail "$file" 'missing exact contract block'
}

assert_before() {
  local file="$1" first="$2" second="$3" first_line second_line
  CHECKS=$((CHECKS + 1))
  first_line="$(awk -v needle="$first" 'index($0, needle) { print NR; exit }' "$file")"
  second_line="$(awk -v needle="$second" 'index($0, needle) { print NR; exit }' "$file")"
  [ -n "$first_line" ] && [ -n "$second_line" ] && [ "$first_line" -lt "$second_line" ] ||
    fail "$file" "expected '$first' before '$second'"
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

assert_present() {
  CHECKS=$((CHECKS + 1))
  [ -f "$1" ] || fail "$1" "missing contract component: $2"
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
spaced_recall=domains/learning/skills/spaced-recall/SKILL.md
learning_scope='    "*": deny
    ".ai/learning/**": allow
    "**/.ai/learning/**": allow'
summary_scope='    "*": deny
    ".ai/learning/summaries/**": allow
    "**/.ai/learning/summaries/**": allow'
summarizer_skill_scope='    "*": deny
    learning-session: allow
    cornell-notes: allow
    cognitive-doc-design: allow'
summary_payload_contract='Before launching, build exactly this seven-field payload with separate lines and these names:
```yaml
operation: <create|update>
target: <exact .ai/learning/summaries/... path>
conversation_language: <language>
covered_material: <complete material covered>
sources_used: <sources|none>
explicit_corrections: <corrections|none>
request_ordinal: <ordinal>
```
All seven fields are mandatory. Do not launch until each field is present; use `none` explicitly only for `sources_used` or `explicit_corrections` when applicable.'
summary_task_call_contract='Invoke the `task` tool with exactly this call; replace placeholders, but do not add fields:
```yaml
subagent_type: learning-summarizer
description: Persist learning summary operation=<create|update> target=<path> request=<ordinal>
background: true
prompt: |-
  operation: <create|update>
  target: <exact .ai/learning/summaries/... path>
  conversation_language: <language>
  covered_material: <complete material covered>
  sources_used: <sources|none>
  explicit_corrections: <corrections|none>
  request_ordinal: <ordinal>
```'
learning_session_payload_contract='On an explicit save or update request, before any `task` call, build exactly this seven-line payload and no other fields:

```yaml
operation: <create|update>
target: <exact .ai/learning/summaries/... path>
conversation_language: <language>
covered_material: <complete material covered>
sources_used: <sources|none>
explicit_corrections: <corrections|none>
request_ordinal: <ordinal>
```'

assert_primary "$mentor"
assert_permission_rule_block "$mentor" edit "$learning_scope"
assert_permission_rule_block "$mentor" write "$learning_scope"
assert_permission_rule_block "$mentor" task '    "*": deny
    learning-recorder: allow
    learning-summarizer: allow'
assert_frontmatter_not_contains "$mentor" 'general: allow'

# Durable learning remains the owner of explicit modes and multi-session intent.
assert_contains "$learning_loop" 'Use when the user wants to learn a topic or skill over multiple sessions'
assert_contains "$learning_loop" 'Do not use for one-off explanations'
assert_contains "$mentor" 'Explicit modes, an existing topic selected for continuation, and clear path, progress, or continued-practice intent take precedence and route through `learning-loop`.'
assert_contains "$mentor" 'Keep review-card task IDs, targets, lifecycle handling, fallback, and completion gates independent from summary tasks.'

# Bounded direct messages and /learn prompts share one routing contract.
assert_contains "$mentor" 'Classify direct messages and raw `/learn` arguments with the same rules.'
assert_contains "$mentor" 'Classification is the first action. Until it resolves, do not load `learning-loop`, get today'
assert_contains "$mentor" 'Durable intent is clear only when the input contains an explicit path or route signal, a multi-session deadline or cadence, existing progress to continue, or continued practice.'
assert_contains "$mentor" 'A generic “quiero aprender X”, or an equivalent learning request without those durable signals, is ambiguous.'
assert_contains "$mentor" 'If bounded-session versus durable-path intent is ambiguous, ask one direct question: session or path; never infer silently.'
assert_contains "$mentor" 'A bounded session exits through `learning-session` before date lookup, state discovery, or the automatic due-check.'
assert_contains "$mentor" 'Do not create a mission, path, topic, exercise, capstone, note, or review card from a bounded session.'
assert_contains "$mentor" 'Run the existing due-check during a bounded session only when the learner explicitly asks to review.'
assert_contains "$learn_command" 'Classify the exact raw arguments with the same precedence and bounded-session rules as a direct `mentor` message.'
assert_contains "$learn_command" 'Explicit modes, existing topics selected for continuation, and clear durable-path intent still route through `learning-loop`.'
assert_contains "$learn_command" 'Before classification resolves, do not load `learning-loop`, look up today'
assert_contains "$learn_command" 'A generic “quiero aprender X”, or an equivalent request without an explicit path or route, multi-session deadline or cadence, existing progress, or continued-practice signal, is ambiguous.'
assert_before "$mentor" 'Classification is the first action.' 'For durable learning, optimize mission-grounded paths'
assert_before "$learn_command" 'Before classification resolves' 'Use this routing table after applying that common boundary:'

# A bare exact topic name gets one names-only lookup before generic ambiguity.
assert_contains "$mentor" 'Before applying the generic “quiero aprender X” ambiguity rule, use one narrow exception only when the direct message or raw `/learn` argument has the form of a bare topic selection: a slug or name, not a concrete question.'
assert_contains "$mentor" 'List and compare only the names of direct child directories of `.ai/learning/`, always excluding `summaries/`.'
assert_contains "$mentor" 'Do not read child contents, `mission.md`, `path.md`, `review-queue.md`, today'
assert_contains "$mentor" 'On an exact existing-topic match, classify durable immediately, then execute the normal durable workflow.'
assert_contains "$mentor" 'On no match, continue to the remaining intent and ambiguity rules; never create a topic from this lookup.'
assert_contains "$mentor" 'Concrete questions never activate the topic lookup or read learning state.'
assert_before "$mentor" 'Explicit modes take precedence.' 'Before applying the generic “quiero aprender X” ambiguity rule'
assert_before "$mentor" 'A concrete question, explanation, or small concept resolvable now routes through `learning-session`.' 'Before applying the generic “quiero aprender X” ambiguity rule'
assert_before "$mentor" 'Before applying the generic “quiero aprender X” ambiguity rule' 'A generic “quiero aprender X”, or an equivalent learning request without those durable signals, is ambiguous.'
assert_contains "$learn_command" 'Before applying the generic “quiero aprender X” ambiguity rule, use one narrow exception only when the exact raw argument has the form of a bare topic selection: a slug or name, not a concrete question.'
assert_contains "$learn_command" 'List and compare only the names of direct child directories of `.ai/learning/`, always excluding `summaries/`.'
assert_contains "$learn_command" 'Do not read child contents, `mission.md`, `path.md`, `review-queue.md`, today'
assert_contains "$learn_command" 'On an exact existing-topic match, classify durable immediately, then execute the normal durable workflow.'
assert_contains "$learn_command" 'On no match, continue to the remaining intent and ambiguity rules; never create a topic from this lookup.'
assert_contains "$learn_command" 'Concrete questions never activate the topic lookup or read learning state.'
assert_before "$learn_command" 'Explicit modes and clear durable-path, progress, or continued-practice intent take precedence' 'Before applying the generic “quiero aprender X” ambiguity rule'
assert_before "$learn_command" 'A concrete question, explanation, or small concept resolvable now routes through `learning-session`' 'Before applying the generic “quiero aprender X” ambiguity rule'
assert_before "$learn_command" 'Before applying the generic “quiero aprender X” ambiguity rule' 'A generic “quiero aprender X”, or an equivalent request without an explicit path or route, multi-session deadline or cadence, existing progress, or continued-practice signal, is ambiguous.'

# Summary persistence is opt-in, asynchronous, serialized per target, and receipt-only.
assert_contains "$mentor" 'Without an explicit save or update request, never create, update, or delegate a summary.'
assert_contains "$mentor" 'Before constructing `covered_material`, derive a learning-material-only view containing concepts, canonical answers, examples, limits, and covered corrections.'
assert_contains "$mentor" 'Exclude card and task IDs, `review-queue.md` rows or queue state, grades, Box/Last/Next metadata, due dates, scheduling dates, and review instructions or plans.'
assert_contains "$mentor" 'Do not pass or promise excluded metadata in any handoff field, even when `spaced-recall` is loaded.'
assert_contains "$mentor" 'Preserve dates that are genuine conceptual learning content; only labeled scheduling metadata is excluded.'
assert_before "$mentor" 'Before constructing `covered_material`' 'Send `learning-summarizer` the operation, exact target, conversation language, covered material'
assert_contains "$mentor" 'Send `learning-summarizer` the operation, exact target, conversation language, covered material, sources used, explicit corrections, and request ordinal.'
assert_exact_block "$mentor" "$summary_payload_contract"
assert_exact_block "$mentor" "$summary_task_call_contract"
assert_contains "$mentor" 'The `prompt` value is exactly the seven payload lines above, with no preface, suffix, or additional field.'
assert_contains "$mentor" 'The call must omit `task_id` entirely; never set it to `null`.'
assert_contains "$mentor" 'If `background: true` is unavailable, do not execute the `task` call: emit only `No se pudo guardar: <motivo>. Puedes pedir “reintenta guardarlo”.` and stop the turn.'
assert_contains "$mentor" 'After a valid launch, require its fresh runtime task ID immediately, track it, and continue the current turn without waiting, polling, or reading the task result.'
assert_contains "$mentor" 'Track review tasks and summary tasks in separate pending maps correlated by runtime task ID and target.'
assert_contains "$mentor" 'Allow only one pending summary mutation per target; coalesce the latest explicit update until the current task returns `OK`.'
assert_contains "$mentor" 'If that task fails, discard its coalesced update and require a new explicit request.'
assert_contains "$mentor" 'A correlated `OK` emits exactly one line: `Resumen guardado: <ruta>`, then terminates the turn.'
assert_contains "$mentor" 'A correlated `BLOCK`, `FAIL`, timeout, cancellation, rejected launch, or runtime error emits exactly one line: `No se pudo guardar: <motivo>. Puedes pedir “reintenta guardarlo”.`, then terminates the turn.'
assert_contains "$mentor" 'A summary-notification turn contains no text before or after that receipt. Never explain it, inspect, re-read, or verify the file, or add another claim.'
assert_contains "$mentor" 'A summary notification never retries, resumes, uses foreground, applies direct fallback, answers, repeats, or advances the open interaction.'
assert_contains "$mentor" 'Treat `summaries/` as reserved state: exclude it from topic discovery and never look there for `mission.md`, `path.md`, or `review-queue.md`.'

# Selected durable modes execute now instead of degrading into planning-only output.
assert_contains "$mentor" 'Once routing selects a durable mode, execute that mode now. Never answer with a plan, proposal, checklist of future actions, or planning-only substitute.'
assert_contains "$mentor" 'This applies especially to `/learn review` and an existing topic selected for continuation: run the due-check, open the required learner interaction immediately, continue it across genuine learner answers, persist each resulting checkpoint through `learning-recorder`, and close through the existing durable contracts.'
assert_contains "$learn_command" 'Once routing selects any durable mode, execute it now; never return a plan, proposed actions, future-action checklist, or planning-only substitute.'
assert_contains "$learn_command" 'For `/learn review` and existing-topic continuation, perform the due-check, open the required interaction immediately, continue it across genuine learner answers, persist resulting checkpoints through `learning-recorder`, and close under the existing durable contracts.'

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

# The bounded teaching contract is additive and does not broaden learning-loop.
assert_present "$learning_session" 'learning-session/classify-bounded-request'
if [ -f "$learning_session" ]; then
  assert_contains "$learning_session" 'Use for a concrete learning request that can be resolved in the current session.'
  assert_contains "$learning_session" 'Direct messages and raw `/learn` prompts use the same classification.'
  assert_contains "$learning_session" 'When “I want to learn X” is ambiguous, ask once whether the learner wants a bounded session or a multi-session path.'
  assert_contains "$learning_session" 'Do not read learning state or run the due-check when a bounded session starts.'
  assert_contains "$learning_session" 'If the learner explicitly asks what is due, run the existing `spaced-recall` due-check then.'
  assert_contains "$learning_session" 'Lead with the answer, teach in short chunks, and ask questions only when they help.'
  assert_contains "$learning_session" 'Never require a quiz, Feynman teach-back, or exercise.'
  assert_contains "$learning_session" 'Persist only after an explicit save or update request.'
  assert_contains "$learning_session" 'Choose `.ai/learning/summaries/YYYY-MM-DD-<slug>.md`; for an unrelated collision, use the next available suffix.'
  assert_contains "$learning_session" 'Pass exactly the seven fields `operation`, `target`, `conversation_language`, `covered_material`, `sources_used`, `explicit_corrections`, and `request_ordinal` to the authorized writer; use the names, order, and rules in the mandatory block below.'
  assert_exact_block "$learning_session" "$learning_session_payload_contract"
  assert_contains "$learning_session" 'Keep each value on its field'"'"'s single line. All seven fields are mandatory. Use `none` only for `sources_used` or `explicit_corrections` when applicable. If any field is absent, abort without launching a task.'
  assert_contains "$learning_session" 'Invoke only `learning-summarizer`, only with `background: true`, and omit `task_id` entirely. The description must equal `Persist learning summary operation=<create|update> target=<path> request=<ordinal>`.'
  assert_contains "$learning_session" 'If background execution is unavailable or the launch is rejected, do not invoke or wait for a foreground task, retry, resume, or apply any fallback.'
  assert_contains "$learning_session" 'A correlated `OK` emits exactly one line: `Resumen guardado: <ruta>`.'
  assert_contains "$learning_session" 'A correlated `BLOCK`, `FAIL`, timeout, cancellation, or runtime error emits exactly one line: `No se pudo guardar: <motivo>. Puedes pedir “reintenta guardarlo”.`'
  assert_contains "$learning_session" 'After that one line, stop. Do not explain, verify, re-read, answer, repeat, or advance the open interaction.'
  assert_contains "$learning_session" 'A compact summary uses the conversation language and one document with a title, date, brief synthesis, and lightweight Cornell cue-and-answer table.'
  assert_contains "$learning_session" 'Do not create a mission, path, module folder, learner-voiced summary, `Recall hand-off`, or review cards.'
  assert_contains "$learning_session" 'Loading `spaced-recall` for an on-demand review does not change this compact-summary boundary.'
  assert_contains "$learning_session" 'The summary may cover material discussed during that review, but it never creates, promises, schedules, or includes new cards, `review-queue.md`, `Recall hand-off`, card IDs, or a review plan.'
  assert_contains "$learning_session" 'Never mutate the review system from compact-summary persistence.'
fi

# The semantic writer has a narrow state and tool boundary.
assert_present "$summarizer" 'learning-summary/background-generation'
if [ -f "$summarizer" ]; then
  assert_frontmatter_contains "$summarizer" 'mode: subagent'
  assert_frontmatter_contains "$summarizer" 'question: deny'
  assert_frontmatter_contains "$summarizer" '  "*": deny'
  assert_permission_rule_block "$summarizer" read "$summary_scope"
  assert_permission_rule_block "$summarizer" edit "$summary_scope"
  assert_permission_rule_block "$summarizer" write "$summary_scope"
  assert_permission_rule_block "$summarizer" skill "$summarizer_skill_scope"
  assert_frontmatter_not_contains "$summarizer" '  bash:'
  assert_frontmatter_not_contains "$summarizer" '  webfetch:'
  assert_frontmatter_not_contains "$summarizer" '  task:'
  assert_contains "$summarizer" 'Require operation, exact target, source material, conversation language, sources used, explicit corrections, and request ordinal.'
  assert_contains "$summarizer" 'BLOCK before mutation when input is ambiguous, incomplete, outside `.ai/learning/summaries/**`, or collides with an unrelated existing file.'
  assert_contains "$summarizer" 'For create, confirm the target is absent and write one complete document.'
  assert_contains "$summarizer" 'For update, re-read the target, merge semantically equivalent ideas, preserve distinct nuances, and rewrite the complete document.'
  assert_contains "$summarizer" 'An explicit correction replaces the prior claim; mark unresolved differences instead of silently deleting them.'
  assert_contains "$summarizer" 'Before drafting and again before writing, apply a final learning-material filter to supplied source material and merged update content.'
  assert_contains "$summarizer" 'Keep only concepts, canonical answers, examples, limits, and covered corrections.'
  assert_contains "$summarizer" 'Never write card or task IDs, `review-queue.md` rows or queue state, grades, Box/Last/Next metadata, due dates, scheduling dates, or review instructions or plans, even when they appear in source material.'
  assert_contains "$summarizer" 'Do not promise that metadata.'
  assert_contains "$summarizer" 'Preserve dates that are genuine conceptual learning content; only labeled scheduling metadata is excluded.'
  assert_contains "$summarizer" 'Never infer uncovered facts, expose sensitive data, ask questions, run commands, access external sources, delegate, or write outside the exact target.'
  assert_contains "$summarizer" 'Return exactly one line: `OK target=<path>`, `BLOCK reason=<short>`, or `FAIL changed=<path|none> reason=<short>`.'
fi

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
