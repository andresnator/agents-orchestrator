import assert from "node:assert/strict"
import { test } from "node:test"
import { mkdtemp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { LearningRuntimePlugin, learningRuntimeContracts } from "./learning-runtime.ts"

const MODULE_ID = "M-0001"
const REVISION = 7

function topicState(phase) {
  return {
    schema_version: 1,
    revision: REVISION,
    topic: { slug: "learning-flow", title: "Learning flow", materials_language: "English", goal: "Practice and consolidate a concept", status: "active" },
    concepts: [{ id: "K-0001", title: "Recovery", prerequisites: [], fundamental: true, learner_override: false, taught: true }],
    modules: [{
      id: MODULE_ID,
      title: "Recovery module",
      win: "Apply the concept",
      phase,
      taught_concept_ids: ["K-0001"],
      class_evidence: "Class completed",
      attempt: { revision: 5, outcome: "done", evidence: "Practice completed" },
      consolidation: { revision: 6, learner_evidence: "Consolidated", blocking_gaps: [] },
      artifacts: { note: "notes/m-0001.md", exercise: "exercises/m-0001.md" },
    }],
    language_units: [],
    vocabulary: { candidates: [], exports: [] }, gaps: [], jobs: [], artifacts: {},
    applied_events: {}, consents: [], views: { revision: REVISION, status: "current" },
  }
}

test("shouldExposeTheNewStateWithoutCalendarOrReviewQueue", () => {
  // Given
  const state = topicState("class")
  state.topic.target_language = "English"
  state.topic.native_language = "Spanish"
  state.language_units.push({ id: "L-0001", passive_at: "2026-09-12", situation: "greeting", target_text: "Hello", native_text: "Hola", status: "pending" })

  // When
  const views = learningRuntimeContracts.renderViews(state)

  // Then
  assert.equal(views["review-queue.md"], undefined)
  assert.doesNotMatch(views["path.md"], /Retention|Next due|selected card/i)
  assert.doesNotMatch(views["path.md"], /next_due/)
  assert.match(views["path.md"], /Language units/)
})

test("shouldBuildWriterAssignmentFromVerifiedModuleEvidence", () => {
  // Given
  const state = topicState("consolidation")
  const first = LEARNER_REFERENCE
  const second = { session_id: "parent", message_id: "learner-2", part_id: "text", quote: "The learner applies the rule in a new case." }
  state.verified_evidence = [first, second]
  state.modules[0].attempt = { revision: 8, outcome: "done", evidence_refs: [first], evidence: "Teacher observed the application.", causal_explanation: "The learner named the cause.", transfer_evidence: "The learner transferred it." }
  state.modules[0].consolidation = { revision: 9, evidence_refs: [first, second], learner_evidence: "Coverage is sufficient.", blocking_gaps: [] }

  // When
  const assignment = learningRuntimeContracts.writerAssignment(state, { kind: "note", method: "cornell-notes", destination_hint: "notes/m-0001.md", materials_language: "English", module_id: MODULE_ID }, "Approved outline")

  // Then
  assert.equal(assignment.approved_outline, "Approved outline")
  assert.deepEqual(assignment.learner_evidence_refs, [first, second])
  assert.equal(assignment.teacher_assessment.consolidation, "Coverage is sufficient.")
  assert.equal(assignment.practice_state.attempt.outcome, "done")
  assert.equal(assignment.teacher_assessment.class_evidence, "Class completed")
  assert.equal(assignment.teacher_assessment.class_evidence.includes(first.quote), false)

  state.verified_evidence = [first]
  assert.throws(() => learningRuntimeContracts.writerAssignment(state, { kind: "note", method: "cornell-notes", destination_hint: "notes/m-0001.md", materials_language: "English", module_id: MODULE_ID }, "Approved outline"), /writer_evidence_not_verified/)
})

test("shouldMakeLanguagePracticeAvailableOnExposureDayWithoutScheduling", () => {
  // Given
  const state = topicState("class")
  state.topic.target_language = "English"
  state.topic.native_language = "Spanish"
  const unit = { type: "add_language_unit", event_id: "LANG-ADD", date: "2026-09-12", unit_id: "L-0001", passive_at: "2026-09-12", situation: "greeting", target_text: "Hello", native_text: "Hola" }

  // When
  let current = learningRuntimeContracts.applyLearningEvent(state, state.topic.slug, unit).state
  current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, { type: "record_language_attempt", event_id: "LANG-TRY", date: "2026-09-12", unit_id: "L-0001", outcome: "input-only", evidence: "Learner recognized the greeting." }).state

  // Then
  assert.equal(current.language_units[0].status, "input-only")
  assert.equal(current.language_units[0].next_due, undefined)
  assert.equal(current.language_units[0].passive_at, "2026-09-12")
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, { ...unit, event_id: "LANG-ADD-OLD", unit_id: "L-0002", next_due: "2026-09-15" }), /language_schedule_fields_removed/)
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, { type: "record_language_attempt", event_id: "LANG-TRY-OLD", date: "2026-09-12", unit_id: "L-0001", outcome: "input-only", evidence: "Learner recognized the greeting.", next_due: "2026-09-15" }), /language_schedule_fields_removed/)
})

const LEARNER_REFERENCE = { session_id: "parent", message_id: "learner", part_id: "text", quote: "A stale response must be revalidated before reuse." }
const CONTEXT = { agent: "mentor", sessionID: "parent", messageID: "assistant", abort: new AbortController().signal }

test("shouldCreateNewStateWithoutHistoricalReviewFields", () => {
  // Given
  const event = {
    type: "create_topic", interaction_id: "mission-choice", event_id: "CREATE", date: "2026-09-12",
    title: "Fresh topic", materials_language: "English", goal: "Explain the concept and apply it",
    concepts: [{ id: "K-0001", title: "Concept", prerequisites: [], fundamental: true }],
    modules: [{ id: "M-0001", title: "First module", win: "Apply the concept" }],
  }
  const interactions = learningRuntimeContracts.createInteractions()
  const staged = interactions.stage(CONTEXT, {
    purpose: "mission", revision: 0, subject_json: JSON.stringify({ topic_slug: "fresh-topic", title: event.title, materials_language: event.materials_language, goal: event.goal, concepts: event.concepts, modules: event.modules }),
    question: "¿Crear?", options: [{ id: "create", label: "Crear", description: "Crear" }, { id: "revise", label: "Revisar", description: "Revisar" }, { id: "cancel", label: "Cancelar", description: "Cancelar" }],
  })
  const choice = { ...staged, status: "answered", requestID: "mission-request", selected: ["create"] }
  event.interaction_id = choice.id

  // When
  const { state } = learningRuntimeContracts.applyLearningEvent(undefined, "fresh-topic", event, choice)

  // Then
  assert.equal(state.schema_version, 1)
  assert.equal(state.modules[0].retention, undefined)
  assert.equal(state.cards, undefined)
  assert.equal(state.card_changes, undefined)
  assert.equal(state.review_events, undefined)
  assert.equal(state.modules[0].artifacts.note, undefined)
})

test("shouldPreserveHistoricalFieldsWithoutUsingThemForProgression", () => {
  // Given
  const legacy = topicState("consolidation")
  legacy.modules[0].retention = { disposition: "pending", selected_card_ids: [] }
  legacy.cards = []
  legacy.card_changes = []
  legacy.review_events = []
  legacy.artifacts = {
    "notes/m-0001.md": { content: "# Note", source_revision: 7, module_id: MODULE_ID, selected_card_ids: [] },
    "exercises/m-0001.md": { content: "# Exercise", source_revision: 7, module_id: MODULE_ID, selected_card_ids: [] },
  }

  assert.throws(() => learningRuntimeContracts.applyLearningEvent(legacy, legacy.topic.slug, {
    type: "attach_artifact", event_id: "LEGACY-ATTACH", date: "2026-09-12", module_id: MODULE_ID,
    path: "notes/m-0001.md", content: "# Note", source_revision: REVISION, job_id: "writer", selected_card_ids: [],
  }), /writer_retention_fields_removed/)

  // When
  const { state } = learningRuntimeContracts.applyLearningEvent(legacy, legacy.topic.slug, { type: "close_module", event_id: "LEGACY-CLOSE", date: "2026-09-12", module_id: MODULE_ID })

  // Then
  assert.equal(state.modules[0].phase, "closed")
  assert.deepEqual(state.modules[0].retention, legacy.modules[0].retention)
  assert.deepEqual(state.cards, [])
  assert.deepEqual(state.card_changes, [])
  assert.deepEqual(state.review_events, [])
})

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
    const current = topicState(phase)
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
    let current = topicState("consolidation")
    delete current.modules[0].consolidation
    if (skipped) { current.modules[0].practice_skipped = true; delete current.modules[0].attempt }
    const event = { type: "record_consolidation", event_id: "CONSOLIDATE", date: "2026-09-10", module_id: MODULE_ID, learner_evidence: "Correct essential explanation", evidence_refs: [LEARNER_REFERENCE], blocking_gaps: [] }

    // When
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, event), /unverified_evidence_reference/)
    current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, event, undefined, [LEARNER_REFERENCE]).state
    const close = { type: "close_module", event_id: "CLOSE", date: "2026-09-10", module_id: MODULE_ID }
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, close), /module_artifacts_not_current/)
    for (const path of ["notes/m-0001.md", "exercises/m-0001.md"]) {
      current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, { type: "attach_artifact", event_id: path.startsWith("notes") ? "NOTE" : "EXERCISE", date: "2026-09-10", module_id: MODULE_ID, path, content: "# Material\n\n" + (skipped ? "Practice skipped" : "Practice done"), source_revision: current.revision, job_id: "writer" }).state
    }
    const blocked = structuredClone(current)
    blocked.modules[0].consolidation.blocking_gaps = ["Unresolved misconception"]
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(blocked, blocked.topic.slug, close), /module_close_requirements_not_met/)
    current = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, close).state

    // Then
    assert.equal(current.modules[0].phase, "closed")
    assert.deepEqual(current.modules[0].consolidation.evidence_refs, [LEARNER_REFERENCE])
    const views = learningRuntimeContracts.renderViews(current)
    const old = learningRuntimeContracts.renderViews(topicState("closed"))
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
      result = { kind: input.kind, source_revision: input.source_revision, destination_hint: input.destination_hint, module_id: input.module_id, content: "# Material\n\n## Evidence\n\nPractice skipped; no completed attempt.\n" }
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
  const initial = topicState("class")
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
    const job = await call("learning_job_start", { worker: "learning-writer", scope: topic_slug, revision, artifact: { kind, method: kind === "note" ? "cornell-notes" : "learning-loop", destination_hint: `${kind === "note" ? "notes" : "exercises"}/m-0001.md`, materials_language: "English", module_id: MODULE_ID }, prompt: "Preserve the existing template. Practice was skipped; preserve omission in existing evidence fields." })
    assert.equal(job.status, "completed")
    const output = JSON.parse(job.result)
    await commit({ type: "attach_artifact", event_id: kind.toUpperCase(), path: output.destination_hint, content: output.content, source_revision: job.revision, job_id: job.id })
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
  const initial = topicState("consolidation")
  initial.verified_evidence = [LEARNER_REFERENCE]
  const fixture = await pluginFixture(t, initial)
  const topic_slug = initial.topic.slug
  const job = await fixture.call("learning_job_start", { worker: "learning-writer", scope: topic_slug, revision: REVISION, artifact: { kind: "note", method: "cornell-notes", destination_hint: "notes/m-0001.md", materials_language: "English", module_id: MODULE_ID }, prompt: "Approved outline" })

  // When
  await fixture.call("learning_commit", { topic_slug, expected_revision: REVISION, event: { type: "record_consolidation", event_id: "NEW-EVIDENCE", date: "2026-09-10", module_id: MODULE_ID, learner_evidence: "Updated assessment", evidence_refs: [LEARNER_REFERENCE], blocking_gaps: [] } })
  const output = JSON.parse(job.result)

  // Then
  await assert.rejects(fixture.call("learning_commit", { topic_slug, expected_revision: REVISION + 1, event: { type: "attach_artifact", event_id: "STALE", date: "2026-09-10", module_id: MODULE_ID, path: output.destination_hint, content: output.content, source_revision: REVISION, job_id: job.id } }), /invalid_or_stale_artifact/)
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
  let current = topicState("class")
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

const NEXT_MODULE_ID = "M-0002"
const SCOPE_PROPOSAL = {
  goal: "Explain plugins theoretically and coordinate local and remote work.",
  modules: [
    { id: MODULE_ID, title: "Plugin theory", win: "Explain the plugin contract and safe activation decisions." },
    { id: NEXT_MODULE_ID, title: "Integration", win: "Coordinate local and remote work without a plugin implementation." },
  ],
  reason: "The learner explicitly wants plugins to be theoretical only.",
  retired_requirements: ["Implement, activate, diagnose and disable a real plugin.", "Incorporate a personal plugin in the integration project."],
}

function flexibleTopic() {
  const initial = topicState("consolidation", "none")
  initial.topic.goal = "Implement a plugin and integrate it with local and remote work."
  initial.modules[0].win = "Implement and operate a plugin."
  initial.modules[0].practice_skipped = true
  delete initial.modules[0].attempt
  initial.modules[0].consolidation = { revision: 6, learner_evidence: "Sound theoretical security decisions; no operation observed.", evidence_refs: [LEARNER_REFERENCE], blocking_gaps: ["No implemented plugin."] }
  initial.modules.push({ id: NEXT_MODULE_ID, title: "Integration", win: "Incorporate your plugin.", phase: "mission", taught_concept_ids: [], artifacts: {} })
  initial.verified_evidence = [LEARNER_REFERENCE]
  for (const path of ["notes/m-0001.md", "exercises/m-0001.md"]) initial.artifacts[path] = { content: "# Prior material\n\nPractice omitted, but required by the original goal.", source_revision: 6, module_id: MODULE_ID }
  return initial
}

async function scopeChoice(fixture, initial, selection = "apply") {
  const { resolved } = await fixture.call("learning_event_reference", { event_type: "revise_scope", topic_slug: initial.topic.slug, proposal_json: JSON.stringify(SCOPE_PROPOSAL) })
  const interaction_id = await fixture.choose(resolved.choice.purpose, resolved.consent_subject, resolved.revision, resolved.choice.options, selection)
  return { type: "revise_scope", event_id: "REVISE-SCOPE", date: "2026-09-11", interaction_id, ...SCOPE_PROPOSAL }
}

async function selectModule(fixture, initial, module_id, event_id) {
  const topic_slug = initial.topic.slug
  const { resolved } = await fixture.call("learning_event_reference", { event_type: "select_module", topic_slug, module_id, reason: "The learner needs this module now." })
  const interaction_id = await fixture.choose(resolved.choice.purpose, resolved.consent_subject, resolved.revision, resolved.choice.options, "select")
  return fixture.call("learning_commit", { topic_slug, expected_revision: resolved.revision, event: { type: "select_module", event_id, date: "2026-09-11", interaction_id, module_id, reason: resolved.consent_subject.reason } })
}

test("shouldReviseTheoryScopeAndCloseWithReusedEvidenceAfterRefreshingMaterials", async (t) => {
  // Given
  const initial = flexibleTopic()
  const fixture = await pluginFixture(t, initial)
  const topic_slug = initial.topic.slug
  const event = await scopeChoice(fixture, initial)
  let revision = initial.revision
  const commit = async (event) => {
    const result = await fixture.call("learning_commit", { topic_slug, expected_revision: revision, event: { date: "2026-09-11", ...event } })
    revision = result.revision
    return result
  }

  // When
  await commit(event)
  const revised = await fixture.call("learning_state_read", { topic_slug })
  assert.deepEqual(revised.modules.map(({ id, title, win }) => ({ id, title, win })), SCOPE_PROPOSAL.modules)
  assert.equal(revised.topic.goal, SCOPE_PROPOSAL.goal)
  assert.deepEqual(revised.scope_revisions, [{ ...SCOPE_PROPOSAL, before: { goal: initial.topic.goal, modules: initial.modules.map(({ id, title, win, consolidation }) => ({ id, title, win, ...(consolidation ? { consolidation } : {}) })) }, revision, event_id: event.event_id, date: event.date, interaction_id: event.interaction_id }])
  assert.deepEqual(revised.modules[0].consolidation, initial.modules[0].consolidation)
  const close = { type: "close_module", event_id: "CLOSE-REVISED", module_id: MODULE_ID }
  await assert.rejects(commit(close), /module_close_requirements_not_met/)
  assert.equal((await commit(event)).duplicate, true)
  await commit({ type: "record_consolidation", event_id: "REASSESS", module_id: MODULE_ID, evidence_refs: [LEARNER_REFERENCE], learner_evidence: "The theoretical goal is met. Practical competence is not assessed; its requirement was retired by consent.", blocking_gaps: [] })
  await assert.rejects(commit(close), /module_artifacts_not_current/)
  for (const kind of ["note", "exercise"]) {
    const job = await fixture.call("learning_job_start", { worker: "learning-writer", scope: topic_slug, revision, artifact: { kind, method: kind === "note" ? "cornell-notes" : "learning-loop", destination_hint: `${kind === "note" ? "notes" : "exercises"}/m-0001.md`, materials_language: "English", module_id: MODULE_ID }, prompt: "Revised theoretical goal. Practice omitted and no longer required, not demonstrated. Reuse verified evidence." })
    const output = JSON.parse(job.result)
    await commit({ type: "attach_artifact", event_id: `REVISED-${kind}`, module_id: MODULE_ID, path: output.destination_hint, content: output.content, source_revision: job.revision, job_id: job.id })
  }
  await commit(close)
  const resumed = await LearningRuntimePlugin({ client: fixture.client, directory: fixture.directory })
  const state = JSON.parse(await resumed.tool.learning_state_read.execute({ topic_slug }, CONTEXT))
  await resumed.tool.learning_recover.execute({ topic_slug }, CONTEXT)

  // Then
  assert.deepEqual(state.verified_evidence, initial.verified_evidence)
  assert.deepEqual(state.modules[0].consolidation.evidence_refs, [LEARNER_REFERENCE])
  assert.equal(state.modules[0].phase, "closed")
  assert.equal(state.modules[0].practice_skipped, true)
  assert.equal(state.modules[0].attempt, undefined)
  assert.equal(state.modules[1].phase, "mission")
  assert.equal(state.topic.status, "active")
  assert.equal(state.current_module_id, NEXT_MODULE_ID)
  assert.deepEqual(state.scope_revisions, revised.scope_revisions)
  const mission = await readFile(join(fixture.directory, ".ai/learning", topic_slug, "mission.md"), "utf8")
  assert.match(mission, /Scope revisions/)
  assert.match(mission, /Retired requirements \(not demonstrated\)/)
  assert.match(mission, /Implement a plugin and integrate it/)
})

for (const invalid of ["cancel", "revise", "altered-goal", "altered-module", "altered-reason", "altered-retirements", "wrong-interaction", "stale"]) {
  test(`shouldPreserveStateWhenScopeConsentIs${invalid}`, async (t) => {
    // Given
    const initial = flexibleTopic()
    const fixture = await pluginFixture(t, initial)
    const event = await scopeChoice(fixture, initial, ["cancel", "revise"].includes(invalid) ? invalid : "apply")
    const root = join(fixture.directory, ".ai/learning", initial.topic.slug, ".state.json")
    if (invalid === "altered-goal") event.goal = "Another goal"
    if (invalid === "altered-module") event.modules = [{ ...SCOPE_PROPOSAL.modules[0], win: "Different requirement" }]
    if (invalid === "altered-reason") event.reason = "Another reason"
    if (invalid === "altered-retirements") event.retired_requirements = []
    if (invalid === "wrong-interaction") event.interaction_id = "unknown"
    if (invalid === "stale") await fixture.call("learning_commit", { topic_slug: initial.topic.slug, expected_revision: initial.revision, event: { type: "record_consolidation", event_id: "NEW-ASSESSMENT", date: "2026-09-11", module_id: MODULE_ID, evidence_refs: [LEARNER_REFERENCE], learner_evidence: "Same theory, implementation still absent.", blocking_gaps: ["No implemented plugin."] } })
    const before = await readFile(root, "utf8")
    const current = JSON.parse(before)

    // When / Then
    await assert.rejects(fixture.call("learning_commit", { topic_slug: initial.topic.slug, expected_revision: current.revision, event }), /interaction/)
    assert.equal(await readFile(root, "utf8"), before)
  })
}

test("shouldRequireReassessmentEvenWhenOldConsolidationHasNoGaps", async (t) => {
  // Given
  const initial = flexibleTopic()
  initial.modules[0].consolidation.blocking_gaps = []
  const fixture = await pluginFixture(t, initial)
  const event = await scopeChoice(fixture, initial)

  // When
  const revised = await fixture.call("learning_commit", { topic_slug: initial.topic.slug, expected_revision: initial.revision, event })

  // Then
  await assert.rejects(fixture.call("learning_commit", { topic_slug: initial.topic.slug, expected_revision: revised.revision, event: { type: "close_module", event_id: "CLOSE", date: "2026-09-11", module_id: MODULE_ID } }), /scope_requires_reassessment/)
})

test("shouldDeferResumeAndPreservePendingWorkAcrossRestart", async (t) => {
  // Given
  const initial = flexibleTopic()
  const fixture = await pluginFixture(t, initial)
  const topic_slug = initial.topic.slug

  // When
  await selectModule(fixture, initial, NEXT_MODULE_ID, "MOVE")
  const resumed = await LearningRuntimePlugin({ client: fixture.client, directory: fixture.directory })
  const state = JSON.parse(await resumed.tool.learning_state_read.execute({ topic_slug }, CONTEXT))
  const path = await readFile(join(fixture.directory, ".ai/learning", topic_slug, "path.md"), "utf8")
  await assert.rejects(fixture.call("learning_commit", { topic_slug, expected_revision: state.revision, event: { type: "complete_topic", event_id: "COMPLETE", date: "2026-09-11", evidence_refs: [LEARNER_REFERENCE] } }), /topic_has_open_modules/)
  await selectModule(fixture, initial, MODULE_ID, "RETURN")
  const returned = await fixture.call("learning_state_read", { topic_slug })

  // Then
  assert.equal(state.current_module_id, NEXT_MODULE_ID)
  assert.deepEqual({ ...state.modules[0], deferred: undefined }, { ...initial.modules[0], deferred: undefined })
  assert.equal(state.modules[0].deferred.reason, "The learner needs this module now.")
  assert.deepEqual(state.modules[1], initial.modules[1])
  assert.deepEqual(state.topic, initial.topic)
  assert.deepEqual(state.artifacts, initial.artifacts)
  assert.match(path, /Current module: M-0002/)
  assert.match(path, /deferred: The learner needs this module now/)
  assert.equal(returned.current_module_id, MODULE_ID)
  assert.deepEqual(returned.modules[0], initial.modules[0])
  assert.equal(returned.modules[1].deferred.reason, "The learner needs this module now.")
})

for (const invalid of ["cancel", "altered-reason", "wrong-module", "unshown", "stale"]) {
  test(`shouldPreserveStateWhenModuleSelectionIs${invalid}`, async (t) => {
    // Given
    const initial = flexibleTopic()
    const fixture = await pluginFixture(t, initial)
    const topic_slug = initial.topic.slug
    const { resolved } = await fixture.call("learning_event_reference", { event_type: "select_module", topic_slug, module_id: NEXT_MODULE_ID, reason: "Urgent priority" })
    let interaction_id
    if (invalid === "unshown") interaction_id = (await fixture.call("learning_choice", { purpose: resolved.choice.purpose, revision: resolved.revision, subject_json: resolved.subject_json, question: "¿Avanzar?", options: resolved.choice.options.map((id) => ({ id, label: id, description: id })) })).id
    else interaction_id = await fixture.choose(resolved.choice.purpose, resolved.consent_subject, resolved.revision, resolved.choice.options, invalid === "cancel" ? "cancel" : "select")
    const event = { type: "select_module", event_id: "MOVE", date: "2026-09-11", module_id: NEXT_MODULE_ID, reason: "Urgent priority", interaction_id }
    if (invalid === "altered-reason") event.reason = "Different reason"
    if (invalid === "wrong-module") event.module_id = "M-9999"
    const root = join(fixture.directory, ".ai/learning", topic_slug, ".state.json")
    const before = await readFile(root, "utf8")

    // When / Then
    await assert.rejects(fixture.call("learning_commit", { topic_slug, expected_revision: initial.revision + (invalid === "stale" ? 1 : 0), event }), /interaction|unknown_module|revision_conflict/)
    assert.equal(await readFile(root, "utf8"), before)
  })
}

test("shouldRejectSkipBeforeClassAndKeepLegacyOperationsUnavailable", () => {
  // Given
  const initial = topicState("mission")
  const choice = answeredReadiness(initial)

  // When / Then
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(initial, initial.topic.slug, skipEvent(choice), choice), /practice_requires_class_or_unfinished_practice/)
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(initial, initial.topic.slug, { type: "preview_cards", event_id: "OLD", date: "2026-09-11" }), /unsupported_event_type/)
  assert.equal(initial.modules[0].retention, undefined)
  assert.equal(initial.cards, undefined)
})

for (const invalid of ["unknown-module", "closed-module", "duplicate-module", "empty-modules", "empty-goal", "completed-topic"]) {
  test(`shouldRejectScopeProposalWhen${invalid}`, async (t) => {
    // Given
    const initial = flexibleTopic()
    const proposal = structuredClone(SCOPE_PROPOSAL)
    if (invalid === "closed-module") initial.modules[1].phase = "closed"
    if (invalid === "unknown-module") proposal.modules[1].id = "M-9999"
    if (invalid === "duplicate-module") proposal.modules.push(proposal.modules[0])
    if (invalid === "empty-modules") proposal.modules = []
    if (invalid === "empty-goal") proposal.goal = " "
    if (invalid === "completed-topic") {
      initial.modules.forEach((module) => { module.phase = "closed" })
      initial.topic.status = "completed"
      initial.topic.completion = { date: "2026-09-11", event_id: "OLD-COMPLETE", evidence: LEARNER_REFERENCE.quote, evidence_refs: [LEARNER_REFERENCE] }
      initial.applied_events["OLD-COMPLETE"] = "0".repeat(64)
    }
    const fixture = await pluginFixture(t, initial)

    // When / Then
    await assert.rejects(fixture.call("learning_event_reference", { event_type: "revise_scope", topic_slug: initial.topic.slug, proposal_json: JSON.stringify(proposal) }), /unknown_module|closed_module_scope_immutable|duplicate_module_id|affected_modules_required|invalid_goal|topic_already_completed/)
    assert.deepEqual(await fixture.call("learning_state_read", { topic_slug: initial.topic.slug }), initial)
  })
}

test("shouldOfferDeferredWorkAfterClosingTheSelectedModule", async (t) => {
  // Given
  const initial = flexibleTopic()
  initial.modules[1] = { ...structuredClone(initial.modules[0]), id: NEXT_MODULE_ID, consolidation: { ...initial.modules[0].consolidation, blocking_gaps: [] }, artifacts: { note: "notes/m-0002.md", exercise: "exercises/m-0002.md" } }
  for (const path of ["notes/m-0002.md", "exercises/m-0002.md"]) initial.artifacts[path] = { content: "# Current material", source_revision: 6, module_id: NEXT_MODULE_ID }
  const fixture = await pluginFixture(t, initial)
  const topic_slug = initial.topic.slug

  // When
  const selected = await selectModule(fixture, initial, NEXT_MODULE_ID, "SELECT")
  await fixture.call("learning_commit", { topic_slug, expected_revision: selected.revision, event: { type: "close_module", event_id: "CLOSE-SELECTED", date: "2026-09-11", module_id: NEXT_MODULE_ID } })
  const state = await fixture.call("learning_state_read", { topic_slug })
  const path = await readFile(join(fixture.directory, ".ai/learning", topic_slug, "path.md"), "utf8")
  const { resolved } = await fixture.call("learning_event_reference", { event_type: "select_module", topic_slug, module_id: MODULE_ID, reason: "Return to pending work" })

  // Then
  assert.equal(state.current_module_id, undefined)
  assert.equal(state.modules[0].phase, "consolidation")
  assert.ok(state.modules[0].deferred)
  assert.equal(state.modules[1].phase, "closed")
  assert.equal(state.modules[1].deferred, undefined)
  assert.match(path, /none; choose a deferred module/)
  assert.equal(resolved.consent_subject.from_module_id, null)
})

test("shouldReplayNavigationWithoutDuplicatingConsentAndRejectChangedReplay", async (t) => {
  // Given
  const initial = flexibleTopic()
  const fixture = await pluginFixture(t, initial)
  const topic_slug = initial.topic.slug
  const { resolved } = await fixture.call("learning_event_reference", { event_type: "select_module", topic_slug, module_id: NEXT_MODULE_ID, reason: "Priority" })
  const interaction_id = await fixture.choose(resolved.choice.purpose, resolved.consent_subject, resolved.revision, resolved.choice.options, "select")
  const event = { type: "select_module", event_id: "MOVE", date: "2026-09-11", module_id: NEXT_MODULE_ID, reason: "Priority", interaction_id }
  const args = { topic_slug, expected_revision: initial.revision, event }

  // When
  await fixture.call("learning_commit", args)
  const before = await fixture.call("learning_state_read", { topic_slug })
  const replay = await fixture.call("learning_commit", args)

  // Then
  assert.equal(replay.duplicate, true)
  assert.deepEqual(await fixture.call("learning_state_read", { topic_slug }), before)
  await assert.rejects(fixture.call("learning_commit", { ...args, event: { ...event, reason: "Changed" } }), /event_id_conflict/)
})

for (const mutation of ["history-shape", "history-entry", "history-module", "current-closed", "deferred-shape", "scope-revision"]) {
  test(`shouldRejectMalformedOptionalProgressStateWhen${mutation}`, async (t) => {
    // Given
    const initial = flexibleTopic()
    if (mutation === "history-shape") initial.scope_revisions = {}
    if (mutation === "history-entry") initial.scope_revisions = [null]
    if (mutation === "history-module") { initial.scope_revisions = [{ revision: 7, modules: {} }]; initial.modules[0].scope_revision = 7 }
    if (mutation === "current-closed") { initial.current_module_id = NEXT_MODULE_ID; initial.modules[1].phase = "closed" }
    if (mutation === "deferred-shape") initial.modules[0].deferred = true
    if (mutation === "scope-revision") initial.modules[0].scope_revision = initial.revision + 1
    const fixture = await pluginFixture(t, initial)

    // When / Then
    await assert.rejects(fixture.call("learning_state_read", { topic_slug: initial.topic.slug }), /state_malformed/)
  })
}
