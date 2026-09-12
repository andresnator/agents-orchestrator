# Use the Learning Domain

Choose a one-off session to learn something now, a durable path for repeated practice, or `/english` for explicit English coaching.

```text
/learn session explícame el event loop con un ejemplo
/learn path validación de caché HTTP para decidir reutilizar, revalidar o descargar
/learn review cache-http
/english I have worked here since three years
```

One-off teaching creates no files unless the learner explicitly approves an independent summary. Durable learning uses a versioned state snapshot under the active project. Existing topic Markdown without that snapshot is unsupported and is never converted or overwritten.

## Install

Learning owns its agents, commands, skills, templates and runtime plugin:

```bash
installers/opencode.sh install --domain learning
```

Use a fresh target for verification or include every domain that should remain in an existing target.

## Verify an isolated target

```bash
LEARNING_PILOT="$(mktemp -d)"
mkdir "$LEARNING_PILOT/project"
installers/opencode.sh install --domain learning \
  --target "$LEARNING_PILOT/config" --no-install-brew-tools
```

Run debug and server commands from `$LEARNING_PILOT/project` with the target selected explicitly:

```bash
env OPENCODE_CONFIG_DIR="$LEARNING_PILOT/config" \
  OPENCODE_DISABLE_PROJECT_CONFIG=true \
  OPENCODE_DISABLE_EXTERNAL_SKILLS=true \
  OPENCODE_DISABLE_CLAUDE_CODE=true \
  XDG_CONFIG_HOME="$LEARNING_PILOT/xdg-config" \
  XDG_DATA_HOME="$LEARNING_PILOT/xdg-data" \
  XDG_STATE_HOME="$LEARNING_PILOT/xdg-state" \
  XDG_CACHE_HOME="$LEARNING_PILOT/xdg-cache" \
  opencode debug agent mentor
```

Inspect `mentor`, `english-tutor`, `learning-researcher`, `learning-writer` and `learning-summarizer`. The effective target must expose `learning_context`, `learning_event_reference`, `learning_state_read`, `learning_commit`, `learning_recover`, `learning_choice`, `learning_choice_result`, `learning_job_start`, `learning_job_result` and `learning_summary_create`. Removed calendar or internal-card operations must be absent and an old client receives `unsupported_event_type`.

## Route and consent

Mentor classifies the request before loading a skill, reading the date or accessing state. `/learn session` uses `learning-session`; `/learn path`, continuation and `/learn review` use `learning-loop` with the matching independent method; `/english` uses `english-tutor`. An ambiguous request presents a localized native session/path choice first.

The complete proposal appears in chat. `learning_choice.question` is only the short confirmation (maximum 300 characters); options remain brief and labels may be translated. `learning_choice` returns `not_shown` and exact `next_args`; Mentor calls the native `question`, then reads `learning_choice_result`. The host-correlated selection, revision and canonical subject digest are the only consent authority.

New consent purposes are `readiness`, `summary`, `export`, `gap`, `mission`, `scope_revision` and `module_selection`. Historical purposes remain readable in old schema-1 snapshots but cannot be staged for new work.

## One-off sessions and summaries

One-off teaching answers first, uses progressive disclosure and asks at most one focused question. It performs no state access or automatic save. An explicit summary request obtains native approval, runs one bounded `learning-summarizer`, validates its JSON and writes one collision-resistant file under `.ai/learning/summaries/`. The segment is frozen at approval; malformed or stale output creates no file.

## Durable state and flow

Every topic has one semantic authority:

```text
.ai/learning/<topic>/
  .state.json
  mission.md
  path.md
  vocabulary.md
  gaps.md
  resources.md
  notes/ exercises/ quizzes/ teachbacks/ dialogues/ maps/
```

`schema_version` remains `1`. New states omit internal-card, retention and due-date fields. Existing optional historical fields remain readable and are preserved during later commits; they never decide progression. `review-queue.md`, when present from an older state, is historical and is not regenerated.

The module flow is **Class → optional Practice → Consolidation → Materials → Close**. After Class, Mentor offers Practicar / Omitir once through native readiness consent. Omission from Class or unfinished Practice preserves partial attempts and enters Consolidation. A normal delivery saves the Cornell note, then the exercise, then closes in the same turn. A resumed delivery generates only missing or invalidated materials.

Close requires a completed or explicitly omitted practice decision, a consolidation with no blocking gaps, current note and exercise for non-language modules, and the applicable topic evidence. It does not require internal cards, a schedule or a delayed observation.

`revise_scope` preserves closed achievements and records before/after scope. `select_module` records a deferred module and resumes the selected destination. Both use native consent and exact current revision subjects. No navigation operation requires materials or closure.

## Evidence handoff

`learning_evidence` locates literal excerpts only in real learner text parts of the current parent session. Each reference keeps `session_id`, `message_id`, `part_id` and exact `quote`. Practice and Consolidation references are checked against the topic's `verified_evidence`, deduplicated and restricted to the module. Foreign or unverified references fail before commit.

The writer assignment contains four separate fields: `approved_outline`, `teacher_assessment`, `practice_state` and `learner_evidence_refs`. Mentor text is a composition instruction or assessment; it is never evidence of learner speech. Cornell and exercise outputs must distinguish literal quotes from teacher synthesis and mark missing evidence as pending.

Workers are bounded and sequential. The runtime checks worker ownership, source revision, destination, exact returned content and job settlement before attachment. An accepted failed child is recovered or cancelled by ID; no automatic retry or equivalent duplicate job is created.

## Language progression

Language practice is available the same day as exposure. Units are proposed in order and remain available when pending, unfinished, erroneous or `input-only`; no calendar, initial waiting period or grade blocks the learner. `input-only` keeps production pending when the mission requires production. Completion requires observed comprehension and meaning-preserving production.

## Anki vocabulary export

Anki remains an optional export. Candidates are previewed as exact five-field semicolon rows; the learner selects the subset natively. Export validates the exact rows, prevents duplicate keys and marks only the confirmed IDs exported. Export proves neither Anki import nor mastery and creates no internal cards or review dates.

## Permissions and evidence limits

Mentor may read a learner repository to teach or assess but cannot solve the learner's target work. Researcher, writer and summarizer cannot edit files, run shell commands, ask questions or delegate. The runtime is the only durable writer.

Deterministic tests and installation checks prove contracts, state validation, atomicity, recovery and permissions. They do not prove model latency, cost, teaching accuracy or learner competence. Model-backed cases must record the exact model, finite sample and explicit credit authorization.

## Troubleshooting

- `learning_tool_helper_unavailable`: install `@opencode-ai/plugin` in the selected OpenCode config target.
- `sequential_session_api_unavailable`: the host lacks a required synchronous session API; no child is launched.
- `unsupported_existing_topic_without_state`: choose a new slug or deliberately recreate the topic under schema 1.
- `revision_conflict`: read current state and form a new event from that revision.
- `topic_busy` or `ambiguous_topic_lock`: inspect the owner; remove a lock only after proving its PID is dead.
- `invalid_or_stale_artifact` or `unsettled_or_stale_writer`: inspect the accepted child and current revision before launching current work.
