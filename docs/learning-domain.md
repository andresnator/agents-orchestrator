# Use the Learning Domain

Choose a one-off session to learn something now, a durable path for repeated practice and review, or `/english` for explicit English coaching.

```text
/learn session explícame el event loop con un ejemplo
/learn path validación de caché HTTP para decidir reutilizar, revalidar o descargar
/learn review cache-http
/english I have worked here since three years
```

One-off teaching creates no files unless the learner explicitly approves an independent summary. Durable learning uses a versioned state snapshot under the active project. Existing topic Markdown without that snapshot is unsupported and is never converted or overwritten.

## Install

Learning owns all of its required agents, commands, skills, templates, and runtime plugins. Install it without a sibling domain:

```bash
installers/opencode.sh install --domain learning
```

Filtered installation synchronizes the selected target. Use a fresh target for verification or include every domain that should remain in an existing target.

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

- `recall_due` and `recall_schedule`
- `learning_context`, `learning_event_reference`, `learning_state_read`, `learning_commit`, and `learning_recover`
- `learning_due`, `learning_choice`, and `learning_choice_result`
- `learning_job_start`, `learning_job_result`, and `learning_summary_create`

A direct source import does not establish installed availability. A missing host helper fails explicitly with `learning_tool_helper_unavailable`.

## Choose the route

Mentor classifies the raw request before loading a skill, reading the date, or accessing state.

| Request | Route |
| --- | --- |
| `/learn session <request>` or a clearly bounded explanation | `learning-session` |
| `/learn path <topic>`, natural-language requests such as “créame un path”, continuation, review, repetition, progress, or another durable mode | `learning-loop` and the matching independent method |
| A genuinely ambiguous topic such as `/learn pizza` | Localized native session/path choice first |
| `/english <text>` | `english-tutor` only |

Existing topics never decide an ambiguous route. The learner can select a native option or state an explicit route in chat. Route selection does not require durable consent.

Present the complete proposal in chat with short paragraphs, lists, or tables; card cues and answers, including replacements, appear in full. Only `learning_choice.question` is limited to 300 characters, with brief options. Longer questions are rejected before UI and must be rewritten, never automatically truncated; structured subjects retain their existing limit and digest validation.

For a closed choice, `learning_choice` prepares data and returns `not_shown`, `next_tool: question`, and exact `next_args`. Mentor must call `question` to open the UI, then read `learning_choice_result` after it returns. Reading a staged choice also returns these instructions; polling never shows an interface or turns chat text into mutation consent.

## One-off sessions

One-off teaching answers first, uses progressive disclosure, and asks one focused learner question at a time. It performs no due-check and creates no mission, path, note, queue, or card.

### Save an independent summary

Saving requires an explicit positive native choice. Mentor sends only the pertinent session segment, conversation language, and sources actually used to a fresh `learning-summarizer`. The child returns one bounded JSON object with title, language, and complete Markdown.

`learning_summary_create` validates the matching job and interaction, then creates a collision-resistant file with exclusive mode:

```text
.ai/learning/summaries/<YYYY-MM-DD>-<HHMMSS>-<slug>-<random>.md
```

The summary segment is frozen at the save request. Mentor obtains native approval before launching the summarizer and saves its completed result on a later real learner turn, without requiring another request. Subsequent conversation does not extend or invalidate that segment.

One approval can create one file. Another explicit save, even with the same title during the same second, receives another path and cannot overwrite the first. Malformed output creates no file. The summary remains independent: it creates no topic, cards, progress, or recall handoff.

Child completion never creates an unsolicited parent response. One status notice is attached to a later real learner message. The notice is operational context; it does not answer an open question, advance a phase, or claim a saved path.

## Durable state

Every topic has one semantic authority:

```text
.ai/learning/
  summaries/
  <topic>/
    .state.json
    mission.md
    path.md
    review-queue.md
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

`learning_event_reference` publishes every supported discriminated event payload and its exact consent subject on demand. An identical event ID and body is idempotent. Reusing the ID with another body fails. Two commits at one expected revision cannot both win, duplicate change IDs are rejected, and the complete resulting snapshot is validated before replacement. If view generation is interrupted, committed state remains authoritative and `learning_recover` regenerates views without applying the event again.

A lock records PID and token. Recovery first claims that exact stale token with an exclusive file, rechecks the owner, and only then removes it; another process cannot delete a replacement lock. A live, malformed, or already-claimed lock stops the mutation. Topic, state-file, and artifact paths are canonicalized under the active project's `.ai/learning/`; traversal and symlink escape fail before content is read.

## Durable teaching

After a durable route is resolved, Mentor reads the identified topic and resumes its current module and phase. Only `unknown_topic` allows initialization; legacy or malformed state stops mutation.

`create_topic` requires native `mission` consent at revision 0 with option `create`, bound to topic slug and the exact title, materials language, goal (including scope and cadence), concepts, modules, and supplied optional language fields. The reference publishes `create`, `revise`, and `cancel`; revision of the proposal requires a new choice. Missing or mismatched consent fails before creating the topic directory. Initial state records consent; schema version 1 and existing topics remain unchanged.

New topics define an observable mission, stable concept IDs, prerequisite relationships, and modules with one tangible win. Mentor proposes an effort and cadence for correction rather than asking for an ungrounded time budget.

Non-language modules follow `Class → Practice → Consolidation`:

| Boundary | Required evidence |
| --- | --- |
| Class | Objective, central relationships, a worked example different from the target exercise, and one focused learner response |
| Retention | Zero to two exact eligible card previews; selected, none, or deferred disposition |
| Readiness | Separate later learner answer before Practice |
| Practice | Actual attempt on a new application, with hints faded from observed performance |
| Consolidation | Learner explanation of essential decisions and transfer, with no unresolved conceptual gap |
| Close | Completed practice, sufficient explanation, no blocking gap, resolved retention, and valid module note and exercise |

Actual evidence may satisfy more than one consolidation purpose. Do not demand a redundant Summary, debrief, or teach-back when the learner's causal explanation and transfer already meet the rubric. Use teach-back selectively for a foundational or uncertain concept. Confidence and worker output are not learner evidence.

Clarification can expand Class or unfinished Practice within the module's win. After Practice is done, a new concept becomes separate reinforcement so the completed scope is not rewritten.

After Consolidation, Mentor prepares missing materials automatically: commission a `cornell-notes` note, attach its exact result, then commission a `learning-loop` exercise at the new revision. These jobs run in series. Close requires both valid materials and the existing evidence conditions. Pending delivery resumes on real learner turns without another materials request.

`learning_evidence` finds literal excerpts only in real learner text parts of the current parent session. It excludes assistant/tool/worker messages and synthetic or ignored text. Practice completion and Consolidation require `evidence_refs` with session, message, part, and exact quote. The runtime verifies new references under the topic lock and stores them in the module and topic's `verified_evidence`; a foreign-session reference is reusable only when already verified in this same topic.

Teacher assessment remains separate from learner quotes. Authorship verification does not prove correctness: Mentor evaluates mission criteria, reuses sufficient evidence, and asks only for a missing criterion. `complete_topic` accepts references and constructs its evidence from their quotes, preserving provenance, date, and event ID in `topic.completion`. The generated `mission.md` includes this completion record, including after restart or view recovery. Schema version remains 1; added fields are optional when reading old state. Existing completions are unchanged and historical narrative is not promoted to verified evidence. Identical committed events remain idempotent even when the original session history is unavailable.

### Fundamental recall

The mission's default fundamental shortlist contains reusable prerequisites, decision rules, and costly recurring misconceptions. Its maximum is `floor(concept_count / 5)`. The denominator is the distinct mission concept inventory; fewer than five concepts can produce zero candidates. A learner may explicitly override this for a shown, taught concept.

After Class, Mentor proposes at most two eligible cards with exact cue, expected answer, concept/source revision, and short rationale. The runtime stores a canonical digest of that preview. Mentor passes both the stored structure and digest to `learning_choice`; the tool verifies the hash and binds the complete structure without adding JSON to the native question. For other entity choices, Mentor passes the exact subject JSON specified by `learning_event_reference`, and the runtime canonicalizes and hashes it. The runtime then binds native `question.asked` and `question.replied` events to the session, tool call, request ID, revision, topic, and target entity. Edits, reformulations, and splits use the same two-step rule: store the proposed replacement, then show the complete replacement in chat and obtain a brief native confirmation bound to its exact structure, change ID, and digest. A consent shown for one entity cannot mutate another. A model-authored `approved: true` has no authority.

Resolve `learning_event_reference` with topic and module/card IDs before selecting cards or grading. It returns the current revision, exact subject JSON/digest and choice contract. Card options are stored proposal IDs plus exclusive `none`/`deferred` choices (`multiple: true`); grade options are exactly `Again`, `Hard`, `Good`, `Easy` (`multiple: false`). Labels may be translated; machine values are copied. Invalid options fail before the interface opens, and incompatible selections cannot authorize a mutation. Retain the staged choice ID, open its exact `next_args`, and apply only the result for that ID. Current unchanged content needs one confirmation; a real content change requires a new one.

Only the exact selected proposals receive final IDs at commit. Partial, extra, replayed, unrelated, or stale selections fail. Editing a scheduled card requires another meaningful choice; the former card is retired and the replacement receives a new ID with lineage. `none` and `deferred` create no card and do not block learning.

Cornell cues remain available as ordinary retrieval questions independently of SRS admission.

## Review

Active cards use deterministic intervals:

| Box | Next interval |
| --- | --- |
| 1 | 1 day |
| 2 | 3 days |
| 3 | 7 days |
| 4 | 14 days |
| 5 | 30 days |

`recall_due` parses only the active `## Queue` table. It supports escaped Markdown pipes and reports duplicate IDs, invalid boxes, invalid dates, impossible Last/Next relations, and malformed rows. It never converts malformed data into a misleading empty queue. File reads are bounded and remain inside the current Learning root.

Mentor recommends a grade from the actual answer and rubric; the learner still selects the grade through a native choice. Each grade is one deterministic state commit, so review does not launch a model writer per card. Good or Easy at box 5 keeps the card on 30-day maintenance. Suspension and retirement require explicit choices.

`apply_card_change` publishes a `choice` contract: purpose `cards` for edit or `reformulation` for reformulate/split, single selection, options `<stored change.id>` and `cancel`. Staging validates these exact IDs; labels may be localized. The positive ID is never `accept`.

The failure count is cumulative since creation or the last agreed repair. A third `Again` cannot be recorded as an ordinary grade. The learner chooses reformulate or split; the old card retires and replacements receive new IDs with history preserved in lineage.

## Research and artifact composition

Mentor may start one bounded researcher and one composition worker for a topic. `learning_job_start` creates a real child session and returns its accepted ID immediately. It uses the host session create, asynchronous prompt, messages, status, and abort APIs; it does not depend on Task exposing a background flag.

`learning_job_start.artifact` is required only for `learning-writer`: `kind`, `method`, `destination_hint`, `materials_language`, and, for notes/exercises, `module_id` and exact `selected_card_ids` (including `[]`). Destinations are lowercase paths relative to the topic, such as `notes/m-0001.md`; omit `.ai/learning/<topic>/`. Invalid destination, method, ownership or selection fails before child creation. Mentor may correct these rejected arguments; an accepted failed model job still never retries automatically. `prompt` supplies the bounded outline and evidence; the runtime constructs the assignment with `source_revision` from `revision`. The writer loads only the specified method and returns `{kind, source_revision, destination_hint, content, module_id?, selected_card_ids?}`.

The researcher receives a question and source scope, returns at most five source-grounded findings, and cannot write or delegate. The writer receives one artifact kind, destination, source revision, materials language, approved outline, real learner evidence, and necessary verified sources. It composes the complete body and has no file, shell, question, research, or delegation access.

Mentor can continue an independent explanation or learner question while a child is busy. A claim that depends on unfinished research remains pending. Silence or absence from the busy map is not a successful result. Observe the accepted child; cancel that ID and verify settlement before replacement.

Topic job metadata is stored with authoritative state. Same-worker work for one topic is not duplicated across parent sessions or simultaneous starts. A newer revision coalesces behind the active job and makes the old result ineligible. A completed child result can be recovered through its host session after OpenCode restarts. Before attachment, the runtime checks topic ownership, worker kind, exact source revision, destination, and content.

## Language progression

Each language unit records passive exposure date, active due date, situation, bilingual text, status, and actual evidence. The initial pilot policy makes active practice due three days after passive exposure; the learner may change the policy in a future configured flow. Unit count never determines due work.

On the due date, the learner reconstructs meaning from the native side. Natural equivalents are valid. Meaning-changing omissions or structural errors produce focused feedback and `needs-another-attempt` with a future date. Completion requires observed gist and meaning-preserving production.

Input-only remains a valid choice. If the mission requires production, it leaves that criterion pending and stays eligible for later productive practice. When no passive units remain, due active units continue until the finite course is drained; one-, five-, and six-unit courses need no buffer or invented unit.

### Vocabulary export

Anki work has two states:

1. candidates contain natural phrase units and proposed five-field semicolon rows;
2. one host-correlated export choice selects exact candidate IDs.

Consent includes the complete preview rows in choice-option order; exported IDs must match the learner-selected subset exactly. Reuse an unexported candidate ID to correct its row at the current revision, then preview and confirm again. Exported rows are immutable.

The export event validates every row, atomically updates the registry, and writes the selected batch once. Duplicate keys are target language plus NFKC/lowercase/whitespace-normalized unit. The first field must normalize to the candidate unit. Quotes, embedded newlines, wrong field counts, and reused exported candidates fail the whole event.

An export does not prove import into Anki or learner mastery. It creates no second Leitner schedule unless the learner separately requests and confirms a conceptual card.

## English privacy

`/english` is explicit; the specialist never monitors unrelated conversation. It returns correction, reason, natural alternatives, and a focused retry. With another learner choice, a repeated issue may become a synthetic gap containing category, invented generic pattern, and distinct occurrence references. Raw user sentences, private examples, and correction history are never stored or handed to another agent.

Gap adoption and review-card admission are separate interactions.

## Permissions

Mentor may read a learner repository to teach or assess, but cannot edit it or solve the learner's target work. Broad shell commands are denied. Known test/build prefixes use `ask`; Mentor announces the exact command and the learner decides through that separate permission boundary.

Researcher, writer, and summarizer cannot edit, write, run shell commands, ask questions, or delegate. The writer and summarizer return data to the runtime. The runtime is the only durable writer.

## Evidence boundaries

The local scripted pilot proves installed tools, native interaction correlation, delayed child overlap, cancellation, restart recovery, exclusive summary creation, and filesystem/permission boundaries. It does not measure model latency, cost, teaching accuracy, or retention.

Model-backed cases require explicit credit authorization and record the exact model and finite sample. Delayed day-7/day-30 observations require learner participation and remain pending until those dates and answers exist. Use the [Learning manual catalog](../domains/learning/manual-tests.md) to keep protocol, model, and human evidence distinct.

## Troubleshooting

- `learning_tool_helper_unavailable`: install `@opencode-ai/plugin` in the selected OpenCode config target and re-inspect installed tools.
- `async_session_api_unavailable`: the host lacks one of the required session APIs; no synchronous fallback is used.
- `unsupported_existing_topic_without_state`: choose a new topic slug or deliberately recreate the topic under schema version 1.
- `revision_conflict`: read current state and form a new event from that revision; do not replay a different event body.
- `topic_busy` or `ambiguous_topic_lock`: inspect the owner; do not remove a lock unless its dead PID is proven.
- `invalid_or_stale_artifact` or `unsettled_or_stale_writer`: inspect the accepted child and current revision; launch current work only after prior settlement is known.
- A summary was not created: confirm a positive native save choice, completed summarizer JSON, and unused interaction ID.
- A language topic will not complete: inspect input-only or retry-needed units when production is required.
