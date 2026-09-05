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
- `learning_context`, `learning_state_read`, `learning_commit`, and `learning_recover`
- `learning_due`, `learning_choice`, and `learning_choice_result`
- `learning_job_start`, `learning_job_result`, and `learning_summary_create`

A direct source import does not establish installed availability. A missing host helper fails explicitly with `learning_tool_helper_unavailable`.

## Choose the route

Mentor classifies the raw request before loading a skill, reading the date, or accessing state.

| Request | Route |
| --- | --- |
| `/learn session <request>` or a clearly bounded explanation | `learning-session` |
| `/learn path <topic>`, continuation, review, repetition, progress, or another durable mode | `learning-loop` and the matching independent method |
| A genuinely ambiguous topic such as `/learn pizza` | Localized native session/path choice first |
| `/english <text>` | `english-tutor` only |

Existing topics never decide an ambiguous route. The host-correlated choice does.

## One-off sessions

One-off teaching answers first, uses progressive disclosure, and asks one focused learner question at a time. It performs no due-check and creates no mission, path, note, queue, or card.

### Save an independent summary

Saving requires an explicit positive native choice. Mentor sends only the pertinent session segment, conversation language, and sources actually used to a fresh `learning-summarizer`. The child returns one bounded JSON object with title, language, and complete Markdown.

`learning_summary_create` validates the matching job and interaction, then creates a collision-resistant file with exclusive mode:

```text
.ai/learning/summaries/<YYYY-MM-DD>-<HHMMSS>-<slug>-<random>.md
```

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

An identical event ID and body is idempotent. Reusing the ID with another body fails. Two commits at one expected revision cannot both win. If view generation is interrupted, committed state remains authoritative and `learning_recover` regenerates views without applying the event again.

A lock records PID and token. Only a provably dead owner is recovered automatically. A live or malformed lock stops the mutation. Topic and artifact paths are canonicalized under the active project's `.ai/learning/`; traversal and symlink escape fail.

## Durable teaching

New topics define an observable mission, stable concept IDs, prerequisite relationships, and modules with one tangible win. Mentor proposes an effort and cadence for correction rather than asking for an ungrounded time budget.

Non-language modules follow `Class → Practice → Consolidation`:

| Boundary | Required evidence |
| --- | --- |
| Class | Objective, central relationships, a worked example different from the target exercise, and one focused learner response |
| Retention | Zero to two exact eligible card previews; selected, none, or deferred disposition |
| Readiness | Separate later learner answer before Practice |
| Practice | Actual attempt on a new application, with hints faded from observed performance |
| Consolidation | Learner explanation of essential decisions and transfer, with no unresolved conceptual gap |
| Close | Completed practice, sufficient explanation, no blocking gap, and resolved retention disposition |

Actual evidence may satisfy more than one consolidation purpose. Do not demand a redundant Summary, debrief, or teach-back when the learner's causal explanation and transfer already meet the rubric. Use teach-back selectively for a foundational or uncertain concept. Confidence and worker output are not learner evidence.

Clarification can expand Class or unfinished Practice within the module's win. After Practice is done, a new concept becomes separate reinforcement so the completed scope is not rewritten.

### Fundamental recall

The mission's default fundamental shortlist contains reusable prerequisites, decision rules, and costly recurring misconceptions. Its maximum is `floor(concept_count / 5)`. The denominator is the distinct mission concept inventory; fewer than five concepts can produce zero candidates. A learner may explicitly override this for a shown, taught concept.

After Class, Mentor proposes at most two eligible cards with exact cue, expected answer, concept/source revision, and short rationale. The runtime stores a canonical digest of that preview. Mentor passes both the stored structure and digest to `learning_choice`; the tool verifies the hash and renders the exact structure itself. The runtime then binds native `question.asked` and `question.replied` events to the session, tool call, request ID, revision, and preview. Edits, reformulations, and splits use the same two-step rule: store the proposed replacement, then render and confirm its exact structure, change ID, and digest. A model-authored `approved: true` has no authority.

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

The failure count is cumulative since creation or the last agreed repair. A third `Again` cannot be recorded as an ordinary grade. The learner chooses reformulate or split; the old card retires and replacements receive new IDs with history preserved in lineage.

## Research and artifact composition

Mentor may start one bounded researcher and one composition worker for a topic. `learning_job_start` creates a real child session and returns its accepted ID immediately. It uses the host session create, asynchronous prompt, messages, status, and abort APIs; it does not depend on Task exposing a background flag.

The researcher receives a question and source scope, returns at most five source-grounded findings, and cannot write or delegate. The writer receives one artifact kind, destination, source revision, materials language, approved outline, real learner evidence, and necessary verified sources. It composes the complete body and has no file, shell, question, research, or delegation access.

Mentor can continue an independent explanation or learner question while a child is busy. A claim that depends on unfinished research remains pending. Silence or absence from the busy map is not a successful result. Observe the accepted child; cancel that ID and verify settlement before replacement.

Topic job metadata is stored with authoritative state. Same-worker work for one topic is not duplicated. A newer revision coalesces behind the active job and makes the old result ineligible. A completed child result can be recovered through its host session after OpenCode restarts. Before attachment, the runtime checks topic ownership, worker kind, exact source revision, destination, and content.

## Language progression

Each language unit records passive exposure date, active due date, situation, bilingual text, status, and actual evidence. The initial pilot policy makes active practice due three days after passive exposure; the learner may change the policy in a future configured flow. Unit count never determines due work.

On the due date, the learner reconstructs meaning from the native side. Natural equivalents are valid. Meaning-changing omissions or structural errors produce focused feedback and `needs-another-attempt` with a future date. Completion requires observed gist and meaning-preserving production.

Input-only remains a valid choice. If the mission requires production, it leaves that criterion pending and stays eligible for later productive practice. When no passive units remain, due active units continue until the finite course is drained; one-, five-, and six-unit courses need no buffer or invented unit.

### Vocabulary export

Anki work has two states:

1. candidates contain natural phrase units and proposed five-field semicolon rows;
2. one host-correlated export choice selects exact candidate IDs.

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
