# Use the Learning Domain

Choose a one-off session to learn something now, a durable path for repeated practice and on-demand review, or `/english` for explicit English coaching.

```text
/learn session explícame el event loop con un ejemplo
/learn path validación de caché HTTP para decidir reutilizar, revalidar o descargar
/english I have worked here since three years
```

One-off teaching creates no files unless the learner explicitly approves an independent summary. Durable learning uses a versioned state snapshot under the active project. Existing topic Markdown without that snapshot is unsupported and is never converted or overwritten.

## Install

Learning owns all of its required agents, commands, skills, templates, and the runtime plugin. Install it without a sibling domain:

```bash
installers/opencode.sh install --domain learning
```

Filtered installation synchronizes the selected target. Use a fresh target for verification or include every domain that should remain in an existing target. Re-running the installer after upgrading from an older checkout also removes previously managed spaced-repetition files (the `recall-calc` plugin and `spaced-recall` skill); existing topic directories keep their files as historical data.

## Verify an isolated target

The implementation pilot used OpenCode 1.18.20, Node 26.8.1, and `@opencode-ai/plugin` 1.18.20. Re-run the capability case after a host upgrade; version strings alone do not prove effective tools or permissions.

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

Configure a provider only inside the disposable target. A scripted loopback provider is enough for protocol checks and avoids model calls. Do not copy global credentials into the target. `OPENCODE_DISABLE_EXTERNAL_SKILLS=true` prevents personal skills from changing the result.

Inspect `mentor`, `english-tutor`, `learning-researcher`, `learning-writer`, and `learning-summarizer`. Inspect the same server's `/doc` and `/experimental/tool?provider=<id>&model=<id>`. The installed target must expose:

- `learning_context`, `learning_event_reference`, `learning_state_read`, `learning_commit`, and `learning_recover`
- `learning_choice`, `learning_choice_result`, and `learning_evidence`
- `learning_job_start`, `learning_job_result`, and `learning_summary_create`

`recall_due`, `recall_schedule`, and `learning_due` must be absent. A direct source import does not establish installed availability. A missing host helper fails explicitly with `learning_tool_helper_unavailable`.

## Choose the route

Mentor classifies the raw request before loading a skill, reading the date, or accessing state.

| Request | Route |
| --- | --- |
| `/learn session <request>` or a clearly bounded explanation | `learning-session` |
| `/learn path <topic>`, natural-language requests such as “créame un path”, continuation, on-demand review, repetition, progress, or another durable mode | `learning-loop` and the matching independent method |
| A genuinely ambiguous topic such as `/learn pizza` | Localized native session/path choice first |
| `/english <text>` | `english-tutor` only |

Existing topics never decide an ambiguous route. The learner can select a native option or state an explicit route in chat. Route selection does not require durable consent.

Present the complete proposal in chat with short paragraphs, lists, or tables. Only `learning_choice.question` is limited to 300 characters, with brief options. Longer questions are rejected before UI and must be rewritten, never automatically truncated; structured subjects retain their existing limit and digest validation.

For a closed choice, `learning_choice` prepares data and returns `not_shown`, `next_tool: question`, and exact `next_args`. Mentor must call `question` to open the UI, then read `learning_choice_result` after it returns. Reading a staged choice also returns these instructions; polling never shows an interface or turns chat text into mutation consent.

## One-off sessions

One-off teaching answers first, uses progressive disclosure, and asks one focused learner question at a time. It performs no due-check and creates no mission, path, note, or queue.

### Save an independent summary

Saving requires an explicit positive native choice. Mentor sends only the pertinent session segment, conversation language, and sources actually used to a fresh `learning-summarizer`. The child returns one bounded JSON object with title, language, and complete Markdown.

`learning_summary_create` validates the matching job and interaction, then creates a collision-resistant file with exclusive mode:

```text
.ai/learning/summaries/<YYYY-MM-DD>-<HHMMSS>-<slug>-<random>.md
```

The summary segment is frozen at the save request. Mentor obtains native approval before launching the summarizer and awaits and saves its completed result in the same turn, without requiring another request. Subsequent conversation does not extend or invalidate that segment.

One approval can create one file. Another explicit save, even with the same title during the same second, receives another path and cannot overwrite the first. Malformed output creates no file. The summary remains independent: it creates no topic, progress, or handoff.

The awaited result returns to the current tool call; no deferred notice or extra learner turn is needed. A saved path is reported only after successful creation.

## Durable state

Every topic has one semantic authority:

```text
.ai/learning/
  summaries/
  <topic>/
    .state.json
    mission.md
    path.md
    vocabulary.md
    gaps.md
    resources.md                 # when composed
    notes/
    exercises/
    quizzes/
    teachbacks/
    dialogues/
    maps/
    anki/
```

`.state.json` uses schema version 1 and a monotonic revision. Markdown files are generated views or validated artifacts, not independent state. A mutation:

1. validates the complete event, host interaction when required, event ID, and expected revision;
2. obtains a per-topic lock;
3. writes and syncs a complete temporary snapshot;
4. atomically replaces `.state.json`;
5. regenerates views for that revision; and
6. marks views current only after generation succeeds.

`learning_event_reference` publishes every supported discriminated event payload and its exact consent subject on demand. An identical event ID and body is idempotent. Reusing the ID with another body fails. Two commits at one expected revision cannot both win, and the complete resulting snapshot is validated before replacement. If view generation is interrupted, committed state remains authoritative and `learning_recover` regenerates views without applying the event again. `review-queue.md` is no longer generated; an existing file from an older version is left untouched as history.

A lock records PID and token. Recovery first claims that exact stale token with an exclusive file, rechecks the owner, and only then removes it; another process cannot delete a replacement lock. A live, malformed, or already-claimed lock stops the mutation. Topic, state-file, and artifact paths are canonicalized under the active project's `.ai/learning/`; traversal and symlink escape fail before content is read.

## Durable teaching

After a durable route is resolved, Mentor reads the identified topic and resumes its current module and phase. Only `unknown_topic` allows initialization; legacy or malformed state stops mutation.

`create_topic` requires native `mission` consent at revision 0 with option `create`, bound to topic slug and the exact title, materials language, goal (including scope and cadence), concepts, modules, and supplied optional language fields. The reference publishes `create`, `revise`, and `cancel`; revision of the proposal requires a new choice. Missing or mismatched consent fails before creating the topic directory. Initial state records consent; schema version 1 and existing topics remain unchanged.

New topics define an observable mission, stable concept IDs, prerequisite relationships, and modules with one tangible win. Mentor proposes an effort and cadence for correction rather than asking for an ungrounded time budget.

Non-language modules follow `Class → optional Practice → Consolidation`:

| Boundary | Required evidence |
| --- | --- |
| Class | Objective, central relationships, a worked example different from the target exercise, and one focused learner response |
| Readiness | Separate native Practicar / Omitir choice (`readiness`: `ready` / `skip`), offered once directly after Class and reused on resume |
| Practice | Actual attempt on a new application, with hints faded from observed performance |
| Consolidation | Learner explanation of essential decisions and transfer, with no unresolved conceptual gap |
| Close | Completed or explicitly omitted practice, sufficient explanation, no blocking gap, and valid module note and exercise |

Actual evidence may satisfy more than one consolidation purpose. Do not demand a redundant Summary, debrief, or teach-back when the learner's causal explanation and transfer already meet the rubric. Use teach-back selectively for a foundational or uncertain concept. Confidence and worker output are not learner evidence.

`skip_practice` requires native `readiness` consent selecting `skip`, bound to the current revision and exact `{topic_slug, module_id}`. It is valid from Class or unfinished Practice, sets optional `practice_skipped: true`, preserves attempts, and enters Consolidation. Clarification or dismissal leaves the phase unchanged. Old `schema_version: 1` states remain readable without migration. Both materials are still generated; omission is shown in existing fields without changing paths, folders, sections, columns, or templates. A brief verified learner explanation remains required; omission does not prove practical competence. There is no mandatory capstone by default: topic completion still requires evidence against the agreed criteria.

Clarification can expand Class or unfinished Practice within the module's win. After Practice is done, a new concept becomes separate reinforcement so the completed scope is not rewritten.

After Consolidation, Mentor prepares missing materials automatically: commission a `cornell-notes` note, attach its exact result, then commission a `learning-loop` exercise at the new revision. These jobs run in series. Close requires both valid materials and the existing evidence conditions. Pending delivery resumes on real learner turns without another materials request. On resume, only missing or invalidated materials are regenerated.

`learning_evidence` finds literal excerpts only in real learner text parts of the current parent session. It excludes assistant/tool/worker messages and synthetic or ignored text. Practice completion and Consolidation require `evidence_refs` with session, message, part, and exact quote. The runtime verifies new references under the topic lock and stores them in the module and topic's `verified_evidence`; a foreign-session reference is reusable only when already verified in this same topic.

Teacher assessment remains separate from learner quotes. Authorship verification does not prove correctness: Mentor evaluates mission criteria, reuses sufficient evidence, and asks only for a missing criterion. `complete_topic` accepts references and constructs its evidence from their quotes, preserving provenance, date, and event ID in `topic.completion`. The generated `mission.md` includes this completion record, including after restart or view recovery. Schema version remains 1; added fields are optional when reading old state. Existing completions are unchanged and historical narrative is not promoted to verified evidence. Identical committed events remain idempotent even when the original session history is unavailable.

### Writer assignments

`learning_job_start` builds the writer assignment from committed state, not from Mentor's prose. It separates:

- `approved_outline`: Mentor's composition instructions;
- `teaching_assessment`: teacher-authored evaluation stored in the module (class evidence, attempt assessment, consolidation assessment);
- `practice_status`: whether practice was skipped and the recorded attempt outcome;
- `learner_evidence`: literal references with exact `session_id`, `message_id`, `part_id`, and `quote`, built from the module's attempt and consolidation, checked against the topic's `verified_evidence`, deduplicated, and restricted to that module.

The writer must quote the learner only from `learner_evidence`; outline and assessment text is teacher authorship and never presented as learner words. Empty `learner_evidence` stays pending. Notes use `cornell-notes` and exercises use `learning-loop`; the loaded skills carry the full inline templates.

## Practice on demand

There is no internal card system, no spaced-repetition calendar, and no grades. Cornell questions, quizzes, teach-backs, and drills remain ordinary practice resources that Mentor or a method skill can run whenever the learner asks. Each `review` request is one self-contained retrieval pass over supplied material; nothing is scheduled and no outcome is recorded as a durable grade.

Older `schema_version: 1` topics may still carry historical card, retention, preview, and scheduling fields. The runtime reads and preserves them, never uses them to gate teaching, materials, closure, or completion, and rejects retired card operations (`preview_cards`, `select_cards`, `grade_card`, `preview_card_change`, `apply_card_change`, `set_card_status`, `set_fundamental_override`) if an old client invokes them. New states simply omit those fields.

## Research and artifact composition

Mentor runs one bounded worker at a time per parent session. `learning_job_start` creates a real child through `client.session.create`, awaits `client.session.prompt`, and verifies terminal messages and status before returning the complete result. `learning_context.sequential_jobs` reports availability. Note → save → exercise → save → Close and approved summary composition/save complete in the same turn, using each commit's new revision, without learner “continue” messages.

`learning_job_start.artifact` is required only for `learning-writer`: `kind`, `method`, `destination_hint`, `materials_language`, and, for notes/exercises, `module_id`. Destinations are lowercase paths relative to the topic, such as `notes/m-0001.md`; omit `.ai/learning/<topic>/`. Invalid destination, method, or ownership fails before child creation. Mentor may correct these rejected arguments; an accepted failed model job still never retries automatically. `prompt` supplies the approved outline only; the runtime constructs the assignment with `source_revision` from `revision` plus the separated evidence fields. The writer loads only the specified method and returns `{kind, source_revision, destination_hint, content, module_id?}`.

The researcher receives a question and source scope, returns at most five source-grounded findings, and cannot write or delegate. The writer receives one artifact kind, destination, source revision, materials language, approved outline, teacher assessment, practice status, and literal learner evidence. It composes the complete body and has no file, shell, question, research, or delegation access.

`learning_job_result` is for cancellation or recovery of the same accepted child; recovery waits inside the call while it remains active. Parent cancellation propagates to the child. Transport errors retain the accepted ID and do not authorize a replacement without inspecting its state. Deferred notifications are not emitted. Silence or absence from the busy map is not a successful result. Observe the accepted child; cancel that ID and verify settlement before replacement.

Topic job metadata is stored with authoritative state. Same-worker work for one topic is not duplicated across parent sessions or simultaneous starts. A newer revision stays blocked behind the accepted job and makes the old result ineligible. A completed child result can be recovered through its host session after OpenCode restarts. Before attachment, the runtime checks topic ownership, worker kind, exact source revision, destination, and content.

## Language progression

Each language unit records the passive exposure date, situation, bilingual text, status, and actual evidence. Unit dates are historical records, never a calendar: a unit the learner selects is available for practice immediately, including units recorded with errors or as input-only. The default proposal follows unit order, and unit count never determines what is offered.

When the learner practices a unit, they reconstruct meaning from the native side. Natural equivalents are valid. Meaning-changing omissions or structural errors produce focused feedback and `needs-another-attempt`; the record notes the error without scheduling a future date. Completion requires observed gist and meaning-preserving production.

Input-only remains a valid choice. If the mission requires production, it leaves that criterion pending and stays eligible for later productive practice. Unfinished units remain available in unit order until the finite course is drained; one-, five-, and six-unit courses need no buffer or invented unit.

### Vocabulary export

Anki work has two states:

1. candidates contain natural phrase units and proposed five-field semicolon rows;
2. one host-correlated export choice selects exact candidate IDs.

Consent includes the complete preview rows in choice-option order; exported IDs must match the learner-selected subset exactly. Reuse an unexported candidate ID to correct its row at the current revision, then preview and confirm again. Exported rows are immutable.

The export event validates every row, atomically updates the registry, and writes the selected batch once. Duplicate keys are target language plus NFKC/lowercase/whitespace-normalized unit. The first field must normalize to the candidate unit. Quotes, embedded newlines, wrong field counts, and reused exported candidates fail the whole event.

An export does not prove import into Anki or learner mastery. It creates no internal review item or review date; any further study of the phrase is an explicit, separate learner activity.

## English privacy

`/english` is explicit; the specialist never monitors unrelated conversation. It returns correction, reason, natural alternatives, and a focused retry. With another learner choice, a repeated issue may become a synthetic gap containing category, invented generic pattern, and distinct occurrence references. Raw user sentences, private examples, and correction history are never stored or handed to another agent.

Gap adoption schedules nothing; it only marks how the learner wants to use the gap.

## Permissions

Mentor may read a learner repository to teach or assess, but cannot edit it or solve the learner's target work. Broad shell commands are denied. Known test/build prefixes use `ask`; Mentor announces the exact command and the learner decides through that separate permission boundary.

Researcher, writer, and summarizer cannot edit, write, run shell commands, ask questions, or delegate. The writer and summarizer return data to the runtime. The runtime is the only durable writer.

## Evidence boundaries

The local scripted pilot proves installed tools, native interaction correlation, delayed child overlap, cancellation, restart recovery, exclusive summary creation, and filesystem/permission boundaries. It does not measure model latency, cost, teaching accuracy, or retention.

Model-backed cases require explicit credit authorization and record the exact model and finite sample. Delayed day-7/day-30 observations require learner participation and remain pending until those dates and answers exist. Use the [Learning manual catalog](../domains/learning/manual-tests.md) to keep protocol, model, and human evidence distinct.

## Troubleshooting

- `learning_tool_helper_unavailable`: install `@opencode-ai/plugin` in the selected OpenCode config target and re-inspect installed tools.
- `sequential_session_api_unavailable`: the host lacks one of the required synchronous session APIs; no model job is launched.
- `unsupported_existing_topic_without_state`: choose a new topic slug or deliberately recreate the topic under schema version 1.
- `revision_conflict`: read current state and form a new event from that revision; do not replay a different event body.
- `topic_busy` or `ambiguous_topic_lock`: inspect the owner; do not remove a lock unless its dead PID is proven.
- `invalid_or_stale_artifact` or `unsettled_or_stale_writer`: inspect the accepted child and current revision; launch current work only after prior settlement is known.
- A summary was not created: confirm a positive native save choice, completed summarizer JSON, and unused interaction ID.
- A language topic will not complete: inspect input-only or retry-needed units when production is required.
- `unsupported_event_type` for a card or scheduling event: the operation was retired; use the current `learning_event_reference` catalog.
