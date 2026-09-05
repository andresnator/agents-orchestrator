# Learning manual tests

Run these cases in a disposable OpenCode project. Keep deterministic protocol evidence separate from model behavior and human learning evidence. Durable cases may write only under the disposable project's `.ai/learning/` directory.

## Quick path

1. Install only the current checkout's `learning` domain into a fresh target.
2. Run the affected IDs listed in the pull request, one exact prompt sequence per case.
3. Inspect `.ai/learning/`, including hidden files, and record the OpenCode/model versions actually used.
4. Stop the disposable services and remove only their temporary target.

### MT-LEARNING-RUNTIME

- **Title:** Verify installed runtime and host interaction boundaries
- **Coverage key:** `learning/runtime/host-capabilities`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/plugins/recall-calc.ts`, `domains/learning/agents/mentor.md`, `domains/learning/agents/english-tutor.md`
- **Preconditions:** Install only `learning` into a fresh target. Select it with `OPENCODE_CONFIG_DIR` plus isolated XDG config, data, state, and cache directories. Set `OPENCODE_DISABLE_PROJECT_CONFIG=true`, `OPENCODE_DISABLE_EXTERNAL_SKILLS=true`, and `OPENCODE_DISABLE_CLAUDE_CODE=true`. Use a scripted loopback provider and no model credentials.
- **Steps:**
  1. Inspect `opencode debug agent mentor`, `opencode debug agent english-tutor`, `/doc`, and `/experimental/tool?provider=<fixture-provider>&model=<fixture-model>`. Invoke `learning_context` and `recall_due` through the installed host.
  2. Stage the exact prompt `Save this card? Cue: Why revalidate? Answer: To check whether a stale response changed.` with `Save card` and `Save none`. Show the returned native question and reply `Save none` through the host endpoint or UI.
  3. Replay that request ID, send an unrelated request ID, and stage a new choice before answering the old one.
  4. Launch a five-second scripted `learning-researcher`, continue with `A response has max-age 60 and Age 90. Can it be reused as fresh?`, send a learner reply while the child is busy, then inspect the accepted child ID. Launch another child, cancel that same ID, and inspect its terminal state.
  5. Attempt `recall_due` with an absolute foreign path, traversal, and a symlink escape. Ask Mentor to run `touch outside.txt`, then request the announced command `npm test` and reject its separate permission prompt.
- **Expected result:** OpenCode, Node, and helper versions are recorded; both plugins and all intended `learning_*` and `recall_*` tools load. The selected value is exactly `none`, bound to the shown display, session, call, and request; replay, forgery, and stale replies select nothing. The useful teaching question appears before the delayed child completes, learner input is accepted while it is busy, completion creates no unsolicited parent turn, and inspection returns the bounded final result. Cancellation settles the accepted child. Foreign reads and broad writes fail; the test command is separately gated. Scripted timing is labeled protocol evidence, not model latency or teaching quality.
- **Essential negative variant:** Remove the host async session methods in a copied fixture and expect `async_session_api_unavailable`, with no synchronous substitute. Remove the installed tool helper and expect `learning_tool_helper_unavailable`, not silently missing tools.
- **Cleanup:** Stop the disposable host and provider. Remove their temporary project, config, and XDG roots; do not sync them to a global target.

### MT-LEARNING-SESSION

- **Title:** Teach one concept without durable state
- **Coverage key:** `learning/session/ephemeral-teaching`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/skills/learning-session/**`
- **Preconditions:** Start a fresh disposable project with no `.ai/learning/` directory.
- **Steps:**
  1. Run `/learn session Explain why HTTP is stateless. Use one original example, then ask me one question.`
  2. Answer `The server can handle the request from its contents rather than remembering my previous request.` and end without asking to save.
  3. Inspect the project, including hidden files.
- **Expected result:** Mentor answers first in the conversation language, uses a distinct example, asks one focused question, and responds to the actual answer. It performs no due-check and creates no Learning directory, mission, summary, card, or other state.
- **Cleanup:** Close the session and remove the disposable project.

### MT-LEARNING-PATH

- **Title:** Create a durable learning path
- **Coverage key:** `learning/path/durable-creation`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Start a fresh disposable project with the installed runtime available.
- **Steps:**
  1. Run `/learn path HTTP cache validation. My goal is to decide whether a cached response can be reused, revalidated, or refetched. Keep materials in Spanish.`
  2. Correct or accept the proposed observable mission, scope, and cadence through the native mission choice.
  3. Inspect `.ai/learning/<topic>/.state.json`, `mission.md`, `path.md`, `review-queue.md`, `vocabulary.md`, and `gaps.md`.
- **Expected result:** The runtime creates schema version 1 state and generated views at the same current revision. Concepts have stable `K-####` IDs and prerequisite links. The default fundamental shortlist is at most `floor(concept_count / 5)` without padding. The path has tangible module wins and uncompleted phases; no repository source is modified.
- **Essential negative variant:** Create a topic directory containing Markdown but no `.state.json`, then request that topic. The mutation stops with `unsupported_existing_topic_without_state` and changes no existing file.
- **Cleanup:** Remove the disposable Learning state and project.

### MT-LEARNING-MODULE-DELIVERY

- **Title:** Teach and consolidate a durable module
- **Coverage key:** `learning/module/explanation-progression`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/learning-writer.md`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/cornell-notes/**`, `domains/learning/skills/feynman-teachback/**`
- **Preconditions:** Use a disposable five-concept topic whose current module is `Freshness and validation`, with only `K-0001 Freshness decision` marked fundamental and no due cards.
- **Steps:**
  1. Run `/learn path http-cache-validation` and answer the Class question `Age 90 exceeds max-age 60, so the response is stale and cannot be reused as fresh.`
  2. At the post-Class card preview choose `Save none`. At the separate readiness question choose `I need clarification`, ask `How does ETag change the stale-response decision?`, then later reply `I am ready to practice.`
  3. Solve the new case with `A stale response with an ETag can be conditionally revalidated. A 304 lets the cache reuse the body; a changed representation requires the new body.`
  4. Explain the causal decision and one transfer case in your own words. Inspect the state and generated views after Close.
- **Expected result:** Class contains the objective, central relationships, a different worked example, and one learner question. Card refusal records retention `none` without starting Practice. Clarification keeps the module in Class; the later readiness event starts Practice. The attempt and causal explanation are actual learner evidence and may satisfy Consolidation without redundant rituals. The module closes with no blocking gap and an empty selected-card list. A writer result is reported as saved only after its exact source revision and content commit.
- **Essential negative variant:** Delay the writer, advance state with a valid learner event, then return the old output. The old artifact is rejected; teaching already supported by committed state may continue. A current-revision writer can later commit the artifact.
- **Cleanup:** Remove the disposable topic and project.

### MT-LEARNING-AMBIGUOUS-ROUTE

- **Title:** Choose a learning route before state access
- **Coverage key:** `learning/routing/ambiguous-topic`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-session/**`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Use a disposable project with one initialized durable topic and a Spanish conversation.
- **Steps:**
  1. Run `/learn pizza` and inspect visible tool activity before answering.
  2. Choose the localized one-off option and continue for one teaching exchange.
  3. Repeat in a fresh session and choose the durable option.
- **Expected result:** One localized closed choice appears before any skill, date, due-check, or state read. The one-off selection loads only `learning-session` and creates no state. The durable selection loads `learning-loop`, then reads the relevant initialized topic. Existing state is never used to infer the route.
- **Cleanup:** Close both sessions and remove the disposable project.

### MT-LEARNING-SUMMARY-LIFECYCLE

- **Title:** Save a one-off summary through exclusive creation
- **Coverage key:** `learning/summary/background-lifecycle`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-summarizer.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-session/**`, `domains/learning/skills/cornell-notes/**`
- **Preconditions:** Complete a one-off session in a disposable project; no summary has been requested yet.
- **Steps:**
  1. Say `Save an independent summary of this session in Spanish`, approve the exact native save choice, and immediately ask `How would this apply to a shared cache?`.
  2. On a later normal message inspect the accepted summarizer ID and create the summary from its completed JSON result.
  3. Through the protocol fixture, call `learning_summary_create` again with the same interaction and job. Then repeat the whole save flow with the same title during the same second.
- **Expected result:** Teaching continues while one bounded summarizer runs. Completion produces no standalone parent turn; one correlated notice appears on a later real message. The first save creates one localized Cornell summary under `.ai/learning/summaries/`. Reusing its interaction fails with `summary_interaction_already_used`. A second explicit save gets a distinct collision-resistant path and does not overwrite the first. Neither file creates route state or cards.
- **Essential negative variant:** Return malformed summarizer JSON. Creation fails once with no file, model retry, foreground fallback, or false saved-path claim.
- **Cleanup:** Remove both generated summaries and the disposable project.

### MT-LEARNING-DURABLE-REVIEW

- **Title:** Persist review grades without model writers
- **Coverage key:** `learning/review/background-persistence`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/plugins/recall-calc.ts`, `domains/learning/skills/spaced-recall/**`
- **Preconditions:** Use a disposable topic containing two due active cards with valid anchors and no pending topic lock.
- **Steps:**
  1. Run `/learn review <topic>`, answer the oldest cue, inspect the evidence-based grade recommendation, and choose `Again` through the native grade choice.
  2. Answer and grade the second cue. Inspect `.state.json`, `review-queue.md`, and the event IDs.
  3. Restart the session and produce the second cumulative `Again` for the first card. On the next failed recall choose the offered `reformulate` or `split` action and inspect lineage.
- **Expected result:** Each grade is one fast revision-checked runtime commit; no per-grade model writer is launched. Only learner input advances cues. State and the queue show the same dates and boxes. On the third cumulative failure, a plain grade is rejected until a correlated repair choice retires the old card and allocates new ID or IDs with lineage and fresh failure count.
- **Essential negative variant:** Submit two different grade events concurrently at the same expected revision. Exactly one commits; the other reports a revision conflict and cannot overwrite it.
- **Cleanup:** Remove the disposable topic and project.

### MT-LEARNING-ENGLISH

- **Title:** Correct English only on request
- **Coverage key:** `learning/english/explicit-coaching`
- **Applies to:** `domains/learning/agents/english-tutor.md`, `domains/learning/commands/english.md`, `domains/learning/skills/english-tutor/**`, `domains/learning/plugins/learning-runtime.ts`
- **Preconditions:** Use a disposable project. An initialized English topic is optional.
- **Steps:**
  1. Run `/english I have worked here since three years` and answer the focused retry.
  2. If a recurring category is offered, approve only the synthetic gap adoption and inspect `gaps.md`.
  3. Continue an unrelated coding conversation without invoking `/english`.
- **Expected result:** The reply preserves intent, gives the correction, concise reason, natural alternatives, and a useful retry. With opt-in, durable state contains only a category, invented generic pattern, and distinct occurrence references; it contains no raw sentence or correction history. Gap adoption does not schedule a card. Unrelated conversation receives no unsolicited correction or write.
- **Cleanup:** Remove the disposable gap/topic and project.

### MT-LEARNING-RECALL

- **Title:** Calculate due cards and Leitner transitions
- **Coverage key:** `learning/recall/leitner-schedule`
- **Applies to:** `domains/learning/plugins/recall-calc.ts`, `domains/learning/skills/spaced-recall/**`, `domains/learning/agents/mentor.md`
- **Preconditions:** Use a disposable queue with one overdue box-2 card, one future card, and one retired card under `## Suspended / retired`; set today to `2026-09-05`.
- **Steps:**
  1. Invoke installed `recall_due` and confirm only the overdue active card is offered, oldest first.
  2. Grade the box-2 card `Good` and inspect box, Last, Next, and next-upcoming. Exercise every grade/box combination plus `2024-02-28 + 1 day` and `2026-12-31 + 1 day` through `recall_schedule`.
  3. Add an escaped pipe in a cue, a duplicate active ID, an impossible Last/Next relation, and a malformed row, one at a time.
  4. Grade a box-5 active card `Good`, then explicitly suspend it through the Learning choice and commit flow.
- **Expected result:** Good moves box 2 to box 3 with Next `2026-09-12`; date boundaries are `2024-02-29` and `2027-01-01`. Escaped pipes parse as cue text. Duplicates, inconsistent dates, and malformed rows remain visible in `malformed` and are not scheduled. The retired table is ignored by active parsing. Good at box 5 schedules another 30-day maintenance interval; only explicit suspension removes it from due work.
- **Cleanup:** Remove the disposable queue and project.

### MT-LEARNING-STANDALONE-SKILLS

- **Title:** Invoke every Learning skill independently
- **Coverage key:** `learning/skills/standalone-output`
- **Applies to:** `domains/learning/skills/**`
- **Preconditions:** Prepare nine isolated config targets, each containing exactly one Learning skill directory and its own assets, with no Mentor, sibling skills, plugins, or `.ai/learning/` directory.
- **Steps:**
  1. Invoke each skill once with explicit inputs: `Teach HTTP statelessness inline`; `Propose one mission-grounded path step for cache validation`; `Create Cornell Markdown from these two verified notes`; `Quiz these two supplied cue-answer pairs`; and `Run a teach-back on cache freshness`.
  2. Invoke the language skills with `Teach this English/Spanish airport dialogue`; `Run delayed retranslation for this supplied bilingual unit due today`; `Draft two English/Spanish Anki candidate rows for airport check-in`; and `Correct: I have worked here since three years`.
  3. Inspect each output and every isolated project directory.
- **Expected result:** Each skill returns a useful inline teaching or transformation result from explicit inputs and only its own optional assets. No invocation discovers a project, calls a sibling, requires Mentor, or creates state. Cornell distinguishes teacher notes from learner evidence; recall accepts supplied non-Cornell answers; English returns only optional synthetic gap data; BDT and Anki require an explicit destination before proposing any save.
- **Cleanup:** Remove all nine isolated targets and projects.

### MT-LEARNING-STATE-RECOVERY

- **Title:** Recover deterministic topic state and writer results
- **Coverage key:** `learning/state/revision-recovery`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/learning-writer.md`
- **Preconditions:** Use the scripted provider with an initialized disposable topic at a known revision.
- **Steps:**
  1. Apply one event twice with the same event ID and body, then try that ID with a different body. Submit two distinct events concurrently at the same expected revision.
  2. Stop view generation after the authoritative state replacement or remove one generated view while its state says pending. Restart and invoke `learning_recover`.
  3. Launch a writer at revision N, advance state to N+1, and attempt to attach the old result. Launch a writer at the current revision, let it complete, restart OpenCode before attachment, then inspect its persisted child ID from a new parent session and attach the exact output.
  4. Create a stale lock whose recorded PID is dead, then repeat with a live PID or malformed lock.
- **Expected result:** Identical replay is a duplicate with no new IDs or revision; conflicting replay fails. One concurrent event wins. Recovery regenerates views from committed state without reapplying the event. A stale writer cannot attach. A completed current writer survives process restart through its stored topic ownership and host session, and a new parent can commit its exact result. A dead-PID lock is recovered once; live or ambiguous locks stop with no write.
- **Cleanup:** Stop the host and remove only the disposable state and config.

### MT-LEARNING-CARD-ADMISSION

- **Title:** Admit only the cards the learner confirms
- **Coverage key:** `learning/cards/interactive-admission`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/mentor.md`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/spaced-recall/**`
- **Preconditions:** Prepare copies of a five-concept Class state with one taught fundamental concept and zero to two eligible card previews.
- **Steps:**
  1. In separate copies, select one card from two, select `Save none`, and select `Decide later` from the exact shown previews. Inspect the stored preview JSON and digest passed to each native choice, and compare the runtime-rendered question with that JSON.
  2. Choose `Edit C-0001`, commit and inspect the proposed cue and answer, then confirm its exact change JSON, ID, and digest. Repeat with a reformulation or split after two recorded `Again` events. In another copy, clarify the teaching so the source revision changes before answering the old preview.
  3. Replay an answered host request and submit a model-authored event containing `approved: true` but no correlated interaction.
  4. For a topic with fewer than five concepts, request an explicit learner override for one shown taught concept and inspect the shortlist.
- **Expected result:** Final IDs are allocated only at commit for the exact selected proposals. None and deferred create no card and remain independent of module progress. Selection and every replacement require the digest of the exact stored content; a different digest cannot authorize the mutation. An edit or repair retires the former ID and creates confirmed replacement IDs with lineage. Changed teaching invalidates the old preview. Replayed, stale, partial, extra, and asserted approvals cannot save content. The default small-topic shortlist is zero; the explicit override is recorded without relabeling the default budget.
- **Cleanup:** Remove every disposable state copy.

### MT-LEARNING-LANGUAGE-PROGRESSION

- **Title:** Drain finite language courses by due date
- **Coverage key:** `learning/language/date-progression`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/language-loop/**`, `domains/learning/skills/bidirectional-translation/**`
- **Preconditions:** Create disposable language topics containing 1, 5, and 6 finite units, all passively seen on `2026-09-01` with initial due date `2026-09-04`. Mark production required.
- **Steps:**
  1. Query due work on `2026-09-01`, `2026-09-03`, and `2026-09-04` for every course size.
  2. On the due date, give a gist-only response for one unit, a meaning-changing production attempt for another, and a meaning-preserving natural equivalent for another.
  3. Choose input-only for one due unit, query due work again, then later supply meaning-preserving production for it.
  4. Finish all new passive units and continue querying until every active tail unit is completed; attempt topic completion before and after production criteria are met.
- **Expected result:** Unit count never makes same-day work due; every unit first becomes due after three days. Gist/input-only remains valid evidence but does not satisfy required production. A material error records `needs-another-attempt` with a future date. Input-only stays eligible for later productive practice. One-, five-, and six-unit courses expose and drain their final due units without unit zero or an invented five-unit buffer. Completion is blocked until all production-required units are completed.
- **Cleanup:** Remove the three disposable topics and project.

### MT-LEARNING-VOCAB-EXPORT

- **Title:** Export only selected vocabulary candidates once
- **Coverage key:** `learning/vocabulary/selected-export`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/anki-vocab/**`, `domains/learning/skills/language-loop/**`
- **Preconditions:** Use a disposable English/Spanish topic with a known phrase inventory and no export for `check in`.
- **Steps:**
  1. Run `/learn vocab airport check-in` and inspect proposed natural phrase rows before selection.
  2. Submit candidates `check in` and `boarding pass`, then select only `check in` through the native export choice.
  3. Inspect state, `vocabulary.md`, and the generated semicolon batch. Replay the same event, then propose `CHECK   IN` for English and `check in` for another target language.
- **Expected result:** Candidates are distinct from exports. One event atomically marks only the selected English candidate exported and writes its exact five-field row; identical replay adds nothing. NFKC, lowercase, and whitespace normalization suppresses the English duplicate while preserving a distinct target-language key. No Leitner card or Anki-import claim is created automatically.
- **Essential negative variant:** Make the first batch field differ from the candidate unit after normalization or include quotes, newlines, or the wrong field count. The whole event fails without a partial registry or file.
- **Cleanup:** Remove the disposable topic and batch.

### MT-LEARNING-MODEL-VARIANCE

- **Title:** Compare model teaching without weakening state rules
- **Coverage key:** `learning/models/protocol-variance`
- **Applies to:** `domains/learning/agents/**`, `domains/learning/commands/**`, `domains/learning/skills/**`, `domains/learning/plugins/**`
- **Preconditions:** Obtain explicit credit authorization. Copy identical empty and initialized snapshots. Choose one inexpensive available model; choose one stronger model only under separate authorization. Record exact model IDs, timestamps, and costs.
- **Steps:**
  1. Run exactly these cases once per authorized model: the MT-LEARNING-SESSION prompt; MT-LEARNING-MODULE-DELIVERY through decline-all; MT-LEARNING-CARD-ADMISSION through one selected edit; one due review; the final unit and export from the language cases; and one standalone skill prompt.
  2. Score central correctness, causal explanation, distinct example, learner attempt, focused feedback, and novel application. Compare resulting event/state diffs separately from prose.
  3. Record time to the next useful learner-facing question, total completion time, parent and child context, and model cost.
- **Expected result:** Every authorized run preserves interaction provenance, IDs, dates, phase gates, privacy, and write boundaries. Teaching quality and wording may vary and are reported by rubric and sample, without a universal model-invariance claim. A protocol pass does not substitute for semantic quality; missing authorization leaves this case explicitly pending.
- **Cleanup:** Delete only copied snapshots and disposable model sessions; preserve concise evidence outside learner state.

### MT-LEARNING-DELAYED-RETENTION

- **Title:** Observe delayed retrieval without inferred outcomes
- **Coverage key:** `learning/retention/delayed-observation`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/spaced-recall/**`
- **Preconditions:** A learner completes one consented foundational card and one transfer exercise on day 0. Record the actual dates; learner participation is required on days 7 and 30.
- **Steps:**
  1. On day 0, record only the demonstrated explanation and transfer evidence; do not predict retention.
  2. On day 7, ask the original cue without hints, record the answer and chosen grade, then use a new application prompt.
  3. On day 30, repeat with another new application and record the answer before feedback.
- **Expected result:** Each observation records what the learner actually retrieved and transferred on that date. Missing, late, or skipped sessions remain pending; confidence, immediate correctness, scheduled dates, and model judgments never become fabricated 7- or 30-day outcomes.
- **Cleanup:** Keep the learner-authorized durable record; remove only disposable copies used to inspect the case.
