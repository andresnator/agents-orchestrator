# Learning manual tests

Run these cases in a disposable OpenCode project. Keep deterministic protocol evidence separate from model behavior and human learning evidence. Durable cases may write only under the disposable project's `.ai/learning/` directory.

## Quick path

1. Install only the current checkout's `learning` domain into a fresh target.
2. Run the affected IDs listed in the pull request, one prompt sequence per case.
3. Inspect `.ai/learning/`, including hidden files, and record the effective OpenCode, Node and model versions.
4. Stop disposable services and remove only their temporary target.

### MT-LEARNING-RUNTIME

- **Title:** Verify installed runtime and removed operations
- **Coverage key:** `learning/runtime/absence-compatibility`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/mentor.md`, `.ai/atl/skill-registry.md`
- **Preconditions:** Install only `learning` into a fresh target with isolated `OPENCODE_CONFIG_DIR` and XDG directories. Disable project, external and Claude configuration. Use a scripted provider with no credentials.
- **Steps:**
  1. Inspect the installed agents, `/doc` and `/experimental/tool` endpoint.
  2. Invoke `learning_context` and `learning_event_reference` for `create_topic`, `skip_practice` and `record_language_attempt`.
  3. Search the effective target for `spaced-recall`, `recall-calc`, `learning_due`, `recall_due`, `recall_schedule` and `review-queue.md` generation.
  4. Send a legacy `preview_cards` event through `learning_commit`.
  5. Remove the host synchronous session prompt in a copied target and invoke `learning_job_start`.
- **Expected result:** The runtime loads with schema version 1 and exposes only current `learning_*` tools. Removed operations and registry entries are absent; an old event returns `unsupported_event_type`. New state omits card, retention and due-date fields while old optional fields remain readable. Missing synchronous APIs return `sequential_session_api_unavailable` before a child is created. Deterministic results are recorded separately from model evidence.
- **Essential negative variant:** Install a second fresh target from the same checkout and verify both targets have the same absence and compatibility behavior.
- **Cleanup:** Stop the disposable host and provider. Remove their project, config and XDG roots.

### MT-LEARNING-SESSION

- **Title:** Teach one concept without durable state
- **Coverage key:** `learning/session/ephemeral-teaching`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/skills/learning-session/**`
- **Preconditions:** Start a fresh disposable project with no `.ai/learning/` directory.
- **Steps:**
  1. Run `/learn session Explain why HTTP is stateless. Use one original example, then ask me one question.`
  2. Answer with a causal explanation and end without asking to save.
  3. Inspect the project, including hidden files.
- **Expected result:** Mentor answers first, uses a distinct example, asks one focused question and responds to the actual answer. No Learning directory, route state, summary or automatic save is created.
- **Cleanup:** Close the session and remove the disposable project.

### MT-LEARNING-PATH

- **Title:** Create a durable learning path
- **Coverage key:** `learning/path/durable-creation`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Start a fresh disposable project with the installed runtime available.
- **Steps:**
  1. Run `/learn path HTTP cache validation. Keep materials in Spanish.`
  2. Inspect the complete mission proposal, then confirm or revise it through native `mission` consent.
  3. Inspect `.ai/learning/<topic>/.state.json`, `mission.md`, `path.md`, `vocabulary.md` and `gaps.md`.
  4. Verify that `review-queue.md` is not generated for a new topic.
- **Expected result:** State uses schema version 1, stable concept and prerequisite IDs, tangible module wins and no internal review schedule. Consent binds the exact proposal and revision. A cancelled or altered proposal creates no topic directory.
- **Essential negative variant:** Create a topic directory containing Markdown without `.state.json`, then request it; mutation stops with `unsupported_existing_topic_without_state`.
- **Cleanup:** Remove the disposable Learning state and project.

### MT-LEARNING-MODULE-DELIVERY

- **Title:** Deliver materials and close a module in one turn
- **Coverage key:** `learning/module/sequential-delivery`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-writer.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/cornell-notes/**`
- **Preconditions:** Use a disposable topic with one open module and verified learner text references. The fixture has no new card or retention fields.
- **Steps:**
  1. Complete Class with an objective, relationships, distinct example and learner response.
  2. Dismiss readiness once, then ask for clarification; later choose **Practicar** through native readiness consent. Repeat in a copy choosing **Omitir** from Class and after a partial attempt.
  3. Record the actual attempt and Consolidation with exact `session_id`, `message_id`, `part_id` and `quote` references.
  4. Start the note writer, attach its exact result, then start the exercise writer at the new revision and attach it.
  5. Inspect state and views before and after `close_module`, then restart and recover views.
- **Expected result:** The flow is Class → optional Practice → Consolidation → note → save → exercise → save → Close in the same turn. Omission and partial attempts remain visible and never imply competence. The writer receives separate `approved_outline`, `teacher_assessment`, `practice_state` and `learner_evidence_refs`; Mentor prose is not a learner quote. Both materials are current before closure and no continuation request is needed.
- **Essential negative variant:** Alter a quote, use a foreign session, use stale writer output or omit a blocking criterion. Each operation fails before durable mutation. On resume, only missing or invalidated materials are regenerated.
- **Cleanup:** Remove the disposable topic and project.

### MT-LEARNING-FLEXIBLE-PATH

- **Title:** Revise scope and defer work without inventing competence
- **Coverage key:** `learning/progression/flexible-path`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/plugins/learning-runtime.ts`, `domains/learning/plugins/learning-runtime.test.mjs`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Use an isolated schema-1 topic with verified evidence, one unfinished module and a later module.
- **Steps:**
  1. Propose a narrower theoretical goal and retire an inapplicable requirement; approve the exact `scope_revision` choice.
  2. Reassess the revised criteria and refresh materials before closing.
  3. In another unfinished module, request the next module now; approve `select_module` before completing practice or materials.
  4. Restart and request the deferred module again.
- **Expected result:** Before/after scope, assessments, citations and retired requirements remain traceable. Navigation preserves phase, partial attempts and gaps without prerequisite or material gates. Retired requirements are not credited and omission does not prove practical competence.
- **Essential negative variant:** Cancel or alter a proposal, replay it against a newer revision or substitute another module; state remains unchanged.
- **Cleanup:** Remove only the isolated project and target.

### MT-LEARNING-EVIDENCE-HANDOFF

- **Title:** Preserve literal learner evidence in writer assignments
- **Coverage key:** `learning/evidence/literal-handoff`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-writer.md`, `domains/learning/skills/cornell-notes/**`
- **Preconditions:** Prepare a module with one learner quote, one teacher assessment paraphrasing it, and one consolidation reference to the same quote.
- **Steps:**
  1. Verify the quote through `learning_evidence` and commit the attempt and consolidation.
  2. Start a note writer with an approved outline containing the teacher paraphrase.
  3. Inspect the child prompt and returned material for `learner_evidence_refs`, exact provenance and quote text.
  4. Repeat with a duplicate reference and with an unverified reference.
- **Expected result:** References are deduplicated, module-scoped and byte-for-byte faithful. `teacher_assessment` contains synthesis only; a paraphrase is never presented as a quote. Unverified references fail with `writer_evidence_not_verified`.
- **Cleanup:** Remove the disposable topic and child session.

### MT-LEARNING-STANDALONE-WRITER-EVIDENCE

- **Title:** Pass selected evidence to a standalone artifact
- **Coverage key:** `learning/evidence/standalone-writer`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/learning-writer.md`
- **Preconditions:** Prepare a topic with one reference already present in `verified_evidence` and no module ownership for the requested artifact.
- **Steps:**
  1. Start a quiz, map or dialogue writer with `artifact.evidence_refs` containing the exact verified reference.
  2. Inspect the accepted child prompt.
  3. Repeat with a foreign or unverified reference.
- **Expected result:** The selected reference appears exactly in `assignment.learner_evidence_refs` even without `module_id`; the foreign or unverified selection is rejected before a child is created.
- **Cleanup:** Remove the disposable topic and child session.

### MT-LEARNING-WRITER-ASSIGNMENT-BUDGET

- **Title:** Bound complete writer assignments
- **Coverage key:** `learning/evidence/writer-budget`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/agents/learning-writer.md`, `domains/learning/agents/mentor.md`
- **Preconditions:** Prepare a module with individually valid but collectively oversized stored assessments, then prepare a second fixture whose exact learner references alone exceed the writer envelope.
- **Steps:**
  1. Start a note writer with the oversized assessments and a short outline.
  2. Inspect the child prompt for the explicit `teacher_assessment.status: omitted` marker and the unchanged evidence references.
  3. Start a writer whose literal references exceed the envelope.
- **Expected result:** Oversized assessment guidance is omitted as a named fallback and the worker still starts. Oversized literal evidence fails before child creation with `writer_assignment_too_large`; the message directs the caller to shorten the outline or pass a bounded `artifact.evidence_refs` selection and promises that quotes are never truncated.
- **Cleanup:** Remove the disposable topic and child session.

### MT-LEARNING-LANGUAGE-PROGRESSION

- **Title:** Practice language units on the exposure day
- **Coverage key:** `learning/language/same-day-practice`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/language-loop/**`, `domains/learning/skills/bidirectional-translation/**`
- **Preconditions:** Create a disposable target/native language topic with units exposed on the current date and production required.
- **Steps:**
  1. Add a unit with `passive_at` equal to today's date and immediately request practice.
  2. Record a meaning-changing attempt, an `input-only` attempt and a meaning-preserving production attempt.
  3. Inspect state after each attempt and attempt topic completion while production remains pending.
- **Expected result:** Same-day practice is available. Pending, error and `input-only` units remain available in learner order; no `next_due`, three-day wait or grade is created. Errors remain pending, `input-only` does not satisfy required production and natural meaning-preserving production can complete the unit.
- **Essential negative variant:** Submit a fake date or malformed unit; the event fails without changing the registry.
- **Cleanup:** Remove the disposable language topic and project.

### MT-LEARNING-VOCAB-EXPORT

- **Title:** Export only confirmed vocabulary rows
- **Coverage key:** `learning/vocabulary/selected-export`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/skills/anki-vocab/**`, `domains/learning/skills/language-loop/**`
- **Preconditions:** Use a disposable language topic with two candidate phrases and no export for either phrase.
- **Steps:**
  1. Preview the exact five-field rows and select one subset through native export consent.
  2. Correct the unexported row under its existing ID and confirm a fresh preview.
  3. Attempt to alter an exported row and replay the export event.
  4. Inspect state, `vocabulary.md` and the generated semicolon batch.
- **Expected result:** Only confirmed rows are exported; duplicate normalized keys are rejected, exported rows are immutable and replay is idempotent. Export does not prove import or mastery and creates no internal review state or dates.
- **Cleanup:** Remove the disposable topic and batch.

### MT-LEARNING-RECOVERY

- **Title:** Recover accepted work without duplication
- **Coverage key:** `learning/runtime/recovery-atomicity`
- **Applies to:** `domains/learning/plugins/learning-runtime.ts`, `domains/learning/plugins/learning-runtime.test.mjs`, `domains/learning/agents/learning-writer.md`
- **Preconditions:** Use an isolated project and fixture provider that can delay, fail transport and later return a terminal child message.
- **Steps:**
  1. Start a researcher or writer and verify the parent call waits for terminal output.
  2. Simulate transport loss, recover the accepted child by ID and inspect the exact result.
  3. Advance the topic revision, then attempt to attach the old result.
  4. Cancel an accepted child and verify settlement before any replacement.
- **Expected result:** One child is created, recovery reuses it, stale output cannot commit and failed terminal jobs are not retried automatically. Atomic state and view writes remain valid after restart.
- **Cleanup:** Stop the fixture provider and remove the isolated project.

### MT-LEARNING-MODEL-VARIANCE

- **Title:** Compare authorized model behavior without weakening contracts
- **Coverage key:** `learning/models/protocol-variance`
- **Applies to:** `domains/learning/agents/**`, `domains/learning/commands/**`, `domains/learning/skills/**`, `domains/learning/plugins/**`
- **Preconditions:** Obtain explicit credit authorization and record the exact Astra or Luna model, host version, timestamps and costs.
- **Steps:**
  1. Run the module-delivery and language cases once per authorized model.
  2. Compare prose quality separately from state diffs, evidence provenance, consent and write boundaries.
  3. Record any model-backed case that could not run as pending, with its reason.
- **Expected result:** Protocol invariants hold for every authorized run. Teaching quality may vary and is reported by rubric and finite sample; deterministic or scripted checks are never reported as live-model evidence.
- **Cleanup:** Delete copied snapshots and disposable model sessions.
