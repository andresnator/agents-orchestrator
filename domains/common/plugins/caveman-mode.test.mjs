import assert from "node:assert/strict"
import test from "node:test"
import fs from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { spawn } from "node:child_process"
import { CavemanModePlugin, cavemanModeContracts as contracts } from "./caveman-mode.ts"

const ROOT_SESSION_ID = "root"
const CHILD_SESSION_ID = "child"
const OTHER_ROOT_SESSION_ID = "other-root"
const PLUGIN_URL = new URL("./caveman-mode.ts", import.meta.url).href

function isolate(t) {
  const directory = fs.mkdtempSync(join(tmpdir(), "caveman-test-"))
  const previous = process.env.OPENCODE_CONFIG_DIR
  process.env.OPENCODE_CONFIG_DIR = directory
  t.after(() => {
    if (previous === undefined) delete process.env.OPENCODE_CONFIG_DIR
    else process.env.OPENCODE_CONFIG_DIR = previous
    fs.rmSync(directory, { recursive: true, force: true })
  })
  return { directory, statePath: join(directory, contracts.STATE_FILE) }
}

async function createPlugin() {
  return CavemanModePlugin({
    client: { session: { get: () => { throw new Error("Global mode must not resolve ancestors") } } },
  })
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
      import { CavemanModePlugin } from ${JSON.stringify(PLUGIN_URL)};
      const plugin = await CavemanModePlugin({});
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
