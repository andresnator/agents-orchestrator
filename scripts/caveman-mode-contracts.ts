import assert from "node:assert/strict"
import { CavemanModePlugin, cavemanModeContracts } from "../domains/common/plugins/caveman-mode.ts"

const {
  DEFAULT_MODE,
  MODE_MARKER_PREFIX,
  commandMatches,
  injectModeMarker,
  parseCommandMode,
  parseDeactivationPhrase,
  resolveEffectiveMode,
} = cavemanModeContracts

let passed = 0
async function test(name: string, body: () => void | Promise<void>): Promise<void> {
  await body()
  passed += 1
  console.log(`ok - ${name}`)
}
await test("shouldParseSupportedCommandModes", () => {
  // Given
  const cases = new Map([
    ["", "lite"],
    ["  ", "lite"],
    ["LITE", "lite"],
    ["full", "full"],
    ["ultra", "ultra"],
    ["wenyan", "wenyan"],
  ])
  // When / Then
  for (const [input, expected] of cases) assert.equal(parseCommandMode(input), expected)
  assert.equal(parseCommandMode("off"), null)
  assert.equal(parseCommandMode("wenyan-full"), null)
  assert.equal(parseCommandMode("ultra now"), null)
  assert.equal(commandMatches("caveman"), true)
  assert.equal(commandMatches("/caveman"), true)
  assert.equal(commandMatches("caveman-help"), false)
})
await test("shouldRecognizeOnlyCompleteDeactivationPhrases", () => {
  // Given / When / Then
  assert.equal(parseDeactivationPhrase("stop caveman"), "off")
  assert.equal(parseDeactivationPhrase("Normal mode."), "off")
  assert.equal(parseDeactivationPhrase('Explain "stop caveman"'), null)
  assert.equal(parseDeactivationPhrase("How does Vim normal mode work?"), null)
})

await test("shouldInheritNearestExplicitAncestorMode", async () => {
  // Given
  const explicit = new Map([
    ["root", "ultra"],
    ["child", "full"],
  ] as const)
  const parents = new Map([
    ["child", "root"],
    ["grandchild", "child"],
    ["sibling", "root"],
  ])
  const parentOf = async (sessionID: string): Promise<string | undefined> => parents.get(sessionID)
  // When
  const grandchildMode = await resolveEffectiveMode("grandchild", explicit, parentOf)
  const siblingMode = await resolveEffectiveMode("sibling", explicit, parentOf)
  const rootWithoutSelection = await resolveEffectiveMode("other-root", explicit, parentOf)
  // Then
  assert.equal(grandchildMode, "full")
  assert.equal(siblingMode, "ultra")
  assert.equal(rootWithoutSelection, DEFAULT_MODE)
})

await test("shouldObserveParentChangesWithoutCachingInheritedMode", async () => {
  // Given
  const explicit = new Map<string, "lite" | "full" | "ultra" | "wenyan" | "off">([["root", "full"]])
  const parentOf = async (sessionID: string): Promise<string | undefined> =>
    sessionID === "child" ? "root" : undefined
  // When
  const before = await resolveEffectiveMode("child", explicit, parentOf)
  explicit.set("root", "wenyan")
  const after = await resolveEffectiveMode("child", explicit, parentOf)
  // Then
  assert.deepEqual({ before, after }, { before: "full", after: "wenyan" })
})

await test("shouldIsolateTreesAndFailSafeToLite", async () => {
  // Given
  const explicit = new Map([
    ["root-a", "off"],
    ["root-b", "ultra"],
  ] as const)
  const parents = new Map([
    ["child-a", "root-a"],
    ["child-b", "root-b"],
    ["cycle-a", "cycle-b"],
    ["cycle-b", "cycle-a"],
  ])
  const parentOf = async (sessionID: string): Promise<string | undefined> => {
    if (sessionID === "broken") throw new Error("SDK unavailable")
    return parents.get(sessionID)
  }
  // When / Then
  assert.equal(await resolveEffectiveMode("child-a", explicit, parentOf), "off")
  assert.equal(await resolveEffectiveMode("child-b", explicit, parentOf), "ultra")
  assert.equal(await resolveEffectiveMode("cycle-a", explicit, parentOf), "lite")
  assert.equal(await resolveEffectiveMode("broken", explicit, parentOf), "lite")
  assert.equal(await resolveEffectiveMode(undefined, explicit, parentOf), "lite")
})

await test("shouldInjectOneLatestModeMarker", () => {
  // Given
  const system = ["base", `${MODE_MARKER_PREFIX} lite. stale`, `${MODE_MARKER_PREFIX} full. stale`]
  // When
  injectModeMarker(system, "wenyan")
  injectModeMarker(system, "off")
  // Then
  assert.deepEqual(system, ["base", `${MODE_MARKER_PREFIX} off. Use normal prose; this overrides the default lite fallback.`])
})

await test("shouldWireCommandInheritanceStopAndCleanupHooks", async () => {
  // Given
  const sessions = new Map([
    ["root", { id: "root" }],
    ["child", { id: "child", parentID: "root" }],
  ])
  const hooks = await CavemanModePlugin({
    client: {
      session: {
        get: async ({ path }: { path: { id: string } }) => ({ data: sessions.get(path.id) }),
      },
    },
    directory: "/tmp/project",
  } as never)
  const commandHook = hooks["command.execute.before"]
  const messageHook = hooks["chat.message"]
  const systemHook = hooks["experimental.chat.system.transform"]
  assert.ok(commandHook)
  assert.ok(messageHook)
  assert.ok(systemHook)
  // When
  await commandHook({ command: "caveman", sessionID: "root", arguments: "ultra" }, { parts: [] })
  const inherited = { system: ["base"] }
  await systemHook({ sessionID: "child", model: {} as never }, inherited)
  await commandHook({ command: "caveman", sessionID: "root", arguments: "invalid" }, { parts: [] })
  const unchanged = { system: ["base"] }
  await systemHook({ sessionID: "child", model: {} as never }, unchanged)
  await messageHook(
    { sessionID: "root", agent: "test" },
    { message: {} as never, parts: [{ type: "text", text: "normal mode" } as never] },
  )
  const stopped = { system: ["base"] }
  await systemHook({ sessionID: "child", model: {} as never }, stopped)
  await hooks.event?.({ event: { type: "session.deleted", properties: { info: { id: "root" } } } as never })
  const cleaned = { system: ["base"] }
  await systemHook({ sessionID: "child", model: {} as never }, cleaned)
  // Then
  assert.match(inherited.system.at(-1) ?? "", /MODE: ultra/)
  assert.match(unchanged.system.at(-1) ?? "", /MODE: ultra/)
  assert.match(stopped.system.at(-1) ?? "", /MODE: off/)
  assert.match(cleaned.system.at(-1) ?? "", /MODE: lite/)
})

console.log(`caveman-mode contracts: ${passed} checks passed`)
