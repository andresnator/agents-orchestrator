import { createHash } from "node:crypto"

// Portable business seam; these legacy-shaped DTOs are internal, not V2 API signatures.
export type LearningToolContext = { agent: string; sessionID: string; messageID: string; callID?: string; abort: AbortSignal }
export type LearningBusinessPlugin = (input: { client: any; directory: string; toolHelper?: any }) => Promise<any>

// API receipts: anomalyco/opencode tag v2.0.28:
// packages/plugin/src/promise/{adapter,session,tool}.ts
// packages/core/src/tool/plugin/question.ts; packages/schema/src/{form,event,session-message}.ts
// The adapter addresses the native User.text property; this is NOT a native part ID.
const TEXT_ID_PREFIX = "v2:text:"
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const CHILD_PERMISSIONS = ["edit", "shell", "subagent"].map((action) => ({ action, resource: "*", effect: "deny" }))
const MAX_RECEIPTS = 1000

function textID(sessionID: string, messageID: string) {
  return TEXT_ID_PREFIX + createHash("sha256").update(JSON.stringify([sessionID, messageID])).digest("hex")
}

function canonical(value: unknown): string {
  return JSON.stringify(value, (_key, item) => item && typeof item === "object" && !Array.isArray(item)
    ? Object.fromEntries(Object.keys(item).sort().map((key) => [key, item[key]])) : item)
}

// A small, dependency-free schema vocabulary for the existing business factory.
// The live registration contains ordinary JSON Schema, never the V1 helper or Zod.
function descriptor(json: any, optional = false): any {
  const changed = (patch: any) => descriptor({ ...json, ...patch }, optional)
  return {
    json, isOptional: optional,
    optional: () => descriptor(json, true),
    describe: (description: string) => changed({ description }),
    min: (value: number) => changed({ [json.type === "array" ? "minItems" : "minLength"]: value }),
    max: (value: number) => changed({ [json.type === "array" ? "maxItems" : "maxLength"]: value }),
    regex: (pattern: RegExp) => changed({ pattern: pattern.source }),
    uuid: () => changed({ pattern: UUID_PATTERN.source }),
    int: () => changed({ type: "integer" }),
    nonnegative: () => changed({ minimum: 0 }),
    default: (value: unknown) => descriptor({ ...json, default: value }, true),
    strict: () => changed({ additionalProperties: false }),
    passthrough: () => changed({ additionalProperties: true }),
    parse: (value: unknown) => parse(json, value),
  }
}

function object(properties: Record<string, any>) {
  return descriptor({
    type: "object", properties: Object.fromEntries(Object.entries(properties).map(([key, value]) => [key, value.json])),
    required: Object.keys(properties).filter((key) => !properties[key].isOptional), additionalProperties: false,
  })
}

function parse(schema: any, value: any): any {
  if (value === undefined && "default" in schema) return structuredClone(schema.default)
  const invalid = () => { throw new Error("invalid_learning_tool_input") }
  if (schema.enum && !schema.enum.includes(value)) invalid()
  if (schema.type === "string") {
    if (typeof value !== "string" || value.length < (schema.minLength ?? 0) || value.length > (schema.maxLength ?? Infinity)
      || schema.pattern && !new RegExp(schema.pattern).test(value)) invalid()
  } else if (schema.type === "boolean") {
    if (typeof value !== "boolean") invalid()
  } else if (schema.type === "number" || schema.type === "integer") {
    if (typeof value !== "number" || !Number.isFinite(value) || value < (schema.minimum ?? -Infinity)
      || schema.type === "integer" && !Number.isInteger(value)) invalid()
  } else if (schema.type === "array") {
    if (!Array.isArray(value) || value.length < (schema.minItems ?? 0) || value.length > (schema.maxItems ?? Infinity)) invalid()
    return value.map((item: unknown) => parse(schema.items, item))
  } else if (schema.type === "object") {
    if (!value || typeof value !== "object" || Array.isArray(value)) invalid()
    if (schema.required?.some((key: string) => value[key] === undefined)) invalid()
    if (schema.additionalProperties === false && Object.keys(value).some((key) => !(key in schema.properties))) invalid()
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, schema.properties[key] ? parse(schema.properties[key], item) : item])
      .concat(Object.entries(schema.properties).filter(([key, item]: any) => !(key in value) && "default" in item)
        .map(([key, item]: any) => [key, structuredClone(item.default)])))
  }
  return value
}

function schemaTool() {
  const tool: any = (definition: any) => {
    const input = object(definition.args)
    return { ...definition, input: input.json, execute: (value: unknown, context: any) => definition.execute(input.parse(value), context) }
  }
  tool.schema = {
    string: () => descriptor({ type: "string" }), number: () => descriptor({ type: "number" }),
    boolean: () => descriptor({ type: "boolean" }), enum: (values: string[]) => descriptor({ type: "string", enum: [...values] }),
    array: (item: any) => descriptor({ type: "array", items: item.json }), object,
  }
  return tool
}

function messages(native: any[], sessionID: string) {
  if (!Array.isArray(native)) throw new Error("learner_history_unavailable")
  const users = native.filter((message) => message.type === "user")
  const terminal = native.at(-1)
  return native.flatMap((message) => {
    if (typeof message.id !== "string" || !message.id.startsWith("msg_")) return []
    if (message.type === "user" && typeof message.text === "string") return [{
      info: { id: message.id, sessionID, role: "user" },
      parts: [{ id: textID(sessionID, message.id), sessionID, messageID: message.id, type: "text", text: message.text }],
    }]
    if (message.type !== "assistant") return []
    // One bounded child receives exactly one prompt. Additional prompts or a
    // non-terminal context cannot be projected into a successful V1 result.
    const settled = users.length === 1 && terminal?.type === "idle" && message.time?.completed
    return [{
      info: {
        id: message.id, sessionID, role: "assistant", parentID: users.length === 1 ? users[0].id : undefined,
        providerID: message.model?.providerID, modelID: message.model?.id,
        time: { completed: settled ? message.time.completed : undefined }, finish: message.finish,
        error: message.error ? { name: message.error.type ?? "worker_failed" }
          : ["failed", "interrupted"].includes(terminal?.outcome) ? { name: `worker_${terminal.outcome}` } : undefined,
      },
      parts: (message.content ?? []).filter((part: any) => part.type === "text" && typeof part.text === "string"),
    }]
  })
}

function createClient(ctx: any, assertActive: () => void) {
  const required = ["get", "create", "context", "switchAgent", "switchModel", "prompt", "wait", "interrupt"]
  if (!required.every((name) => typeof ctx.session?.[name] === "function") || typeof ctx.agent?.list !== "function") {
    throw new Error("sequential_session_api_unavailable")
  }
  const observations = new Map<string, { settled: boolean; failed: boolean }>()
  const owned = new Map<string, string>()
  const admissions = new Map<string, Promise<void>>()
  const cancellations = new Map<string, boolean>()
  const terminals = new Set<string>()
  const read = async (id: string) => {
    assertActive()
    const info = await ctx.session.get({ sessionID: id })
    assertActive()
    if (info?.id !== id) throw new Error("worker_session_observation_failed")
    if (info.parentID && canonical(info.permissions) !== canonical(CHILD_PERMISSIONS)) throw new Error("restricted_child_not_confirmed")
    return info
  }
  function observe(id: string) {
    if (observations.has(id)) return
    const receipt = { settled: false, failed: false }
    observations.set(id, receipt)
    // wait is a native execution-settlement receipt, not an inferred idle map.
    void ctx.session.wait({ sessionID: id }).then(() => { receipt.settled = true }, () => { receipt.failed = true })
  }
  const session = {
    get: async ({ path, throwOnError }: any) => {
      try { return { data: await read(path.id) } } catch (error: any) {
        // Promise plugins surface Effect FiberFailure for local failures. Only
        // direct, typed absence is definitive; wrapped/transport failures retain exclusion.
        if (throwOnError === false && error?._tag === "SessionNotFoundError" && error.sessionID === path.id) {
          return { response: { status: 404 }, error: { name: "NotFoundError" } }
        }
        throw error
      }
    },
    messages: async ({ path }: any) => {
      const info = await read(path.id)
      if (info.parentID) observe(path.id)
      const native = await ctx.session.context({ sessionID: path.id })
      assertActive()
      if (info.parentID) {
        if (native.at(-1)?.type === "idle" && native.filter((message: any) => message.type === "user").length === 1) terminals.add(path.id)
        else terminals.delete(path.id)
      }
      return { data: messages(native, path.id) }
    },
    message: async ({ path }: any) => {
      await read(path.id)
      const native = await ctx.session.context({ sessionID: path.id })
      assertActive()
      return { data: messages(native, path.id).find((message) => message.info.id === path.messageID) }
    },
    create: async ({ body }: any) => {
      assertActive()
      const child = await ctx.session.create({ parentID: body.parentID, title: body.title, permissions: structuredClone(CHILD_PERMISSIONS) })
      assertActive()
      if (typeof child?.id !== "string" || !child.id.startsWith("ses_")) throw new Error("child_session_not_created")
      // Preserve the accepted native ID even if its restriction receipt is bad.
      // prompt/read fail closed; the business ledger retains exclusion for that
      // same child instead of creating an orphan and silently retrying.
      owned.set(child.id, body.parentID)
      return { data: child }
    },
    prompt: async ({ path, body, signal }: any) => {
      let release!: () => void
      const pending = new Promise<void>((resolve) => { release = resolve })
      admissions.set(path.id, pending)
      try {
        assertActive()
        signal.throwIfAborted()
        const child = await read(path.id)
        if (!owned.has(path.id) || child.parentID !== owned.get(path.id)) throw new Error("foreign_worker_session")
        await ctx.session.switchAgent({ sessionID: path.id, agent: body.agent })
        if (body.model) await ctx.session.switchModel({ sessionID: path.id, model: { providerID: body.model.providerID, id: body.model.modelID, ...(body.model.variant ? { variant: body.model.variant } : {}) } })
        assertActive()
        signal.throwIfAborted()
        observations.delete(path.id)
        const admitted = await ctx.session.prompt({ sessionID: path.id, text: body.parts[0].text })
        assertActive()
        observe(path.id)
        return { data: admitted }
      } finally {
        admissions.delete(path.id)
        release()
      }
    },
    status: async () => {
      assertActive()
      return { data: Object.fromEntries([...observations].map(([id, receipt]) => [id, {
        type: receipt.settled && !receipt.failed && (cancellations.get(id) !== false || terminals.has(id)) ? "idle" : "busy",
      }])) }
    },
    abort: async ({ path }: any) => {
      assertActive()
      // Native prompt admission is uninterruptible and wakes execution before
      // returning. Serialize cancellation after that boundary: an early idle
      // interrupt must not authorize a child that starts afterwards.
      await admissions.get(path.id)
      assertActive()
      const receipt = await ctx.session.interrupt({ sessionID: path.id, resume: false })
      cancellations.set(path.id, receipt?.interrupted === true)
      observations.delete(path.id)
      observe(path.id)
    },
  }
  return {
    assertActive,
    assertWorker: (info: any, job: any) => {
      if (info.parentID !== job.parentID || info.agent && info.agent !== job.worker) throw new Error("foreign_worker_session")
    },
    session,
    app: { agents: async () => {
      assertActive()
      const result = await ctx.agent.list()
      return { data: result.data.map((agent: any) => ({ ...agent, name: agent.id, model: agent.model ? { ...agent.model, modelID: agent.model.id } : undefined })) }
    } },
    onEvent: (event: any) => {
      if (event.type === "session.execution.started") observations.delete(event.data?.sessionID)
    },
  }
}

function formEvents() {
  const calls = new Map<string, any>()
  const forms = new Map<string, any>()
  const key = (sessionID: string, id: string) => JSON.stringify([sessionID, id])
  return {
    prepare: (event: any) => {
      if (calls.size >= MAX_RECEIPTS) throw new Error("learning_host_receipt_limit")
      calls.set(key(event.sessionID, event.id), { messageID: event.messageID, questions: structuredClone(event.input.questions) })
    },
    map: (event: any) => {
      const data = event.data
      if (event.type === "form.created") {
        const form = data?.form
        if (form?.metadata?.kind !== "question" || typeof form.id !== "string" || !form.id.startsWith("frm_")) return
        const tool = form.metadata.tool
        const call = calls.get(key(form.sessionID, tool?.id))
        if (!call || tool.messageID !== call.messageID || forms.has(form.id) || forms.size >= MAX_RECEIPTS) return
        const fields = call.questions.map((question: any, index: number) => ({
          key: `q${index}`, title: question.header, description: question.question,
          type: question.multiple === true ? "multiselect" : "string",
          options: question.options.map((option: any) => ({ value: option.label, label: option.label, description: option.description })), custom: true,
        }))
        if (canonical(form.fields) !== canonical(fields) || form.title !== "Questions") return
        forms.set(form.id, { sessionID: form.sessionID, multiple: call.questions[0]?.multiple === true })
        calls.delete(key(form.sessionID, tool.id))
        return { type: "question.asked", properties: { id: form.id, sessionID: form.sessionID, tool: { callID: tool.id }, questions: call.questions } }
      }
      if (event.type !== "form.replied" && event.type !== "form.cancelled") return
      const form = forms.get(data?.id)
      if (!form || form.sessionID !== data.sessionID) return
      if (event.type === "form.cancelled") {
        forms.delete(data.id)
        return { type: "question.rejected", properties: { requestID: data.id, sessionID: data.sessionID } }
      }
      if (!data.answer || Object.keys(data.answer).length !== 1 || !("q0" in data.answer)) return
      const value = data.answer.q0
      if (form.multiple ? !Array.isArray(value) || !value.every((label: unknown) => typeof label === "string") : typeof value !== "string") return
      forms.delete(data.id)
      return { type: "question.replied", properties: { requestID: data.id, sessionID: data.sessionID, answers: [form.multiple ? value : [value]] } }
    },
    clear: () => { calls.clear(); forms.clear() },
  }
}

async function setup(ctx: any, factory: any) {
  if (!ctx.app?.version?.startsWith("2.")) throw new Error("learning_v2_host_required")
  let disposed = false
  const assertActive = () => { if (disposed) throw new Error("learning_plugin_disposed") }
  const client = createClient(ctx, assertActive)
  const runtime = await factory({ client, directory: ctx.location.directory, toolHelper: schemaTool() })
  const forms = formEvents()
  const controller = new AbortController()
  const registrations: any[] = []
  const cleanup = async () => {
    if (!disposed) {
      disposed = true
      controller.abort()
      forms.clear()
    }
    await Promise.all(registrations.splice(0).map((registration) => registration.dispose()))
  }
  const stream = (async () => {
    for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
      if (disposed) break
      client.onEvent(event)
      const mapped = forms.map(event)
      if (mapped) await runtime.event({ event: mapped })
    }
  })().catch(() => {
    // No event receipts means no consent, not a synthetic approval fallback.
    if (!disposed) void cleanup().catch(() => {})
  })
  try {
    registrations.push(await ctx.tool.hook("execute.before", async (event: any) => {
      assertActive()
      if (event.tool !== "question") return
      const prepared = await runtime["tool.execute.before"]({ tool: event.tool, sessionID: event.sessionID, callID: event.id }, { args: event.input })
      if (prepared) forms.prepare(event)
    }))
    registrations.push(await ctx.tool.transform((editor: any) => {
      for (const [name, tool] of Object.entries(runtime.tool) as any) editor.add({
        name, description: tool.description, input: tool.input,
        execute: async (input: unknown, context: any) => {
          assertActive()
          const content = await tool.execute(input, { ...context, callID: context.id, abort: context.signal })
          assertActive()
          return { content }
        },
      })
    }))
    assertActive()
    return async () => { await cleanup(); await stream }
  } catch (error) {
    await cleanup()
    throw error
  }
}

export const learningHostV2 = { setup, textID, schemaTool, messages, formEvents, createClient }
