import assert from "node:assert/strict"
import { test } from "node:test"
import { mkdtemp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { LearningRuntimePlugin, learningRuntimeContracts } from "./learning-runtime.ts"

const MODULE_ID = "M-0001"
const PREVIEW_ID = "RETENTION-RECOVERY"
const REVISION = 7

function topicState(phase, disposition = "pending", preview) {
  return {
    schema_version: 1,
    revision: REVISION,
    topic: { slug: "retention-recovery", title: "Retention recovery", materials_language: "English", goal: "Recover a missing preview", status: "active" },
    concepts: [{ id: "K-0001", title: "Recovery", prerequisites: [], fundamental: true, learner_override: false, taught: true }],
    modules: [{
      id: MODULE_ID,
      title: "Recovery module",
      win: "Recover retention",
      phase,
      taught_concept_ids: ["K-0001"],
      class_evidence: "Class completed",
      attempt: { revision: 5, outcome: "done", evidence: "Practice completed" },
      consolidation: { revision: 6, learner_evidence: "Consolidated", blocking_gaps: [] },
      retention: { disposition, ...(preview ? { preview } : {}), selected_card_ids: [] },
      artifacts: { note: "notes/m-0001.md", exercise: "exercises/m-0001.md" },
    }],
    cards: [], card_changes: [], review_events: [], language_units: [],
    vocabulary: { candidates: [], exports: [] }, gaps: [], jobs: [], artifacts: {},
    applied_events: {}, consents: [], views: { revision: REVISION, status: "current" },
  }
}

function previewEvent() {
  return {
    type: "preview_cards",
    event_id: "TEST-RETENTION-RECOVERY",
    date: "2026-09-09",
    module_id: MODULE_ID,
    preview_id: PREVIEW_ID,
    source_revision: REVISION,
    cards: [],
  }
}

for (const phase of ["practice", "consolidation"]) {
  test(`shouldPreserveModuleEvidenceWhenRecoveringMissingPreviewIn${phase}`, () => {
    // Given
    const current = topicState(phase)
    const before = structuredClone(current)

    // When
    const { state } = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, previewEvent())
    const updated = state.modules[0]

    // Then
    assert.deepEqual(current, before)
    assert.deepEqual({ ...updated, retention: before.modules[0].retention }, before.modules[0])
    assert.equal(updated.retention.preview.id, PREVIEW_ID)
    assert.equal(updated.retention.disposition, "pending")
  })
}

for (const phase of ["mission", "closed"]) {
  test(`shouldRejectPreviewWhenModuleIs${phase}`, () => {
    // Given
    const current = topicState(phase)

    // When / Then
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, previewEvent()), /preview_requires_class/)
  })
}

for (const disposition of ["none", "deferred", "selected"]) {
  test(`shouldRejectLatePreviewWhenRetentionIs${disposition}`, () => {
    // Given
    const current = topicState("consolidation", disposition)

    // When / Then
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, previewEvent()), /preview_requires_class/)
  })
}

test("shouldRejectLateReplacementWhenPreviewAlreadyExists", () => {
  // Given
  const existingPreview = { topic_slug: "retention-recovery", module_id: MODULE_ID, id: "EXISTING", source_revision: REVISION, digest: "digest", cards: [] }
  const current = topicState("consolidation", "pending", existingPreview)

  // When / Then
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, previewEvent()), /preview_requires_class/)
})

test("shouldStillRejectClosureWhenRetentionIsPending", () => {
  // Given
  const current = topicState("consolidation")
  const event = { type: "close_module", event_id: "TEST-CLOSE", date: "2026-09-09", module_id: MODULE_ID }

  // When / Then
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, event), /module_close_requirements_not_met/)
})

const LEARNER_REFERENCE = { session_id: "parent", message_id: "learner", part_id: "text", quote: "A stale response must be revalidated before reuse." }
const CONTEXT = { agent: "mentor", sessionID: "parent", messageID: "assistant", abort: new AbortController().signal }

function answeredReadiness(current, selected = "skip") {
  const interactions = learningRuntimeContracts.createInteractions()
  const choice = interactions.stage(CONTEXT, {
    purpose: "readiness", revision: current.revision,
    subject_json: JSON.stringify({ topic_slug: current.topic.slug, module_id: MODULE_ID }),
    question: "¿Practicar u omitir?",
    options: [{ id: "ready", label: "Practicar", description: "Aplicar" }, { id: "skip", label: "Omitir", description: "Consolidar" }],
  })
  return { ...choice, status: "answered", requestID: "native-request", selected: [selected] }
}

function skipEvent(choice) {
  return { type: "skip_practice", event_id: "SKIP", date: "2026-09-10", module_id: MODULE_ID, interaction_id: choice.id }
}

for (const phase of ["class", "practice"]) {
  test(`shouldPreserveAttemptsAndRequireConsolidationWhenSkippingFrom${phase}`, () => {
    // Given
    const current = topicState(phase, "none")
    delete current.modules[0].consolidation
    if (phase === "class") delete current.modules[0].attempt
    else current.modules[0].attempt.outcome = "partial"
    const choice = answeredReadiness(current)

    // When
    const { state } = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, skipEvent(choice), choice)
    const replay = learningRuntimeContracts.applyLearningEvent(state, state.topic.slug, skipEvent(choice))

    // Then
    assert.deepEqual(state.modules[0], { ...current.modules[0], phase: "consolidation", practice_skipped: true })
    assert.deepEqual(replay.state, state)
    assert.equal(replay.result.duplicate, true)
    assert.equal(state.schema_version, 1)
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(state, state.topic.slug, { type: "close_module", event_id: "CLOSE", date: "2026-09-10", module_id: MODULE_ID }), /module_close_requirements_not_met/)
  })
}

for (const invalid of ["pending", "dismissed", "wrong-selection", "stale", "wrong-module", "wrong-purpose"]) {
  test(`shouldRejectSkipWhenConsentIs${invalid}`, () => {
    // Given
    const current = topicState("class")
    const choice = answeredReadiness(current)
    if (["pending", "dismissed"].includes(invalid)) choice.status = invalid
    if (invalid === "wrong-selection") choice.selected = ["ready"]
    if (invalid === "stale") choice.input.revision--
    if (invalid === "wrong-module") choice.input.subject_json = "{}"
    if (invalid === "wrong-purpose") choice.input.purpose = "cards"
    const before = structuredClone(current)

    // When / Then
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, skipEvent(choice), choice), /interaction/)
    assert.deepEqual(current, before)
  })
}

for (const skipped of [false, true]) {
  test(`shouldCloseWithVerifiedConsolidationAndMaterialsWhenPracticeIs${skipped ? "Skipped" : "Done"}`, () => {
    // Given
    let current = topicState("consolidation", "none")
    delete current.modules[0].consolidation
    if (skipped) { current.modules[0].practice_skipped = true; delete current.modules[0].attempt }
    const event = { type: "record_consolidation", event_id: "CONSOLIDATE", date: "2026-09-10", module_id: MODULE_ID, learner_evidence: "Correct essential explanation", evidence_refs: [LEARNER_REFERENCE], blocking_gaps: [] }

    // When
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, event), /unverified_evidence_reference/)
    current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, event, undefined, [LEARNER_REFERENCE]).state
    const close = { type: "close_module", event_id: "CLOSE", date: "2026-09-10", module_id: MODULE_ID }
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, close), /module_artifacts_not_current/)
    for (const path of ["notes/m-0001.md", "exercises/m-0001.md"]) {
      current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, { type: "attach_artifact", event_id: path.startsWith("notes") ? "NOTE" : "EXERCISE", date: "2026-09-10", module_id: MODULE_ID, path, content: "# Material\n\n" + (skipped ? "Practice skipped" : "Practice done"), source_revision: current.revision, job_id: "writer", selected_card_ids: [] }).state
    }
    const blocked = structuredClone(current)
    blocked.modules[0].consolidation.blocking_gaps = ["Unresolved misconception"]
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(blocked, blocked.topic.slug, close), /module_close_requirements_not_met/)
    current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, close).state

    // Then
    assert.equal(current.modules[0].phase, "closed")
    assert.deepEqual(current.modules[0].consolidation.evidence_refs, [LEARNER_REFERENCE])
    const views = learningRuntimeContracts.renderViews(current)
    const old = learningRuntimeContracts.renderViews(topicState("closed", "none"))
    assert.deepEqual(Object.keys(views).filter((path) => !path.includes("/")), Object.keys(old))
    const structure = (text) => text.split("\n").filter((line) => line.startsWith("#") || line.startsWith("| ID") || line.startsWith("| ---"))
    for (const path of Object.keys(old)) assert.deepEqual(structure(views[path]), structure(old[path]))
    assert.equal(views["path.md"].includes("practice skipped"), skipped)
  })
}

function deferred() {
  let resolve, reject
  const promise = new Promise((yes, no) => { resolve = yes; reject = no })
  return { promise, resolve, reject }
}

function workerFixture() {
  const started = deferred()
  const response = deferred()
  const records = new Map()
  let created = 0
  let aborted = 0
  const client = {
    app: { agents: async () => ({ data: ["learning-researcher", "learning-writer", "learning-summarizer"].map((name) => ({ name })) }) },
    session: {
      message: async () => ({ data: { info: { role: "assistant", providerID: "fixture", modelID: "scripted" } } }),
      create: async () => { const id = `child-${++created}`; records.set(id, { busy: true, messages: [{ info: { role: "user", id: "prompt" }, parts: [] }] }); return { data: { id } } },
      prompt: async ({ path, signal }) => {
        started.resolve(path.id)
        return Promise.race([response.promise, new Promise((_, reject) => signal.addEventListener("abort", () => reject(new Error("aborted")), { once: true }))])
      },
      messages: async ({ path }) => ({ data: records.get(path.id).messages }),
      status: async () => ({ data: Object.fromEntries([...records].map(([id, record]) => [id, { type: record.busy ? "busy" : "idle" }])) }),
      abort: async ({ path }) => { aborted++; records.get(path.id).busy = false; return { data: true } },
    },
  }
  function finish(id, text = "Complete worker output", error) {
    const record = records.get(id)
    record.busy = false
    record.messages.push({ info: { role: "assistant", parentID: "prompt", time: { completed: 1 }, finish: "stop", ...(error ? { error: { name: error } } : {}) }, parts: [{ type: "text", text }] })
    response.resolve({ data: record.messages.at(-1) })
  }
  return { client, started, response, records, finish, counts: () => ({ created, aborted }) }
}

const RESEARCH_JOB = { worker: "learning-researcher", scope: "session:test", revision: 0, prompt: "One bounded question" }

test("shouldWaitForDelayedTerminalOutputAndSerializeAllWorkersWithinParent", async () => {
  // Given
  const fixture = workerFixture()
  const jobs = learningRuntimeContracts.createJobs(fixture.client)
  let returned = false

  // When
  const pending = jobs.launch(CONTEXT, RESEARCH_JOB).then((job) => { returned = true; return job })
  const id = await fixture.started.promise
  await new Promise((resolve) => setTimeout(resolve, 20))
  assert.equal(returned, false)
  await assert.rejects(jobs.launch(CONTEXT, { ...RESEARCH_JOB, worker: "learning-summarizer", scope: "summaries" }), /learning_job_pending/)
  fixture.finish(id)
  const result = await pending

  // Then
  assert.equal(result.status, "completed")
  assert.equal(result.result, "Complete worker output")
  assert.deepEqual(fixture.counts(), { created: 1, aborted: 0 })
  assert.equal(jobs.notices, undefined)
})

test("shouldKeepTransportFailurePendingAndRecoverSameChildWithoutRelaunch", async () => {
  // Given
  const fixture = workerFixture()
  const jobs = learningRuntimeContracts.createJobs(fixture.client)
  const launch = jobs.launch(CONTEXT, RESEARCH_JOB)
  const id = await fixture.started.promise

  // When
  fixture.response.reject(new Error("connection lost"))
  const accepted = await launch
  assert.equal(accepted.status, "starting")
  await assert.rejects(jobs.launch(CONTEXT, RESEARCH_JOB), /learning_job_pending/)
  let returned = false
  const recovery = jobs.wait(CONTEXT.sessionID, id).then((job) => { returned = true; return job })
  await new Promise((resolve) => setTimeout(resolve, 20))
  assert.equal(returned, false)
  fixture.finish(id, "Recovered full output")
  const result = await recovery

  // Then
  assert.equal(result.result, "Recovered full output")
  assert.equal(result.status, "completed")
  assert.equal(fixture.counts().created, 1)
})

test("shouldPropagateParentCancellationToAcceptedChild", async () => {
  // Given
  const fixture = workerFixture()
  const jobs = learningRuntimeContracts.createJobs(fixture.client)
  const controller = new AbortController()
  const launch = jobs.launch({ ...CONTEXT, abort: controller.signal }, RESEARCH_JOB)
  await fixture.started.promise

  // When
  controller.abort()
  const result = await launch

  // Then
  assert.equal(result.status, "cancelled")
  assert.deepEqual(fixture.counts(), { created: 1, aborted: 1 })
})

test("shouldRejectUnavailableSynchronousAPIWithoutCreatingChild", async () => {
  // Given
  const fixture = workerFixture()
  delete fixture.client.session.prompt
  const jobs = learningRuntimeContracts.createJobs(fixture.client)

  // When / Then
  assert.equal(jobs.available, false)
  await assert.rejects(jobs.launch(CONTEXT, RESEARCH_JOB), /sequential_session_api_unavailable/)
  assert.equal(fixture.counts().created, 0)
})

async function pluginFixture(t, initial) {
  const directory = await mkdtemp(join(tmpdir(), "learning-protocol-"))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const fixture = workerFixture()
  if (initial) {
    const root = join(directory, ".ai/learning", initial.topic.slug)
    await mkdir(root, { recursive: true })
    await writeFile(join(root, ".state.json"), JSON.stringify(initial))
  }
  fixture.client.session.prompt = async ({ path, body }) => {
    let result
    if (body.agent === "learning-summarizer") result = { kind: "summary", title: "Resumen", language: "Spanish", markdown: "# Resumen\n\n## Preguntas\n\n¿Por qué revalidar?\n\n## Notas\n\nComprueba cambios.\n\n## Resumen\n\nRevalidar permite reutilizar." }
    else {
      const input = JSON.parse(body.parts[0].text)
      result = { kind: input.kind, source_revision: input.source_revision, destination_hint: input.destination_hint, module_id: input.module_id, selected_card_ids: input.selected_card_ids, content: "# Material\n\n## Evidence\n\nPractice skipped; no completed attempt.\n" }
    }
    fixture.finish(path.id, JSON.stringify(result))
    return { data: fixture.records.get(path.id).messages.at(-1) }
  }
  const plugin = await LearningRuntimePlugin({ client: fixture.client, directory })
  async function call(name, args) { return JSON.parse(await plugin.tool[name].execute(args, CONTEXT)) }
  async function choose(purpose, subject, revision, options, selected) {
    const choice = await call("learning_choice", { purpose, revision, subject_json: JSON.stringify(subject), question: "¿Confirmas?", options: options.map((id) => ({ id, label: id, description: id })), multiple: false })
    const output = { args: structuredClone(choice.next_args) }
    await plugin["tool.execute.before"]({ tool: "question", sessionID: CONTEXT.sessionID, callID: choice.id }, output)
    await plugin.event({ event: { type: "question.asked", properties: { id: choice.id, sessionID: CONTEXT.sessionID, tool: { callID: choice.id }, questions: output.args.questions } } })
    await plugin.event({ event: { type: "question.replied", properties: { requestID: choice.id, sessionID: CONTEXT.sessionID, answers: [[selected]] } } })
    const answered = await call("learning_choice_result", { id: choice.id })
    assert.equal(answered.status, "answered")
    return answered.id
  }
  return { ...fixture, directory, plugin, call, choose }
}

test("shouldDeliverNoteExerciseAndCloseInOneProtocolTurnAfterNativeSkip", async (t) => {
  // Given: an old schema-1 snapshot has no practice_skipped field.
  const initial = topicState("class", "none")
  delete initial.modules[0].attempt
  delete initial.modules[0].consolidation
  initial.verified_evidence = [LEARNER_REFERENCE]
  const fixture = await pluginFixture(t, initial)
  const { call, choose } = fixture
  const topic_slug = initial.topic.slug
  let revision = initial.revision
  async function commit(event) {
    const result = await call("learning_commit", { topic_slug, expected_revision: revision, event: { date: "2026-09-10", module_id: MODULE_ID, ...event } })
    revision = result.revision
    assert.equal(result.views, "current")
  }

  // When: every operation uses the same parent message, with no continuation.
  const capabilities = await call("learning_context", {})
  assert.equal(capabilities.sequential_jobs, true)
  assert.equal(capabilities.async_sessions, undefined)
  assert.equal(fixture.plugin["chat.message"], undefined)
  const reference = await call("learning_event_reference", { event_type: "skip_practice" })
  assert.deepEqual(reference.events.skip_practice.choice.options, ["ready", "skip"])
  const interaction_id = await choose("readiness", { topic_slug, module_id: MODULE_ID }, revision, ["ready", "skip"], "skip")
  await commit({ type: "skip_practice", event_id: "SKIP", interaction_id })
  await commit({ type: "record_consolidation", event_id: "CONSOLIDATE", learner_evidence: "Essential explanation sufficient", evidence_refs: [LEARNER_REFERENCE], blocking_gaps: [] })
  const revisions = []
  for (const kind of ["note", "exercise"]) {
    revisions.push(revision)
    const job = await call("learning_job_start", { worker: "learning-writer", scope: topic_slug, revision, artifact: { kind, method: kind === "note" ? "cornell-notes" : "learning-loop", destination_hint: `${kind === "note" ? "notes" : "exercises"}/m-0001.md`, materials_language: "English", module_id: MODULE_ID, selected_card_ids: [] }, prompt: "Retain the existing template. Practice was skipped; preserve omission in existing evidence fields." })
    assert.equal(job.status, "completed")
    const output = JSON.parse(job.result)
    await commit({ type: "attach_artifact", event_id: kind.toUpperCase(), path: output.destination_hint, content: output.content, source_revision: job.revision, job_id: job.id, selected_card_ids: [] })
  }
  await commit({ type: "close_module", event_id: "CLOSE" })

  // Then: persisted state and generated paths survive a new plugin instance.
  const resumed = await LearningRuntimePlugin({ client: fixture.client, directory: fixture.directory })
  const state = JSON.parse(await resumed.tool.learning_state_read.execute({ topic_slug }, CONTEXT))
  assert.deepEqual(revisions, [REVISION + 2, REVISION + 3])
  assert.equal(state.modules[0].phase, "closed")
  assert.equal(state.modules[0].practice_skipped, true)
  assert.equal(state.modules[0].attempt, undefined)
  assert.equal(state.consents.length, 1)
  assert.deepEqual(state.jobs.map((job) => job.status), ["completed", "completed"])
  assert.match(await readFile(join(fixture.directory, ".ai/learning", topic_slug, "path.md"), "utf8"), /closed \(practice skipped\)/)
  assert.equal(fixture.counts().created, 2)
})

test("shouldCreateApprovedSummaryExclusivelyInSameProtocolTurn", async (t) => {
  // Given
  const fixture = await pluginFixture(t)
  const interaction_id = await fixture.choose("summary", { scope: "summaries" }, 0, ["save", "cancel"], "save")

  // When
  const job = await fixture.call("learning_job_start", { worker: "learning-summarizer", scope: "summaries", revision: 0, prompt: "Frozen approved conversation segment" })
  const args = { job_id: job.id, interaction_id }
  const results = await Promise.allSettled([fixture.call("learning_summary_create", args), fixture.call("learning_summary_create", args)])

  // Then
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1)
  assert.match(results.find((result) => result.status === "rejected").reason.message, /summary_interaction_already_used/)
  await assert.rejects(fixture.call("learning_summary_create", args), /summary_interaction_already_used/)
  const files = await readdir(join(fixture.directory, ".ai/learning/summaries"))
  assert.equal(files.length, 1)
  assert.equal(fixture.counts().created, 1)
})

test("shouldRejectStaleWriterResultAtCommitWithoutRelaunch", async (t) => {
  // Given
  const initial = topicState("consolidation", "none")
  initial.verified_evidence = [LEARNER_REFERENCE]
  const fixture = await pluginFixture(t, initial)
  const topic_slug = initial.topic.slug
  const job = await fixture.call("learning_job_start", { worker: "learning-writer", scope: topic_slug, revision: REVISION, artifact: { kind: "note", method: "cornell-notes", destination_hint: "notes/m-0001.md", materials_language: "English", module_id: MODULE_ID, selected_card_ids: [] }, prompt: "Approved outline" })

  // When
  await fixture.call("learning_commit", { topic_slug, expected_revision: REVISION, event: { type: "record_consolidation", event_id: "NEW-EVIDENCE", date: "2026-09-10", module_id: MODULE_ID, learner_evidence: "Updated assessment", evidence_refs: [LEARNER_REFERENCE], blocking_gaps: [] } })
  const output = JSON.parse(job.result)

  // Then
  await assert.rejects(fixture.call("learning_commit", { topic_slug, expected_revision: REVISION + 1, event: { type: "attach_artifact", event_id: "STALE", date: "2026-09-10", module_id: MODULE_ID, selected_card_ids: [], path: output.destination_hint, content: output.content, source_revision: REVISION, job_id: job.id } }), /invalid_or_stale_artifact/)
  assert.equal(fixture.counts().created, 1)
})

for (const terminal of ["failed", "completed"]) {
  test(`shouldWaitBeyondToolCallsUntilWorkerIs${terminal}`, async () => {
    // Given
    const fixture = workerFixture()
    const jobs = learningRuntimeContracts.createJobs(fixture.client)
    let returned = false
    const pending = jobs.launch(CONTEXT, RESEARCH_JOB).then((job) => { returned = true; return job })
    const id = await fixture.started.promise
    const record = fixture.records.get(id)
    record.messages.push({ info: { role: "assistant", parentID: "prompt", time: { completed: 1 }, finish: "tool-calls" }, parts: [{ type: "text", text: "Partial intermediate text" }] })
    record.busy = false

    // When
    fixture.response.resolve({ data: record.messages.at(-1) })
    await new Promise((resolve) => setTimeout(resolve, 20))
    assert.equal(returned, false)
    fixture.finish(id, "Final complete text", terminal === "failed" ? "ModelError" : undefined)
    const result = await pending

    // Then
    assert.equal(result.status, terminal)
    if (terminal === "failed") assert.equal(result.error, "ModelError")
    else assert.equal(result.result, "Final complete text")
    assert.equal(fixture.counts().created, 1)
  })
}

test("shouldPreservePracticePathAndRejectOmissionAfterCompletion", () => {
  // Given
  let current = topicState("class", "none")
  delete current.modules[0].attempt
  delete current.modules[0].consolidation
  const choice = answeredReadiness(current, "ready")

  // When
  current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, { ...skipEvent(choice), type: "start_practice" }, choice).state
  assert.equal(current.modules[0].phase, "practice")
  current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, { type: "record_attempt", event_id: "DONE", date: "2026-09-10", module_id: MODULE_ID, outcome: "done", evidence: "Correct application", evidence_refs: [LEARNER_REFERENCE] }, undefined, [LEARNER_REFERENCE]).state

  // Then
  assert.equal(current.modules[0].phase, "consolidation")
  assert.equal(current.modules[0].practice_skipped, undefined)
  const skip = answeredReadiness(current)
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, { ...skipEvent(skip), event_id: "LATE-SKIP" }, skip), /practice_requires_class_or_unfinished_practice/)
})

test("shouldCancelRecoveredChildAndKeepNewerRequestsFromRelaunching", async () => {
  // Given
  const fixture = workerFixture()
  const jobs = learningRuntimeContracts.createJobs(fixture.client)
  const launch = jobs.launch(CONTEXT, { ...RESEARCH_JOB, scope: "existing-topic", revision: 1 })
  const id = await fixture.started.promise
  fixture.response.reject(new Error("lost response"))
  await launch

  // When
  await assert.rejects(jobs.launch(CONTEXT, { ...RESEARCH_JOB, scope: "existing-topic", revision: 2 }), /learning_job_pending/)
  const controller = new AbortController()
  const pending = jobs.wait(CONTEXT.sessionID, id, controller.signal)
  controller.abort()
  const result = await pending

  // Then
  assert.equal(result.status, "cancelled")
  assert.equal(result.supersededRevision, 2)
  assert.deepEqual(fixture.counts(), { created: 1, aborted: 1 })
})
