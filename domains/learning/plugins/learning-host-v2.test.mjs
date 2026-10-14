import assert from "node:assert/strict"
import { test } from "node:test"
import { createHash } from "node:crypto"
import { mkdtemp, readFile, rm } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import plugin, { LearningRuntimePlugin, learningRuntimeContracts } from "./learning-runtime.ts"
import { learningHostV2 } from "./learning-host-v2.ts"

// Contract fixtures, NOT a running host. Shapes/signatures are from the official
// anomalyco/opencode v2.0.28 Promise adapter, protocol/groups/session.ts,
// schema/{form,event,session-message}.ts and core/tool/plugin/question.ts.
const PARENT = "ses_parent"
const ASSISTANT = "msg_assistant"
const NATIVE_CONTEXT = { sessionID: PARENT, messageID: ASSISTANT, agent: "mentor", id: "call_learning", signal: new AbortController().signal }
const CONTEXT = { ...NATIVE_CONTEXT, abort: NATIVE_CONTEXT.signal }
const PERMISSIONS = [
  { action: "edit", resource: "*", effect: "deny" },
  { action: "shell", resource: "*", effect: "deny" },
  { action: "subagent", resource: "*", effect: "deny" },
]
const TOOLS = ["learning_context", "learning_event_reference", "learning_evidence", "learning_state_read", "learning_commit", "learning_recover", "learning_choice", "learning_choice_result", "learning_job_start", "learning_job_result", "learning_summary_create"]
const MODEL = { providerID: "fixture", id: "bounded", variant: "default" }
const USER = { id: "msg_user", type: "user", text: "Only the learner said this literal excerpt.", time: { created: 1 } }
const PARENT_ASSISTANT = { id: ASSISTANT, type: "assistant", agent: "mentor", model: MODEL, content: [{ type: "text", text: "Assistant-only assertion." }], time: { created: 2 } }
const tick = () => new Promise((resolve) => setImmediate(resolve))

function deferred() {
  let resolve, reject
  const promise = new Promise((yes, no) => { resolve = yes; reject = no })
  return { promise, resolve, reject }
}

async function hostFixture(t) {
  const directory = await mkdtemp(join(tmpdir(), "learning-v2-contract-"))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const tools = new Map(), hooks = new Map(), records = new Map(), requests = []
  let created = 0, promptFailure = false, disposed = 0, streamClosed = false, promptGate
  const info = (id, parentID, permissions) => ({
    id, ...(parentID ? { parentID, permissions: structuredClone(permissions) } : {}), projectID: "prj_fixture", location: { directory },
    cost: 0, tokens: { input: 0, output: 0, reasoning: 0, cache: { read: 0, write: 0 } }, time: { created: 1, updated: 1 },
  })
  records.set(PARENT, { info: info(PARENT), context: [USER, PARENT_ASSISTANT], settled: deferred() })
  const queue = [], wake = deferred()
  let waiting = wake
  const ctx = {
    app: { version: "2.0.28" }, location: { directory },
    agent: { list: async () => ({ location: { directory }, data: ["learning-researcher", "learning-writer", "learning-summarizer"].map((id) => ({
      id, name: id, model: MODEL, request: { settings: {}, headers: {}, body: {} }, mode: "subagent", hidden: false, permissions: [],
    })) }) },
    event: { subscribe: ({ signal }) => ({ async *[Symbol.asyncIterator]() {
      const abort = () => waiting.resolve()
      signal.addEventListener("abort", abort, { once: true })
      try {
        while (!signal.aborted) {
          if (!queue.length) await waiting.promise
          if (signal.aborted) break
          while (queue.length) yield queue.shift()
          waiting = deferred()
        }
      } finally { streamClosed = true; signal.removeEventListener("abort", abort) }
    } }) },
    tool: {
      hook: async (name, callback) => {
        assert.equal(name, "execute.before")
        hooks.set(name, callback)
        return { dispose: async () => { disposed++; hooks.delete(name) } }
      },
      transform: async (callback) => {
        callback({ add: (tool) => tools.set(tool.name, tool) })
        return { dispose: async () => { disposed++; tools.clear() } }
      },
    },
    session: {
      get: async (input) => {
        assert.deepEqual(Object.keys(input), ["sessionID"])
        requests.push(["get", input])
        if (!records.has(input.sessionID)) throw new Error("uncertain missing session")
        return structuredClone(records.get(input.sessionID).info)
      },
      context: async (input) => { requests.push(["context", input]); return structuredClone(records.get(input.sessionID).context) },
      create: async (input) => {
        requests.push(["create", input])
        assert.deepEqual(input.permissions, PERMISSIONS)
        const id = `ses_child_${++created}`
        records.set(id, { info: info(id, input.parentID, input.permissions), context: [], settled: deferred() })
        return structuredClone(records.get(id).info)
      },
      switchAgent: async (input) => { requests.push(["switchAgent", input]); records.get(input.sessionID).info.agent = input.agent },
      switchModel: async (input) => { requests.push(["switchModel", input]); records.get(input.sessionID).info.model = input.model },
      prompt: async (input) => {
        requests.push(["prompt", input])
        const record = records.get(input.sessionID)
        record.context.push({ ...USER, id: "msg_child_input", text: input.text })
        const admitted = { type: "user", id: "msg_child_input", sessionID: input.sessionID, time: { created: 1 }, payload: { text: input.text }, delivery: "steer" }
        if (promptGate) await promptGate.promise
        if (promptFailure) throw new Error("admission response lost")
        return admitted
      },
      wait: async (input) => { requests.push(["wait", input]); await records.get(input.sessionID).settled.promise },
      interrupt: async (input) => {
        requests.push(["interrupt", input])
        assert.deepEqual(input, { sessionID: input.sessionID, resume: false })
        records.get(input.sessionID).settled.resolve()
        return { interrupted: true }
      },
    },
  }
  const emit = async (type, data) => {
    queue.push({ id: "evt_fixture", type, created: 1, location: { directory }, data })
    waiting.resolve()
    await tick()
  }
  const finish = (id, text = "Bounded worker output") => {
    const record = records.get(id)
    record.context.push({ id: "msg_child_output", type: "assistant", agent: record.info.agent, model: MODEL,
      content: [{ type: "text", text }], finish: "stop", time: { created: 3, completed: 4 } },
    { id: "msg_child_idle", type: "idle", outcome: "succeeded", time: { created: 5 } })
    record.settled.resolve()
  }
  return { ctx, tools, hooks, records, requests, emit, finish,
    losePromptResponse: () => { promptFailure = true },
    delayPrompt: () => { promptGate = deferred(); return promptGate },
    counts: () => ({ created, disposed, streamClosed }) }
}

async function nativeChoice(fixture, purpose = "summary", subject = { scope: "summaries" }, options = ["save", "none"], multiple = false) {
  const call = async (name, input) => JSON.parse((await fixture.tools.get(name).execute(input, NATIVE_CONTEXT)).content)
  const choice = await call("learning_choice", { purpose, revision: 0, subject_json: JSON.stringify(subject), question: "Confirm?",
    options: options.map((id) => ({ id, label: id, description: id })), ...(multiple ? { multiple } : {}) })
  const event = { ...NATIVE_CONTEXT, tool: "question", id: `call_${choice.id}`, input: structuredClone(choice.next_args) }
  await fixture.hooks.get("execute.before")(event)
  // Native question.ts toField output, not output invented by this adapter.
  const question = event.input.questions[0]
  const form = { id: `frm_${choice.id}`, sessionID: PARENT, title: "Questions", metadata: { kind: "question", tool: { messageID: ASSISTANT, id: event.id } },
    fields: [{ key: "q0", title: question.header, description: question.question, type: multiple ? "multiselect" : "string",
      options: question.options.map((option) => ({ value: option.label, label: option.label, description: option.description })), custom: true }] }
  return { call, choice, event, form }
}

test("shouldRegisterElevenJsonSchemaToolsAndDisposeV2ResourcesWithoutV1Dependencies", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  // When
  const cleanup = await plugin.setup(fixture.ctx)
  const captured = fixture.tools.get("learning_context")
  const result = JSON.parse((await captured.execute({}, NATIVE_CONTEXT)).content)
  // Then
  assert.deepEqual([...fixture.tools.keys()], TOOLS)
  assert.equal(result.state_schema, 1)
  assert.equal(result.sequential_jobs, true)
  assert.deepEqual(captured.input, { type: "object", properties: {}, required: [], additionalProperties: false })
  assert.deepEqual(fixture.tools.get("learning_commit").input.required, ["topic_slug", "expected_revision", "event"])
  assert.equal(fixture.tools.get("learning_commit").input.properties.event.additionalProperties, true)
  await cleanup()
  await cleanup()
  assert.deepEqual(fixture.counts(), { created: 0, disposed: 2, streamClosed: true })
  await assert.rejects(captured.execute({}, NATIVE_CONTEXT), /learning_plugin_disposed/)
})

for (const negative of ["foreign-session", "foreign-call", "foreign-message", "changed-fields", "rejected", "unknown-selection", "extra-field", "replay"]) {
  test(`shouldFailClosedWhenNativeConsentIs${negative}`, async (t) => {
    // Given
    const fixture = await hostFixture(t)
    const cleanup = await plugin.setup(fixture.ctx)
    t.after(cleanup)
    const { call, choice, form } = await nativeChoice(fixture)
    const shown = structuredClone(form)
    if (negative === "foreign-call") shown.metadata.tool.id = "foreign"
    if (negative === "foreign-message") shown.metadata.tool.messageID = "msg_foreign"
    if (negative === "changed-fields") shown.fields[0].description = "Changed by model"
    // When
    await fixture.emit("form.created", { form: shown })
    if (negative === "rejected") await fixture.emit("form.cancelled", { id: form.id, sessionID: PARENT })
    else await fixture.emit("form.replied", { id: form.id, sessionID: negative === "foreign-session" ? "ses_foreign" : PARENT,
      answer: negative === "extra-field" ? { q0: "save", q1: "save" } : { q0: negative === "unknown-selection" ? "invented" : "save" } })
    const result = await call("learning_choice_result", { id: choice.id })
    // Then
    if (negative !== "replay") assert.notEqual(result.status, "answered")
    else {
      assert.deepEqual(result.selected, ["save"])
      await fixture.emit("form.replied", { id: form.id, sessionID: PARENT, answer: { q0: "none" } })
      assert.deepEqual((await call("learning_choice_result", { id: choice.id })).selected, ["save"])
      const next = await nativeChoice(fixture)
      await fixture.emit("form.replied", { id: form.id, sessionID: PARENT, answer: { q0: "save" } })
      assert.equal((await next.call("learning_choice_result", { id: next.choice.id })).status, "not_shown")
    }
  })
}

test("shouldCommitSchemaOneOnlyAfterCorrelatedNativeMissionConsent", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const cleanup = await plugin.setup(fixture.ctx)
  t.after(cleanup)
  const subject = { topic_slug: "native-topic", title: "Native", materials_language: "English", goal: "Verify safely",
    concepts: [{ id: "K-0001", title: "Native", prerequisites: [], fundamental: false }], modules: [{ id: "M-0001", title: "Native", win: "Verify safely" }] }
  const { call, choice, form } = await nativeChoice(fixture, "mission", subject, ["create", "revise", "cancel"])
  const event = { ...subject, type: "create_topic", event_id: "CREATE", date: "2026-10-14", interaction_id: choice.id }
  delete event.topic_slug
  // When
  await assert.rejects(call("learning_commit", { topic_slug: subject.topic_slug, expected_revision: 0, event }), /verified_interaction_required/)
  await fixture.emit("form.created", { form })
  await fixture.emit("form.replied", { id: form.id, sessionID: PARENT, answer: { q0: "create" } })
  const result = await call("learning_commit", { topic_slug: subject.topic_slug, expected_revision: 0, event })
  // Then
  assert.equal(result.revision, 1)
  const state = JSON.parse(await readFile(join(fixture.ctx.location.directory, ".ai/learning/native-topic/.state.json"), "utf8"))
  assert.equal(state.schema_version, 1)
  assert.deepEqual(state.consents[0].selected, ["create"])
  assert.equal(state.consents[0].request_id, form.id)
  const before = await readFile(join(fixture.ctx.location.directory, ".ai/learning/native-topic/.state.json"), "utf8")
  await cleanup()
  const resumedCleanup = await plugin.setup(fixture.ctx)
  t.after(resumedCleanup)
  assert.deepEqual(JSON.parse((await fixture.tools.get("learning_state_read").execute({ topic_slug: subject.topic_slug }, NATIVE_CONTEXT)).content), state)
  assert.equal(await readFile(join(fixture.ctx.location.directory, ".ai/learning/native-topic/.state.json"), "utf8"), before)
})

test("shouldAcceptNativeMultiselectAndIgnoreUnrelatedQuestionCalls", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const cleanup = await plugin.setup(fixture.ctx)
  t.after(cleanup)
  const unrelated = { ...NATIVE_CONTEXT, tool: "question", id: "call_unrelated", input: { questions: [{ header: "Unrelated", question: "Choose?", options: [{ label: "Other", description: "Other" }] }] } }
  const original = { ...unrelated, input: structuredClone(unrelated.input) }
  // When
  await fixture.hooks.get("execute.before")(unrelated)
  const { call, choice, form } = await nativeChoice(fixture, "export", { topic_slug: "native-topic" }, ["V-0001", "V-0002", "none"], true)
  await fixture.emit("form.created", { form })
  await fixture.emit("form.replied", { id: form.id, sessionID: PARENT, answer: { q0: ["V-0002", "V-0001"] } })
  // Then
  assert.deepEqual(unrelated, original)
  const result = await call("learning_choice_result", { id: choice.id })
  assert.equal(result.status, "answered")
  assert.deepEqual(result.selected, ["V-0001", "V-0002"])
})

test("shouldRejectMissingNativeSessionCapabilityBeforeCreatingChildOrRegisteringHooks", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  delete fixture.ctx.session.prompt
  // When / Then
  await assert.rejects(plugin.setup(fixture.ctx), /sequential_session_api_unavailable/)
  assert.equal(fixture.tools.size, 0)
  assert.equal(fixture.hooks.size, 0)
  assert.equal(fixture.counts().created, 0)
})

test("shouldAddressOnlyNativeRootUserTextAndReuseOnlyExactHistoricalEvidence", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const client = learningHostV2.createClient(fixture.ctx, () => {})
  const evidence = learningRuntimeContracts.createEvidence(client)
  fixture.records.get(PARENT).context.push({ id: "msg_synthetic", type: "synthetic", text: "Synthetic-only assertion.", time: { created: 3 } })
  const hash = createHash("sha256").update(JSON.stringify([PARENT, USER.id])).digest("hex")
  // When
  const refs = await evidence.locate(PARENT, ["literal excerpt"])
  // Then
  assert.deepEqual(refs, [{ session_id: PARENT, message_id: USER.id, part_id: `v2:text:${hash}`, quote: "literal excerpt" }])
  assert.equal(refs[0].part_id.length, 72)
  assert.notEqual(learningHostV2.textID("ses_foreign", USER.id), refs[0].part_id)
  for (const quote of ["Assistant-only assertion", "Synthetic-only assertion"]) await assert.rejects(evidence.locate(PARENT, [quote]), /learner_excerpt_not_found/)
  const verify = (ref, stored = []) => evidence.verify(PARENT, { type: "record_attempt", outcome: "done", evidence_refs: [ref] }, { verified_evidence: stored })
  const old = { ...refs[0], part_id: "prt_old_native" }
  await assert.rejects(verify(old), /unverified_evidence_reference/)
  await assert.rejects(verify({ ...refs[0], message_id: "msg_other" }), /unverified_evidence_reference/)
  await assert.rejects(verify({ ...refs[0], session_id: "ses_foreign" }), /foreign_evidence_reference/)
  await assert.rejects(verify({ ...refs[0], quote: "Not the learner's text" }), /unverified_evidence_reference/)
  const historical = structuredClone(old)
  const before = fixture.requests.length
  assert.deepEqual(await verify(old, [historical]), [old])
  assert.equal(fixture.requests.length, before)
  assert.deepEqual(historical, old)
  await assert.rejects(verify({ ...old, quote: "literal" }, [historical]), /unverified_evidence_reference/)
  fixture.records.get(PARENT).info.parentID = "ses_foreign"
  fixture.records.get(PARENT).info.permissions = PERMISSIONS
  await assert.rejects(evidence.locate(PARENT, ["literal excerpt"]), /learner_session_required/)
})

test("shouldKeepNativeChildRestrictedSequentialAndRecoverSameAcceptedSession", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const client = learningHostV2.createClient(fixture.ctx, () => {})
  const jobs = learningRuntimeContracts.createJobs(client)
  fixture.losePromptResponse()
  const input = { worker: "learning-researcher", scope: "session-native", revision: 0, prompt: "One bounded question" }
  // When
  const accepted = await jobs.launch(CONTEXT, input)
  await assert.rejects(jobs.launch(CONTEXT, input), /learning_job_pending/)
  const restored = learningRuntimeContracts.createJobs(learningHostV2.createClient(fixture.ctx, () => {}))
  restored.restore({ id: accepted.id, parent_id: PARENT, worker: input.worker, source_revision: 0, status: accepted.status }, input.scope)
  fixture.finish(accepted.id)
  const result = await restored.wait(PARENT, accepted.id)
  // Then
  assert.equal(result.status, "completed")
  assert.equal(result.result, "Bounded worker output")
  assert.equal(fixture.counts().created, 1)
  assert.deepEqual(fixture.requests.find(([name]) => name === "create")[1], { parentID: PARENT, title: "learning-researcher: session-native", permissions: PERMISSIONS })
  assert.deepEqual(fixture.requests.find(([name]) => name === "switchAgent")[1], { sessionID: accepted.id, agent: "learning-researcher" })
  assert.deepEqual(fixture.requests.find(([name]) => name === "switchModel")[1], { sessionID: accepted.id, model: MODEL })
  assert.deepEqual(fixture.requests.find(([name]) => name === "prompt")[1], { sessionID: accepted.id, text: input.prompt })
})

test("shouldNotSettleFromCompletedAssistantWithoutNativeWaitAndIdleReceipts", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const child = await fixture.ctx.session.create({ parentID: PARENT, title: "Recovered", permissions: PERMISSIONS })
  const record = fixture.records.get(child.id)
  record.context = [{ ...USER, id: "msg_child_input" }, { ...PARENT_ASSISTANT, id: "msg_child_output", finish: "stop", time: { created: 2, completed: 3 } }]
  const jobs = learningRuntimeContracts.createJobs(learningHostV2.createClient(fixture.ctx, () => {}))
  jobs.restore({ id: child.id, parent_id: PARENT, worker: "learning-researcher", source_revision: 0, status: "running" }, "session-native")
  // When
  const busy = await jobs.inspect(PARENT, child.id)
  fixture.finish(child.id)
  const completed = await jobs.wait(PARENT, child.id)
  // Then
  assert.equal(busy.status, "running")
  assert.equal(completed.status, "completed")
  assert.equal(fixture.counts().created, 1)
})

test("shouldRejectPermissionDriftAndUseNativeInterruptSettlementForCancellation", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const client = learningHostV2.createClient(fixture.ctx, () => {})
  const child = await fixture.ctx.session.create({ parentID: PARENT, title: "Recovered", permissions: PERMISSIONS })
  const jobs = learningRuntimeContracts.createJobs(client)
  jobs.restore({ id: child.id, parent_id: PARENT, worker: "learning-researcher", source_revision: 0, status: "running" }, "session-native")
  fixture.records.get(child.id).info.permissions.push({ action: "edit", resource: "*", effect: "allow" })
  // When / Then
  await assert.rejects(jobs.inspect(PARENT, child.id), /restricted_child_not_confirmed/)
  fixture.records.get(child.id).info.permissions = structuredClone(PERMISSIONS)
  const cancelled = await jobs.cancel(PARENT, child.id)
  assert.equal(cancelled.status, "cancelled")
  assert.deepEqual(fixture.requests.find(([name]) => name === "interrupt")[1], { sessionID: child.id, resume: false })
})

test("shouldRetainAcceptedChildIdentityWhenNativeRestrictionReceiptIsInvalid", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const create = fixture.ctx.session.create
  fixture.ctx.session.create = async (input) => {
    const child = await create(input)
    fixture.records.get(child.id).info.permissions = []
    return { ...child, permissions: [] }
  }
  const jobs = learningRuntimeContracts.createJobs(learningHostV2.createClient(fixture.ctx, () => {}))
  const input = { worker: "learning-researcher", scope: "session-native", revision: 0, prompt: "Bounded" }
  // When
  const accepted = await jobs.launch(CONTEXT, input)
  // Then
  assert.equal(accepted.id, "ses_child_1")
  assert.equal(accepted.status, "starting")
  await assert.rejects(jobs.launch(CONTEXT, input), /restricted_child_not_confirmed/)
  assert.equal(fixture.counts().created, 1)
  assert.equal(fixture.requests.some(([name]) => name === "prompt"), false)
})

test("shouldSerializeCancellationAfterUninterruptibleNativePromptAdmission", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const gate = fixture.delayPrompt()
  const controller = new AbortController()
  const jobs = learningRuntimeContracts.createJobs(learningHostV2.createClient(fixture.ctx, () => {}))
  const launch = jobs.launch({ ...CONTEXT, abort: controller.signal }, { worker: "learning-researcher", scope: "session-native", revision: 0, prompt: "Bounded" })
  await tick()
  assert.equal(fixture.requests.some(([name]) => name === "prompt"), true)
  // When
  controller.abort()
  await tick()
  assert.equal(fixture.requests.some(([name]) => name === "interrupt"), false)
  gate.resolve()
  const result = await launch
  // Then
  assert.equal(result.status, "cancelled")
  assert.equal(fixture.counts().created, 1)
  assert.deepEqual(fixture.requests.find(([name]) => name === "interrupt")[1], { sessionID: "ses_child_1", resume: false })
})

test("shouldKeepCancellationUnsettledWhenNativeInterruptWasOnlyIdleNoOp", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const child = await fixture.ctx.session.create({ parentID: PARENT, title: "Recovered", permissions: PERMISSIONS })
  fixture.ctx.session.interrupt = async () => ({ interrupted: false })
  fixture.records.get(child.id).settled.resolve()
  const client = learningHostV2.createClient(fixture.ctx, () => {})
  // When
  await client.session.abort({ path: { id: child.id } })
  await client.session.messages({ path: { id: child.id } })
  await tick()
  // Then
  assert.deepEqual(await client.session.status(), { data: { [child.id]: { type: "busy" } } })
})

test("shouldPreserveBoundedArgumentsAndRejectNonMentorToolsInV2", async (t) => {
  // Given
  const fixture = await hostFixture(t)
  const cleanup = await plugin.setup(fixture.ctx)
  t.after(cleanup)
  // When / Then
  await assert.rejects(fixture.tools.get("learning_choice_result").execute({ id: "invented" }, NATIVE_CONTEXT), /invalid_learning_tool_input/)
  await assert.rejects(fixture.tools.get("learning_evidence").execute({ excerpts: ["literal"] }, { ...NATIVE_CONTEXT, agent: "learning-writer" }), /learning_teacher_required/)
  await assert.rejects(fixture.tools.get("learning_commit").execute({ topic_slug: "../escape", expected_revision: -1, event: {} }, NATIVE_CONTEXT), /invalid_learning_tool_input/)
  const tools = await LearningRuntimePlugin({ client: learningHostV2.createClient(fixture.ctx, () => {}), directory: fixture.ctx.location.directory, toolHelper: learningHostV2.schemaTool() })
  assert.deepEqual(Object.keys(tools.tool), TOOLS)
})
