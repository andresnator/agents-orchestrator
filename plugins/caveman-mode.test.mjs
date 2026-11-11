import assert from "node:assert/strict"
import test from "node:test"
import fs from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { spawn } from "node:child_process"
import CavemanModePlugin, { cavemanModeContracts as contracts } from "./caveman-mode.ts"

const ROOT_SESSION_ID = "root"
const CHILD_SESSION_ID = "child"
const OTHER_ROOT_SESSION_ID = "other-root"
const PLUGIN_URL = new URL("./caveman-mode.ts", import.meta.url).href
const FIXTURE_ROOT = join(tmpdir(), "opencode")

function isolate(t) {
  fs.mkdirSync(FIXTURE_ROOT, { recursive: true })
  const directory = fs.mkdtempSync(join(FIXTURE_ROOT, "caveman-test-"))
  const previous = process.env.OPENCODE_CONFIG_DIR
  process.env.OPENCODE_CONFIG_DIR = directory
  t.after(() => {
    if (previous === undefined) delete process.env.OPENCODE_CONFIG_DIR
    else process.env.OPENCODE_CONFIG_DIR = previous
    fs.rmSync(directory, { recursive: true, force: true })
  })
  return { directory, statePath: join(directory, contracts.STATE_FILE) }
}

async function createHost(definition, failHook) {
  const hooks = new Map()
  const transforms = new Set()
  const prompts = []
  const disposals = []
  const register = (collection, value) => {
    collection.add(value)
    let disposed = false
    return { async dispose() {
      if (disposed) return
      disposed = true
      collection.delete(value)
      disposals.push(value)
    } }
  }
  const context = {
    command: { async transform(callback) { return register(transforms, callback) } },
    session: {
      get() { throw new Error("Global mode must not resolve ancestors") },
      async prompt(input) { prompts.push(input) },
      async hook(name, callback) {
        if (name === failHook) throw new Error("Registration failed")
        if (!hooks.has(name)) hooks.set(name, new Set())
        return register(hooks.get(name), callback)
      },
    },
  }
  const invoke = async (name, event) => {
    for (const callback of hooks.get(name) ?? []) await callback(event)
  }
  const commands = () => {
    const definitions = new Map()
    for (const transform of transforms) transform({ add(command) { definitions.set(command.name, command) } })
    return definitions
  }
  const host = { context, hooks, transforms, prompts, disposals, invoke, commands }
  try {
    host.cleanup = await definition.setup(context)
  } catch (error) {
    error.host = host
    throw error
  }
  return host
}

// Keep the original characterization scenarios, but route every operation through
// native V2 registrations rather than testing an obsolete production adapter.
async function characterize(definition) {
  const host = await createHost(definition)
  return {
    async "command.execute.before"(input) {
      const command = host.commands().get(input.command.replace(/^\//, ""))
      if (command) await command.execute({ sessionID: input.sessionID, prompt: { text: input.arguments }, delivery: "steer" })
    },
    async "chat.message"(input, output) {
      const text = output.parts.filter((part) => part.type === "text").map((part) => part.text).join("\n")
      await host.invoke("prompt", { sessionID: input.sessionID, prompt: { text }, delivery: "steer" })
    },
    async "experimental.chat.system.transform"(input, output) {
      const event = { sessionID: input.sessionID, system: output.system.map((text) => ({ type: "text", text })) }
      await host.invoke("context", event)
      output.system.splice(0, output.system.length, ...event.system.map((part) => part.text))
    },
  }
}

async function createPlugin() {
  return characterize(CavemanModePlugin)
}

async function select(plugin, mode, sessionID = ROOT_SESSION_ID) {
  await plugin["command.execute.before"]({ command: "caveman", arguments: mode, sessionID })
}

async function systemFor(plugin, sessionID) {
  const output = { system: ["Existing instructions"] }
  await plugin["experimental.chat.system.transform"]({ sessionID }, output)
  return output.system
}

function runProcess(directory, body) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, ["--input-type=module", "-e", `
      import CavemanModePlugin from ${JSON.stringify(PLUGIN_URL)};
      ${createHost.toString()}
      ${characterize.toString()}
      const plugin = await characterize(CavemanModePlugin);
      ${body}
    `], { env: { ...process.env, OPENCODE_CONFIG_DIR: directory }, stdio: ["ignore", "pipe", "pipe"] })
    let stdout = ""
    let stderr = ""
    child.stdout.on("data", (data) => { stdout += data })
    child.stderr.on("data", (data) => { stderr += data })
    child.on("error", reject)
    child.on("close", (code) => code === 0 ? resolve(stdout.trim()) : reject(new Error(stderr)))
  })
}

test("shouldInjectLiteWhenAnySessionHasNoSavedSelection", async (t) => {
  // Given
  const { statePath } = isolate(t)
  const plugin = await createPlugin()
  // When
  const systems = await Promise.all([ROOT_SESSION_ID, CHILD_SESSION_ID, undefined].map((id) => systemFor(plugin, id)))
  // Then
  for (const system of systems) assert.deepEqual(system, [
    "Existing instructions",
    "CAVEMAN SESSION MODE: lite. Apply the matching Caveman rules from global AGENTS.md.",
  ])
  assert.equal(fs.existsSync(statePath), false)
})

test("shouldRefreshAllSessionsAndInstancesWhenAnySessionSelectsEachMode", async (t) => {
  // Given
  isolate(t)
  const writer = await createPlugin()
  const existing = await createPlugin()
  // When
  for (const mode of ["full", "ultra", "wenyan", "lite"]) {
    await select(writer, mode, CHILD_SESSION_ID)
    const fresh = await createPlugin()
    // Then
    for (const plugin of [writer, existing, fresh]) {
      for (const id of [ROOT_SESSION_ID, CHILD_SESSION_ID, OTHER_ROOT_SESSION_ID, "new-child", undefined]) {
        assert.equal((await systemFor(plugin, id)).at(-1), `CAVEMAN SESSION MODE: ${mode}. Apply the matching Caveman rules from global AGENTS.md.`)
      }
    }
  }
})

for (const phrase of ["normal mode", "stop caveman"]) {
  test(`shouldPersistOffAndAllowReselectionWhenUserSays${phrase.replaceAll(" ", "")}`, async (t) => {
    // Given
    isolate(t)
    const plugin = await createPlugin()
    await select(plugin, "ultra")
    // When
    await plugin["chat.message"]({ sessionID: CHILD_SESSION_ID }, { parts: [{ type: "text", text: phrase }] })
    // Then
    assert.deepEqual(await systemFor(await createPlugin(), OTHER_ROOT_SESSION_ID), [
      "Existing instructions",
      "CAVEMAN SESSION MODE: off. Use normal prose; this overrides the default lite fallback.",
    ])
    for (const mode of ["full", "wenyan", "ultra", "lite"]) {
      await plugin["chat.message"]({}, { parts: [{ type: "text", text: phrase }] })
      await select(plugin, mode)
      assert.match((await systemFor(plugin, CHILD_SESSION_ID)).at(-1), new RegExp(`MODE: ${mode}\\.`))
    }
  })
}

test("shouldSelectLiteGloballyWhenBareCommandFollowsOff", async (t) => {
  // Given
  isolate(t)
  const plugin = await createPlugin()
  await plugin["chat.message"]({}, { parts: [{ type: "text", text: "normal mode" }] })
  // When
  await select(plugin, "")
  // Then
  assert.match((await systemFor(plugin, OTHER_ROOT_SESSION_ID)).at(-1), /MODE: lite\./)
})

test("shouldRejectInvalidCommandWithoutMutationWhenSelectionExists", async (t) => {
  // Given
  const { statePath } = isolate(t)
  const plugin = await createPlugin()
  await select(plugin, "full")
  const before = fs.readFileSync(statePath, "utf8")
  // When
  for (const invalid of ["off", "bad", "lite full"]) {
    await assert.rejects(select(plugin, invalid), /Usage: \/caveman \[lite\|full\|ultra\|wenyan\]/)
  }
  await plugin["command.execute.before"]({ command: "other", arguments: "ultra" })
  await plugin["chat.message"]({}, { parts: [{ type: "text", text: "Explain normal mode" }, { type: "file" }] })
  // Then
  assert.equal(fs.readFileSync(statePath, "utf8"), before)
})

test("shouldReplaceOldMarkerWhenGlobalModeChanges", async (t) => {
  // Given
  isolate(t)
  const plugin = await createPlugin()
  const output = { system: ["Existing instructions", "CAVEMAN SESSION MODE: ultra. Obsolete"] }
  // When
  await plugin["experimental.chat.system.transform"]({}, output)
  // Then
  assert.deepEqual(output.system, await systemFor(plugin, ROOT_SESSION_ID))
})

test("shouldUseConfigOverridesWhenResolvingGlobalDirectory", (t) => {
  // Given
  const { directory } = isolate(t)
  const previous = process.env.XDG_CONFIG_HOME
  t.after(() => {
    if (previous === undefined) delete process.env.XDG_CONFIG_HOME
    else process.env.XDG_CONFIG_HOME = previous
  })
  process.env.XDG_CONFIG_HOME = join(directory, "xdg")
  // When
  const explicit = contracts.configDirectory()
  delete process.env.OPENCODE_CONFIG_DIR
  const xdg = contracts.configDirectory()
  // Then
  assert.equal(explicit, directory)
  assert.equal(xdg, join(directory, "xdg", "opencode"))
})

test("shouldPreserveSelectionAcrossRestartsWhenProcessesShareConfig", async (t) => {
  // Given
  const { directory } = isolate(t)
  const existing = await createPlugin()
  // When
  await runProcess(directory, `await plugin["chat.message"]({}, {parts: [{type: "text", text: "normal mode"}]});`)
  const restarted = await runProcess(directory, `
    const output = {system: []};
    await plugin["experimental.chat.system.transform"]({sessionID: "child"}, output);
    console.log(output.system[0]);
  `)
  // Then
  assert.match(restarted, /MODE: off\./)
  assert.equal((await systemFor(existing, ROOT_SESSION_ID)).at(-1), restarted)
})

test("shouldExposeOnlyCompleteStatesWhenTwoProcessesWriteConcurrently", async (t) => {
  // Given
  const { directory, statePath } = isolate(t)
  const plugin = await createPlugin()
  await select(plugin, "lite")
  const reader = runProcess(directory, `
    for (let i = 0; i < 200; i++) {
      const output = {system: []};
      await plugin["experimental.chat.system.transform"]({}, output);
      if (!/MODE: (lite|full|wenyan)\\./.test(output.system[0])) throw new Error("Partial state");
      await new Promise(resolve => setTimeout(resolve, 1));
    }
  `)
  // When
  await Promise.all([reader, ...["full", "wenyan"].map((mode) => runProcess(directory, `
    for (let i = 0; i < 60; i++) {
      await plugin["command.execute.before"]({command: "caveman", arguments: ${JSON.stringify(mode)}});
      await new Promise(resolve => setTimeout(resolve, 1));
    }
  `))])
  await runProcess(directory, `await plugin["command.execute.before"]({command: "caveman", arguments: "ultra"});`)
  // Then
  assert.deepEqual(JSON.parse(fs.readFileSync(statePath, "utf8")), { mode: "ultra" })
  assert.deepEqual(fs.readdirSync(directory), [contracts.STATE_FILE])
})

test("shouldPreserveOldStateUntilAtomicRenameWhenTemporaryWriteIsPartial", async (t) => {
  // Given
  const { directory, statePath } = isolate(t)
  const plugin = await createPlugin()
  await select(plugin, "full")
  const originalWrite = fs.writeFileSync
  const before = fs.readFileSync(statePath, "utf8")
  t.mock.method(fs, "writeFileSync", (path, _content, options) => {
    originalWrite(path, '{"mode":', options)
    assert.equal(fs.readFileSync(statePath, "utf8"), before)
    throw new Error("Interrupted partial write")
  })
  // When
  await assert.rejects(select(plugin, "ultra"), /Interrupted partial write/)
  // Then
  assert.equal(fs.readFileSync(statePath, "utf8"), before)
  assert.deepEqual(fs.readdirSync(directory), [contracts.STATE_FILE])
})

for (const corrupt of ["{", "null", '{"mode":"bad"}', '{"mode":"off","extra":true}', "[]"]) {
  test(`shouldReportErrorWithoutOverwritingWhenStateIsCorrupt${corrupt}`, async (t) => {
    // Given
    const { statePath } = isolate(t)
    fs.writeFileSync(statePath, corrupt)
    const plugin = await createPlugin()
    // When
    await assert.rejects(systemFor(plugin, CHILD_SESSION_ID), /Caveman global state failed/)
    await assert.rejects(select(plugin, "full"), /Caveman global state failed/)
    await assert.rejects(plugin["chat.message"]({}, { parts: [{ type: "text", text: "stop caveman" }] }), /Caveman global state failed/)
    // Then
    assert.equal(fs.readFileSync(statePath, "utf8"), corrupt)
  })
}

for (const operation of ["readFileSync", "writeFileSync", "renameSync", "mkdirSync"]) {
  test(`shouldRejectWithoutAcknowledgmentOrMutationWhen${operation}Fails`, async (t) => {
    // Given
    const { directory, statePath } = isolate(t)
    const plugin = await createPlugin()
    await select(plugin, "wenyan")
    const before = fs.readFileSync(statePath, "utf8")
    const failure = t.mock.method(fs, operation, () => { throw Object.assign(new Error("Denied"), { code: "EACCES" }) })
    // When
    await assert.rejects(select(plugin, "full"), /Caveman global state failed: Denied/)
    if (operation === "readFileSync") await assert.rejects(systemFor(plugin, ROOT_SESSION_ID), /Caveman global state failed: Denied/)
    failure.mock.restore()
    // Then
    assert.equal(fs.readFileSync(statePath, "utf8"), before)
    assert.deepEqual(fs.readdirSync(directory), [contracts.STATE_FILE])
  })
}

test("shouldRegisterNativeV2DefinitionAndPreserveAttachmentsWhenCommandExecutes", async (t) => {
  // Given
  const { statePath } = isolate(t)
  const host = await createHost(CavemanModePlugin)
  t.after(host.cleanup)
  const prompt = { text: " FULL ", files: [{ uri: "file:///fixture.txt" }], skills: ["caveman"] }
  // When
  const command = host.commands().get("caveman")
  await command.execute({ sessionID: CHILD_SESSION_ID, prompt, delivery: "queue" })
  // Then
  assert.equal(CavemanModePlugin.id, "caveman-mode")
  assert.equal(typeof CavemanModePlugin.setup, "function")
  assert.equal("server" in CavemanModePlugin, false)
  assert.equal("effect" in CavemanModePlugin, false)
  assert.deepEqual([...host.hooks.keys()], ["prompt", "context", "compaction", "generate", "title"])
  assert.deepEqual(JSON.parse(fs.readFileSync(statePath, "utf8")), { mode: "full" })
  assert.deepEqual(host.prompts, [{
    ...prompt,
    sessionID: CHILD_SESSION_ID,
    delivery: "queue",
    text: "Caveman mode full was saved globally. Acknowledge in one short sentence using that style.",
  }])
})

test("shouldDeduplicateTypedMarkersForEveryModelRequestWhenStateChanges", async (t) => {
  // Given
  isolate(t)
  const host = await createHost(CavemanModePlugin)
  t.after(host.cleanup)
  const retained = { type: "text", text: "Existing instructions", providerOptions: { test: { cache: true } } }
  await host.invoke("prompt", { prompt: { text: "normal mode" } })
  // When
  for (const hook of ["context", "compaction", "generate", "title"]) {
    const event = { sessionID: CHILD_SESSION_ID, system: [retained,
      { type: "text", text: "CAVEMAN SESSION MODE: full. Obsolete" },
      { type: "text", text: "CAVEMAN SESSION MODE: lite. Duplicate" },
    ] }
    await host.invoke(hook, event)
    await host.invoke(hook, event)
    // Then
    assert.deepEqual(event.system, [retained, {
      type: "text", text: "CAVEMAN SESSION MODE: off. Use normal prose; this overrides the default lite fallback.",
    }])
    assert.equal(event.system[0], retained)
  }
})

test("shouldRejectInvalidCommandBeforePromptAdmissionWhenStateExists", async (t) => {
  // Given
  const { statePath } = isolate(t)
  const host = await createHost(CavemanModePlugin)
  t.after(host.cleanup)
  const execute = (text) => host.commands().get("caveman").execute({ sessionID: ROOT_SESSION_ID, prompt: { text }, delivery: "steer" })
  await execute("wenyan")
  const before = fs.readFileSync(statePath, "utf8")
  host.prompts.length = 0
  // When
  await assert.rejects(execute("off"), /Usage:/)
  await assert.rejects(execute("lite full"), /Usage:/)
  // Then
  assert.deepEqual(host.prompts, [])
  assert.equal(fs.readFileSync(statePath, "utf8"), before)
})

for (const operation of ["readFileSync", "writeFileSync", "renameSync", "mkdirSync"]) {
  test(`shouldNotAdmitAcknowledgmentWhenNativeCommand${operation}Fails`, async (t) => {
    // Given
    const { directory, statePath } = isolate(t)
    const host = await createHost(CavemanModePlugin)
    t.after(host.cleanup)
    await host.invoke("prompt", { prompt: { text: "stop caveman" } })
    const before = fs.readFileSync(statePath, "utf8")
    const failure = t.mock.method(fs, operation, () => { throw new Error("Denied") })
    // When
    await assert.rejects(host.commands().get("caveman").execute({ prompt: { text: "full" }, delivery: "steer" }), /Caveman global state failed: Denied/)
    failure.mock.restore()
    // Then
    assert.deepEqual(host.prompts, [])
    assert.equal(fs.readFileSync(statePath, "utf8"), before)
    assert.deepEqual(fs.readdirSync(directory), [contracts.STATE_FILE])
  })
}

test("shouldIgnoreQuotedOrExtendedDeactivationWhenPromptIsNotStandalone", async (t) => {
  // Given
  const { statePath } = isolate(t)
  const host = await createHost(CavemanModePlugin)
  t.after(host.cleanup)
  await host.commands().get("caveman").execute({ prompt: { text: "ultra" }, delivery: "steer" })
  const before = fs.readFileSync(statePath, "utf8")
  // When
  for (const text of ['"normal mode"', "Explain normal mode", "stop caveman\nand explain", "normal mode please"]) {
    await host.invoke("prompt", { prompt: { text } })
  }
  // Then
  assert.equal(fs.readFileSync(statePath, "utf8"), before)
})

test("shouldDisposeAllRegistrationsWithoutStateLossWhenPluginReloads", async (t) => {
  // Given
  const { statePath } = isolate(t)
  const host = await createHost(CavemanModePlugin)
  await host.invoke("prompt", { prompt: { text: "stop caveman" } })
  const before = fs.readFileSync(statePath, "utf8")
  // When
  host.commands()
  host.commands()
  await host.cleanup()
  await host.cleanup()
  await host.invoke("prompt", { prompt: { text: "normal mode" } })
  const fresh = await createHost(CavemanModePlugin)
  t.after(fresh.cleanup)
  const event = { system: [] }
  await fresh.invoke("context", event)
  // Then
  assert.equal(host.transforms.size, 0)
  assert.equal([...host.hooks.values()].reduce((count, callbacks) => count + callbacks.size, 0), 0)
  assert.equal(host.disposals.length, 6)
  assert.deepEqual([...fresh.commands().keys()], ["caveman"])
  assert.equal([...fresh.hooks.values()].every((callbacks) => callbacks.size === 1), true)
  assert.match(event.system[0].text, /MODE: off\./)
  assert.equal(fs.readFileSync(statePath, "utf8"), before)
})

test("shouldRollBackEarlierRegistrationsWhenV2SetupFails", async (t) => {
  // Given
  const { statePath } = isolate(t)
  // When
  await assert.rejects(createHost(CavemanModePlugin, "generate"), (error) => {
    // Then
    assert.match(error.message, /Registration failed/)
    assert.equal(error.host.transforms.size, 0)
    assert.equal([...error.host.hooks.values()].every((callbacks) => callbacks.size === 0), true)
    assert.equal(error.host.disposals.length, 4)
    assert.equal(fs.existsSync(statePath), false)
    return true
  })
})
