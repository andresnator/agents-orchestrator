# Learning manual tests

Run these cases in a disposable OpenCode project. Keep deterministic protocol evidence separate from model behavior and human learning evidence. Durable cases may write only under the disposable project's `.ai/learning/` directory. When several cases must run side by side with isolated targets, a Herdr session with one pane per case keeps the runs separated; scripted loopback providers are protocol evidence, and real-model runs (for example the pre-authorized `Astra` and `Luna` presets) are recorded separately from deterministic results.

## Quick path

1. Install only the current checkout's `learning` domain into a fresh target.
2. Run the affected IDs listed in the pull request, one exact prompt sequence per case.
3. Inspect `.ai/learning/`, including hidden files, and record the OpenCode/model versions actually used.
4. Stop the disposable services and remove only their temporary target.

### MT-LEARNING-RUNTIME

- **Title:** Verify installed runtime, retired surfaces, and host interaction boundaries
- **Coverage key:** `learning/runtime/host-capabilities`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/plugins/recall-calc.ts`, `domains/learning/agents/mentor.md`, `domains/learning/agents/english-tutor.md`
- **Preconditions:** Install only `learning` into a fresh target. Select it with `OPENCODE_CONFIG_DIR` plus isolated XDG config, data, state, and cache directories. Set `OPENCODE_DISABLE_PROJECT_CONFIG=true`, `OPENCODE_DISABLE_EXTERNAL_SKILLS=true`, and `OPENCODE_DISABLE_CLAUDE_CODE=true`. Use a scripted loopback provider and no model credentials. For an upgrade check, first install an older checkout that still ships the recall plugin, then reinstall from this checkout over the same target.
- **Steps:**
  1. Inspect `opencode debug agent mentor`, `opencode debug agent english-tutor`, `/doc`, and `/experimental/tool?provider=<fixture-provider>&model=<fixture-model>`. Invoke `learning_context` and `learning_event_reference` for `create_topic` through the installed host.
  2. Verify the exposed tools are exactly the learning set: `learning_context`, `learning_event_reference`, `learning_state_read`, `learning_commit`, `learning_recover`, `learning_evidence`, `learning_choice`, `learning_choice_result`, `learning_job_start`, `learning_job_result`, and `learning_summary_create`. Verify `recall_due`, `recall_schedule`, and `learning_due` are absent, `learning_context` reports no `calculator`, and the event catalog contains no card, grade, preview, or scheduling events. On the upgraded target, confirm the installer removed the managed `recall-calc` plugin and `spaced-recall` skill files.
  3. Stage the exact prompt `Omit practice for this module?` with `Omit` and `Practice`. Omit `multiple`, inspect the `not_shown` response, and call `learning_choice_result` once before showing anything. Both responses must direct `question` with exact `next_args`. Open it and reply `Omit` through the host endpoint or UI.
  4. Stage questions of exactly 300 and 301 characters: accept 300 unchanged and reject 301 before UI without truncation. Attempt to reuse consent for altered content, replay that request ID, and stage a new choice before answering the old one.
  5. Launch a five-second scripted `learning-researcher` and verify `learning_job_start` stays pending until its terminal output. Attempt a writer or summarizer in the same parent while it runs; no second child may start. Continue with the returned result in the same turn. Launch another child, cancel the parent, and verify child settlement; simulate transport loss and recover the same ID with a waiting `learning_job_result`.
  6. Ask Mentor to run `touch outside.txt`, then request the announced command `npm test` and reject its separate permission prompt.
- **Expected result:** OpenCode, Node, and helper versions are recorded; the runtime plugin loads with all intended `learning_*` tools and no recall or due tools. Retired operations fail explicitly instead of silently no-op. Invalid writer assignments (missing artifact/method, multiple artifacts, wrong destination, or module) fail before child creation. The event reference returns the exact discriminated payload and consent subject without requiring Mentor to guess erased TypeScript types. An unshown choice reports `not_shown` with the exact next tool call; staging never claims the UI is open. Omitting `multiple` defaults to a single choice, bound to the shown display, session, call, and request; replay, forgery, and stale replies select nothing. `learning_context` announces `sequential_jobs`. The delayed tool call stays pending and returns the complete terminal result without a learner continuation. Cancellation reaches the accepted child. Transport errors never prove completion or authorize an unchecked replacement. Foreign reads and broad writes fail; the test command is separately gated. Scripted timing is labeled protocol evidence, not model latency or teaching quality.
- **Essential negative variant:** Remove the host `session.prompt` method in a copied fixture and expect `sequential_session_api_unavailable`, with no child created. Remove the installed tool helper and expect `learning_tool_helper_unavailable`, not silently missing tools. Submit a `grade_card` or `preview_cards` event to `learning_commit` and expect `unsupported_event_type` with unchanged state.
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
- **Expected result:** Mentor answers first in the conversation language, uses a distinct example, asks one focused question, and responds to the actual answer. It performs no due-check and creates no Learning directory, mission, summary, or other state.
- **Cleanup:** Close the session and remove the disposable project.

### MT-LEARNING-PATH

- **Title:** Create a durable learning path
- **Coverage key:** `learning/path/durable-creation`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Start a fresh disposable project with the installed runtime available.
- **Steps:**
  1. Run `/learn path HTTP cache validation. My goal is to decide whether a cached response can be reused, revalidated, or refetched. Keep materials in Spanish.`
  2. Correct or accept the proposed observable mission, scope, and cadence through the native mission choice.
  3. In a fresh session, run `/learn quiero que me crees un path para aprender patrones de disenio` and accept the proposed scope. In an ambiguous-route session, reply `path de aprendizaje` directly in chat.
  4. In fresh disposable projects, request an extensive Java path covering basics, OOP, collections, exceptions, streams, concurrency, testing, and JVM tooling, with a goal and weekly cadence. Check the formatted proposal in chat and a native confirmation of at most 300 characters with visible Create, Revise, and Cancel options and no appended JSON. Confirm creation in one project and cancel in another.
  5. Inspect `.ai/learning/<topic>/.state.json`, `mission.md`, `path.md`, `vocabulary.md`, and `gaps.md`, and verify no `review-queue.md` is generated.
- **Expected result:** Natural-language path requests select the durable route without a redundant session/path choice; a later explicit chat answer resolves routing without polling consent. The runtime creates schema version 1 state and generated views at the same current revision. Concepts have stable `K-####` IDs and prerequisite links, without a fundamental quota or padding. The path has tangible module wins and uncompleted phases; no repository source is modified.
- **Essential negative variant:** Reject the mission, omit consent, or reuse approval for a different topic or changed proposal; no topic directory may be created. A corrected proposal requires a new native choice. Create a topic directory containing Markdown but no `.state.json`, then request that topic. The mutation stops with `unsupported_existing_topic_without_state` and changes no existing file.
- **Cleanup:** Remove the disposable Learning state and project.

### MT-LEARNING-MODULE-DELIVERY

- **Title:** Teach and consolidate a durable module
- **Coverage key:** `learning/module/explanation-progression`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-writer.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/cornell-notes/**`, `domains/learning/skills/feynman-teachback/**`
- **Preconditions:** Use a disposable topic whose current module is `Freshness and validation` in Mission phase. No due cards, previews, or grades exist anywhere in the flow.
- **Steps:**
  1. Run `/learn path http-cache-validation` and answer the Class question `Age 90 exceeds max-age 60, so the response is stale and cannot be reused as fresh.`
  2. Immediately after Class, find the single Practicar / Omitir readiness choice. Request clarification or dismiss it, then ask `How does ETag change the stale-response decision?`. Confirm `Practicar` through the native readiness choice.
  3. Solve the new case with `A stale response with an ETag can be conditionally revalidated. A 304 lets the cache reuse the body; a changed representation requires the new body.`
  4. Explain the causal decision and one transfer case in your own words. Inspect the writer assignment the runtime builds (via the scripted provider log): `approved_outline`, `teaching_assessment`, `practice_status`, and `learner_evidence` must be separate fields, with learner words only from `learner_evidence` references. Have the writer load `cornell-notes` with reads denied; check the loaded skill includes the full lesson template, and `learning-loop` includes the full exercise template. Inspect the state and generated views after Close.
  5. Repeat with native `Omitir` from Class and after a partial attempt; provide a brief explanation and compare all generated paths, sections, and table columns. Complete the final module against the agreed mission criteria, restart, and regenerate views.
- **Expected result:** The initialized fixture is read and resumed before any mission proposal. Readiness is offered once directly after Class; clarification keeps the module in Class, and the later readiness event starts Practice. After Consolidation, Mentor automatically commissions and attaches the Cornell note, then commissions the learning-loop exercise at the new revision and attaches it before Close in the same turn, without a “continue” message or another materials request. The attempt and causal explanation are actual learner evidence and may satisfy Consolidation without redundant rituals. The module closes with no blocking gap; there is no retention decision anywhere in the flow. Omission records optional `practice_skipped`, preserves partial attempts, and never fabricates completed practice. Resume reuses the recorded decision. Both materials still exist with omission in existing fields; no default capstone is imposed or practical competence credited without evidence. Mentor-only explanations and the assignment outline never appear as learner quotes; the note and exercise quote the learner only from the supplied `learner_evidence` references, and empty references render as pending evidence. Practice and Consolidation store verified `evidence_refs` from real learner messages. A writer result is reported as saved only after its exact source revision and content commit. Sufficient evidence is reused without another exercise; only an uncovered criterion is asked. Sufficient mission evidence quotes, provenance, completion date, and event ID survive restart in `topic.completion` and the generated mission completion record.
- **Essential negative variant:** Submit fake message/part IDs, altered quotes, synthetic text, worker text and unstored foreign-session references; every rejection leaves state unchanged. Restart and complete with references already verified in the same topic, even with original history unavailable; replay the identical event without another write. Read old schema-1 states without migration, promoting historical narrative, or changing prior completion. Reject stale, wrong-module, unshown, dismissed, or wrong-option skip consent. Delay the writer, advance state with a valid learner event, then return the old output. The old artifact is rejected; teaching already supported by committed state may continue. A current-revision writer can later commit the artifact. A writer result that still carries `selected_card_ids` is rejected with `unexpected_writer_retention`.
- **Cleanup:** Remove the disposable topic and project.

### MT-LEARNING-INDEPENDENT-EVIDENCE

- **Title:** Save independent learner evidence without an attempt or consolidation
- **Coverage key:** `learning/runtime/independent-evidence`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/mentor.md`
- **Preconditions:** Install only `learning` into a fresh disposable project and use the scripted loopback provider for protocol evidence; record real-model runs separately with their versions. Start a durable topic and reach Class without recording an attempt or consolidation.
- **Steps:**
  1. Create or resume the durable topic, reach Class, and have the learner produce a real answer to the Class question.
  2. Call `learning_evidence` with one literal excerpt from that answer and inspect the returned `evidence_refs`.
  3. Start a teach-back writer job through `learning_job_start`, passing the returned selection as `artifact.evidence_refs`; include one variant without `module_id` and one with the module owner.
  4. Attach the writer result through the normal save and `attach_artifact` protocol.
  5. Inspect the writer assignment, `.ai/learning/<topic>/.state.json`, and the saved teach-back file.
- **Expected result:** The writer assignment's `learner_evidence` equals exactly the selected references. Phase, attempts, consolidation, and competency assessment are unchanged, and `verified_evidence` is unchanged with no auto-add. The save follows the normal writer result and `attach_artifact` protocol. Scripted-provider labels distinguish protocol evidence from model behavior.
- **Essential negative variant:** Submit altered quotes, synthetic text, assistant text, foreign-session references, duplicates, and an empty list. Every rejection occurs before worker creation with state and jobs unchanged. With `evidence_refs` omitted, the automatic module selection still applies, and a module without available evidence stays pending.
- **Cleanup:** Remove the disposable topic and project.

### MT-LEARNING-FLEXIBLE-PATH

- **Title:** Revise scope and defer modules without crediting unobserved competence
- **Coverage key:** `learning/progression/flexible-path`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/plugins/learning-runtime.test.mjs`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Use an isolated project with an active schema-1 topic. One module has skipped practice, verified theoretical explanations, materials, and a practical blocking gap; a later module also requires the practical deliverable. Do not use a real learner topic.
- **Steps:**
  1. Say `Quiero plugins únicamente teóricos; retira también la obligación de incorporarlos en el módulo siguiente.` Inspect the complete scope proposal and approve the native choice.
  2. Let Mentor reuse the verified explanations, reassess the revised win, refresh both materials, and close the module without inventing practical evidence. Restart and inspect scope history and regenerated views.
  3. In another unfinished module, say `Necesito pasar al siguiente ahora; deja este aplazado.` Approve navigation before completing practice or materials, restart, and later request the deferred module.
  4. In a module still in Mission, supply a sufficient explanation and ask to omit redundant teaching and practice. Approve omission; deliver materials before closure.
- **Expected result:** Scope revision updates the goal and affected wins atomically with exact native consent. Old goals, wins, assessments, citations and retired requirements remain traceable. Retired practice is not described as mastered or still mandatory. Reassessment and current materials remain necessary for Close. Navigation persists the selected module, preserves deferred phases and evidence, and does not impose prerequisite gates or require materials. Resume honors the selection. Prior knowledge can reach Consolidation without a fictitious Class or practice; only actual verified learner evidence supports closure. Legacy snapshots remain readable.
- **Essential negative variant:** Cancel or alter either proposal, replay it against a newer revision, or substitute another module; state does not change. A changed scope with an old gap-free assessment still cannot close. A remaining conceptual gap blocks Close. Deferred modules block topic completion. A stale writer result cannot overwrite current material. Do not retry an already recorded omission or require repeated explanations merely after restart.
- **Cleanup:** Remove only the isolated project and target.

### MT-LEARNING-AMBIGUOUS-ROUTE

- **Title:** Choose a learning route before state access
- **Coverage key:** `learning/routing/ambiguous-topic`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-session/**`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Use a disposable project with one initialized durable topic and a Spanish conversation.
- **Steps:**
  1. Run `/learn pizza` and inspect visible tool activity before answering.
  2. Choose the localized one-off option and continue for one teaching exchange.
  3. Repeat in a fresh session and choose the durable option. Repeat once more, dismiss the selector and give an explicit route answer in chat; verify that answer resolves the route.
- **Expected result:** One localized closed choice appears before any skill, date check, or state read. The one-off selection loads only `learning-session` and creates no state. The durable selection loads `learning-loop`, then reads the relevant initialized topic. Existing state is never used to infer the route.
- **Cleanup:** Close both sessions and remove the disposable project.

### MT-LEARNING-SUMMARY-LIFECYCLE

- **Title:** Save a one-off summary through exclusive creation
- **Coverage key:** `learning/summary/background-lifecycle`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-summarizer.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-session/**`, `domains/learning/skills/cornell-notes/**`
- **Preconditions:** Complete a one-off session in a disposable project; no summary has been requested yet.
- **Steps:**
  1. Say `Save an independent summary of this session in Spanish`, approve the exact native save choice, and send no additional message.
  2. Verify that the summarizer call waits for completion and Mentor immediately creates the summary from its complete JSON in that same turn. Then ask `How would this apply to a shared cache?`.
  3. Through the protocol fixture, call `learning_summary_create` twice concurrently with the same interaction and job, then call it again after settlement. Repeat the whole save flow with the same title during the same second.
- **Expected result:** The segment ends at the original save request. One bounded summarizer is awaited and saved with the retained approval in the same turn; later messages neither extend nor invalidate that segment. No continuation, extra save request, or deferred notice is needed. Exactly one concurrent call creates one localized Cornell summary under `.ai/learning/summaries/`; the other and later reuse fail with `summary_interaction_already_used`. A second explicit save gets a distinct collision-resistant path and does not overwrite the first. Neither file creates route state or durable progress.
- **Essential negative variant:** Return malformed summarizer JSON. Creation fails once with no file, model retry, foreground fallback, or false saved-path claim.
- **Cleanup:** Remove both generated summaries and the disposable project.

### MT-LEARNING-REVIEW-ONDEMAND

- **Title:** Review only on explicit request without calendar or grades
- **Coverage key:** `learning/review/on-demand`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/cornell-notes/**`
- **Preconditions:** Use a disposable topic with at least one closed module whose note contains Cornell questions, and no pending topic lock.
- **Steps:**
  1. Restart a session on the topic and run `/learn review <topic>`. Verify Mentor does not propose any due list, dates, boxes, or grades; it supplies the Cornell questions or a fresh retrieval pass from existing material.
  2. Answer two retrieval questions. Verify feedback is inline teaching only and no `learning_commit` runs; no durable event, grade, or date is recorded.
  3. Run `/learn review <topic>` again the next day and confirm the second pass is identical in shape: self-contained questions, no accumulated calendar, no Leitner state.
  4. Ask for a quiz and a drill in the same topic and verify both behave the same way: inline practice resources, no scheduling proposals.
- **Expected result:** Review is a one-off, learner-requested retrieval pass. Nothing proposes due work, nothing records a grade, and no `review-queue.md` is created or regenerated; an existing historical `review-queue.md` stays untouched. Cornell questions, quizzes, teach-backs, and drills remain ordinary practice resources with no persistence side effects.
- **Essential negative variant:** Ask Mentor to `grade my recall` or `schedule reviews`; it explains that scheduling and grades are retired, offers on-demand practice instead, and commits nothing. Invoke the removed `recall_due` tool name; the host reports it as unavailable.
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
- **Expected result:** The reply preserves intent, gives the correction, concise reason, natural alternatives, and a useful retry. With opt-in, durable state contains only a category, invented generic pattern, and distinct occurrence references; it contains no raw sentence or correction history. Gap adoption schedules nothing. Unrelated conversation receives no unsolicited correction or write.
- **Cleanup:** Remove the disposable gap/topic and project.

### MT-LEARNING-STANDALONE-SKILLS

- **Title:** Invoke every Learning skill independently
- **Coverage key:** `learning/skills/standalone-output`
- **Applies to:** `domains/learning/skills/**`
- **Preconditions:** Prepare eight isolated config targets, each containing exactly one Learning skill directory and its own assets, with no Mentor, sibling skills, plugins, or `.ai/learning/` directory.
- **Steps:**
  1. Invoke each skill once with explicit inputs: `Teach HTTP statelessness inline`; `Propose one mission-grounded path step for cache validation`; `Create Cornell Markdown from these two verified notes`; `Quiz these two supplied cue-answer pairs`; and `Run a teach-back on cache freshness`.
  2. Invoke the language skills with `Teach this English/Spanish airport dialogue`; `Run a retranslation drill for this supplied bilingual unit`; `Draft two English/Spanish Anki candidate rows for airport check-in`; and `Correct: I have worked here since three years`.
  3. Inspect each output and every isolated project directory.
- **Expected result:** Each skill returns a useful inline teaching or transformation result from explicit inputs and only its own optional assets. No invocation discovers a project, calls a sibling, requires Mentor, or creates state. Cornell distinguishes teacher notes from learner evidence and marks missing learner evidence pending; English returns only optional synthetic gap data; BDT and Anki require an explicit destination before proposing any save. No skill proposes spaced-repetition schedules, due dates, or card storage.
- **Cleanup:** Remove all eight isolated targets and projects.

### MT-LEARNING-STATE-RECOVERY

- **Title:** Recover deterministic topic state and writer results
- **Coverage key:** `learning/state/revision-recovery`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/learning-writer.md`
- **Preconditions:** Use the scripted provider with an initialized disposable topic at a known revision.
- **Steps:**
  1. Apply one event twice with the same event ID and body, then try that ID with a different body. Submit two distinct events concurrently at the same expected revision. Submit a retired card event and verify `unsupported_event_type` with no revision change.
  2. Stop view generation after the authoritative state replacement or remove one generated view while its state says pending. Restart and invoke `learning_recover`.
  3. Launch a writer at revision N, advance state to N+1, and request the same topic/worker from another parent before settlement. Attempt to attach the old result. Launch a writer at the current revision, let it complete, restart OpenCode before attachment, then inspect its persisted child ID from a new parent session and attach the exact output.
  4. Point `.state.json` at a valid same-slug foreign-project state through a symlink and attempt a read. Create a stale lock whose recorded PID is dead and race two processes to recover it; then repeat with a live PID or malformed lock.
- **Expected result:** Identical replay is a duplicate with no new IDs or revision; conflicting replay fails. One concurrent event wins, and every resulting snapshot validates. Recovery regenerates views from committed state without reapplying the event. A stale writer cannot attach, and another parent receives the existing pending child rather than launching a second one. A completed current writer survives process restart through its stored topic ownership and host session, and a new parent can commit its exact result. Foreign state is rejected before read. Exactly one process can claim a dead lock; live, claimed, or ambiguous locks stop with no write.
- **Cleanup:** Stop the host and remove only the disposable state and config.

### MT-LEARNING-NO-SRS-COMPAT

- **Title:** Read historical spaced-repetition state without calendar behavior
- **Coverage key:** `learning/compatibility/no-calendar`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/mentor.md`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Prepare copies of a legacy schema-1 topic whose state contains cards with boxes and dates, a module retention entry (pending and selected variants), review events, historical consents with retired purposes, and language units carrying `next_due`. Also keep one real backup of a current learner topic before any migration-style test; restore it afterwards.
- **Steps:**
  1. Open each legacy copy with Mentor through the normal resume flow and verify teaching proceeds from the recorded phase; no cards, previews, grades, or due dates are offered.
  2. Close the consolidation-phase copy: attach current note and exercise and commit `close_module`. Verify closure succeeds despite pending or selected historical retention, and that `cards`, `review_events`, `retention`, and `next_due` fields are preserved byte-for-byte in the resulting `.state.json`.
  3. Record a same-day language attempt on a unit whose historical `next_due` is in the future; verify the attempt commits without a due-date rejection and stores no new scheduling field.
  4. Submit `preview_cards`, `select_cards`, `grade_card`, `preview_card_change`, `apply_card_change`, `set_card_status`, and `set_fundamental_override` through `learning_commit` against each copy and verify `unsupported_event_type` with unchanged revisions and files.
  5. Generate views (or run `learning_recover`) and verify no `review-queue.md` is written; if an old file exists, verify its bytes are unchanged.
- **Expected result:** Historical card, retention, scheduling, and consent fields are optional and readable in schema version 1, preserved across later operations, and never used to gate teaching, materials, closure, or topic completion. New state snapshots simply omit those fields. Retired operations are rejected explicitly. Existing `review-queue.md` files remain as untouched history. Real learner data is never mutated by a compatibility check.
- **Essential negative variant:** Corrupt a historical digest or add an unknown retention disposition and expect `state_malformed` on read, with no repair attempt. Send an `add_language_unit` event carrying `next_due` and expect `unexpected_next_due` with no unit created.
- **Cleanup:** Remove every disposable copy; restore the backed-up learner topic from its untouched backup.

### MT-LEARNING-LANGUAGE-PRACTICE

- **Title:** Practice language units the same day by learner choice
- **Coverage key:** `learning/language/same-day-practice`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/language-loop/**`, `domains/learning/skills/bidirectional-translation/**`
- **Preconditions:** Create disposable language topics (production required) containing 1, 5, and 6 units passively seen today, with no `next_due` fields anywhere.
- **Steps:**
  1. On the same day as passive exposure, ask to practice a unit and verify Mentor offers it in unit order without any wait, calendar, or due-date language.
  2. Give a gist-only response for one unit, a meaning-changing production attempt for another, and a meaning-preserving natural equivalent for another. Inspect the recorded outcomes and evidence.
  3. Choose input-only for one unit, then later supply meaning-preserving production for it.
  4. Finish all units and attempt topic completion before and after the production criteria are met.
- **Expected result:** Practice availability follows the learner's choice and unit order, never a date or unit count. A material error records `needs-another-attempt` without scheduling a future date. Input-only stays valid and keeps required production pending until demonstrated. One-, five-, and six-unit courses drain in unit order with no buffer or invented unit. Completion is blocked until all production-required units are completed, and allowed once they are.
- **Essential negative variant:** Submit `add_language_unit` with `next_due`; the event fails with `unexpected_next_due` and the unit is not created. Attempt topic completion while a production-required unit is input-only; completion stays blocked with no invented mastery.
- **Cleanup:** Remove the three disposable topics and project.

### MT-LEARNING-VOCAB-EXPORT

- **Title:** Export only selected vocabulary candidates once
- **Coverage key:** `learning/vocabulary/selected-export`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/anki-vocab/**`, `domains/learning/skills/language-loop/**`
- **Preconditions:** Use a disposable English/Spanish topic with a known phrase inventory and no export for `check in`.
- **Steps:**
  1. Run `/learn vocab airport check-in` and inspect proposed natural phrase rows before selection.
  2. Submit candidates `check in` and `boarding pass`, then select only `check in` through the native export choice.
  3. Edit the example or translation of unexported `boarding pass`, keeping its ID and phrase. Reject the old approval, preview the corrected row, and export it after a fresh selection. Attempt to change an exported row.
  4. Inspect state, `vocabulary.md`, and the generated semicolon batch. Replay the same event, then propose `CHECK   IN` for English and `check in` for another target language.
- **Expected result:** Candidates are distinct from exports. Consent binds the full displayed candidate rows; the event exports only the host-selected subset. Edits preserve an unexported candidate ID, invalidate old consent, and require a fresh preview; exported rows remain immutable. One event atomically marks only the selected English candidate exported and writes its exact five-field row; identical replay adds nothing. NFKC, lowercase, and whitespace normalization suppresses the English duplicate while preserving a distinct target-language key. No internal review item, review date, or Anki-import claim is created.
- **Essential negative variant:** Make the first batch field differ from the candidate unit after normalization or include quotes, newlines, or the wrong field count. The whole event fails without a partial registry or file.
- **Cleanup:** Remove the disposable topic and batch.

### MT-LEARNING-MODEL-VARIANCE

- **Title:** Compare model teaching without weakening state rules
- **Coverage key:** `learning/models/protocol-variance`
- **Applies to:** `domains/learning/agents/**`, `domains/learning/commands/**`, `domains/learning/skills/**`, `domains/learning/plugins/**`
- **Preconditions:** Obtain explicit credit authorization. Copy identical empty and initialized snapshots. Choose one inexpensive available model; choose one stronger model only under separate authorization. Record exact model IDs, timestamps, and costs.
- **Steps:**
  1. Run exactly these cases once per authorized model: the MT-LEARNING-SESSION prompt; MT-LEARNING-MODULE-DELIVERY through readiness declined and one consolidation; MT-LEARNING-REVIEW-ONDEMAND through two answered questions; one same-day language practice with input-only; one vocab export; and one standalone skill prompt.
  2. Score central correctness, causal explanation, distinct example, learner attempt, focused feedback, and novel application. Compare resulting event/state diffs separately from prose.
  3. Record time to the next useful learner-facing question, total completion time, parent and child context, and model cost.
- **Expected result:** Every authorized run preserves interaction provenance, IDs, dates, phase gates, privacy, and write boundaries, and never reintroduces card previews, grades, or scheduling. Teaching quality and wording may vary and are reported by rubric and sample, without a universal model-invariance claim. A protocol pass does not substitute for semantic quality; missing authorization leaves this case explicitly pending.
- **Cleanup:** Delete only copied snapshots and disposable model sessions; preserve concise evidence outside learner state.

### MT-LEARNING-DELAYED-RETENTION

- **Title:** Observe delayed retrieval without inferred outcomes
- **Coverage key:** `learning/retention/delayed-observation`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/cornell-notes/**`
- **Preconditions:** A learner completes one foundational module with a verified explanation and one transfer exercise on day 0. Record the actual dates as historical records; learner participation is required on days 7 and 30. No reminders, calendars, or scheduled events are created.
- **Steps:**
  1. On day 0, record only the demonstrated explanation and transfer evidence; do not predict retention.
  2. On day 7, ask the original retrieval question without hints, record the actual answer, then use a new application prompt.
  3. On day 30, repeat with another new application and record the answer before feedback.
- **Expected result:** Each observation records what the learner actually retrieved and transferred on that date, as ordinary learner evidence with provenance. Missing, late, or skipped sessions remain pending; confidence, immediate correctness, and model judgments never become fabricated 7- or 30-day outcomes, and nothing schedules the follow-up automatically.
- **Cleanup:** Keep the learner-authorized durable record; remove only disposable copies used to inspect the case.
