import assert from "node:assert/strict"
import { mkdir, mkdtemp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"
import {
  calculateChanges,
  normalizeProviderCatalog,
  validateProfile,
  type AgentChange,
} from "../domains/meta/tui-plugins/model-configurator/domain"
import {
  readConfigSnapshot,
  renderConfigChanges,
  writeConfigChanges,
  type ConfigSnapshot,
  type PersistenceStep,
} from "../domains/meta/tui-plugins/model-configurator/persistence"
import { runModelConfigurator } from "../domains/meta/tui-plugins/model-configurator/wizard"
import type { TuiDialogConfirmProps, TuiDialogSelectProps, TuiPluginApi, TuiToast } from "@opencode-ai/plugin/tui"

const ROOT = path.resolve(import.meta.dirname, "..")
const FIXTURES = path.join(ROOT, "scripts", "fixtures", "model-configurator")
const EXPECTED_FAILURE_STEPS: PersistenceStep[] = [
  "backup",
  "temporary-open",
  "temporary-write",
  "temporary-flush",
  "rename",
  "destination-flush",
  "post-validate",
]

let passes = 0

async function shouldValidateProfileAsWholeContractWhenProfileIsComplete(): Promise<void> {
  // Given
  const agents = ["alpha", "beta", "gamma"]
  const profile = {
    name: "default",
    description: "Three tiers",
    tiers: {
      high: { description: "High", variant: "high", agents: ["alpha", "beta"] },
      low: { description: "Low", agents: [] },
    },
  }

  // When
  const actual = validateProfile(profile, agents)

  // Then
  assert.deepEqual(actual, {
    profile,
    errors: [],
    warnings: ["agents not covered by a tier: gamma"],
  })
  pass("shouldValidateProfileAsWholeContractWhenProfileIsComplete")
}

async function shouldRejectDuplicateUnknownAndMalformedAgentsWhenProfileIsInvalid(): Promise<void> {
  // Given
  const profile = {
    tiers: {
      first: { agents: ["alpha", "missing", 42] },
      second: { agents: ["alpha"] },
    },
  }

  // When
  const actual = validateProfile(profile, ["alpha", "beta"])

  // Then
  assert.deepEqual(actual, {
    errors: [
      "tier 'first' contains a non-string agent",
      "tier 'first' references unknown agent 'missing'",
      "agent 'alpha' appears in more than one tier",
    ],
    warnings: ["agents not covered by a tier: beta"],
  })
  pass("shouldRejectDuplicateUnknownAndMalformedAgentsWhenProfileIsInvalid")
}

async function shouldExposeOnlyConnectedProvidersWhenCatalogContainsDisconnectedEntries(): Promise<void> {
  // Given
  const response = {
    data: {
      connected: ["openai", "missing"],
      all: [
        { id: "anthropic", models: { opus: { variants: { high: {} } } } },
        { id: "openai", models: { gpt: { variants: ["medium", "high"] } } },
      ],
    },
  }

  // When
  const actual = normalizeProviderCatalog(response)

  // Then
  assert.deepEqual(actual, [{ id: "openai", models: [{ id: "gpt", variants: ["high", "medium"] }] }])
  pass("shouldExposeOnlyConnectedProvidersWhenCatalogContainsDisconnectedEntries")
}

async function shouldCalculateOnlyChangedAssignmentsWhenDecisionsMixActions(): Promise<void> {
  // Given
  const current = {
    alpha: { model: "openai/gpt", variant: "high" },
    beta: { model: "anthropic/opus" },
  }
  const decisions = new Map([
    ["alpha", { action: "set", model: "openai/gpt", variant: "high" } as const],
    ["beta", { action: "inherit" } as const],
    ["gamma", { action: "set", model: "google/gemini" } as const],
  ])

  // When
  const actual = calculateChanges(current, decisions)

  // Then
  assert.deepEqual(actual, [
    { agent: "beta", before: { model: "anthropic/opus" }, after: {}, action: "inherit" },
    { agent: "gamma", before: {}, after: { model: "google/gemini" }, action: "set" },
  ])
  pass("shouldCalculateOnlyChangedAssignmentsWhenDecisionsMixActions")
}

async function shouldPreserveForeignJsoncWhenRenderingAssignmentChanges(): Promise<void> {
  // Given
  const content = await readFile(path.join(FIXTURES, "config-before.jsonc"), "utf8")
  const snapshot: ConfigSnapshot = {
    file: "fixture.jsonc",
    exists: true,
    content,
    mode: 0o640,
    mappings: {},
  }
  const changes = fixtureChanges()

  // When
  const actual = renderConfigChanges(snapshot, changes)

  // Then
  const expected = await readFile(path.join(FIXTURES, "config-after.jsonc"), "utf8")
  assert.equal(actual, expected)
  pass("shouldPreserveForeignJsoncWhenRenderingAssignmentChanges")
}

async function shouldWriteBackupAndPreserveModeWhenWriteSucceeds(): Promise<void> {
  const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-persistence."))
  try {
    // Given
    const file = path.join(scratch, "opencode.jsonc")
    const original = await readFile(path.join(FIXTURES, "config-before.jsonc"), "utf8")
    await writeFile(file, original, { mode: 0o640 })
    const snapshot = await readConfigSnapshot(file)

    // When
    const result = await writeConfigChanges(snapshot, fixtureChanges())

    // Then
    assert.ok(result.backup)
    assert.equal(await readFile(result.backup, "utf8"), original)
    assert.equal(await readFile(file, "utf8"), await readFile(path.join(FIXTURES, "config-after.jsonc"), "utf8"))
    assert.equal((await stat(file)).mode & 0o777, 0o640)
    assert.equal((await stat(result.backup)).mode & 0o777, 0o640)
    pass("shouldWriteBackupAndPreserveModeWhenWriteSucceeds")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldRejectConcurrentEditBeforeCreatingBackup(): Promise<void> {
  const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-persistence."))
  try {
    // Given
    const file = path.join(scratch, "opencode.jsonc")
    await writeFile(file, await readFile(path.join(FIXTURES, "config-before.jsonc"), "utf8"))
    const snapshot = await readConfigSnapshot(file)
    const external = '{"external":true}\n'
    await writeFile(file, external)

    // When
    await assert.rejects(() => writeConfigChanges(snapshot, fixtureChanges()), /changed while the configurator was open/)

    // Then
    assert.equal(await readFile(file, "utf8"), external)
    assert.deepEqual((await readdir(scratch)).sort(), ["opencode.jsonc"])
    pass("shouldRejectConcurrentEditBeforeCreatingBackup")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldRestoreOriginalWhenInjectedPersistenceStepFails(): Promise<void> {
  for (const failureStep of EXPECTED_FAILURE_STEPS) {
    const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-persistence."))
    try {
      // Given
      const file = path.join(scratch, "opencode.jsonc")
      const original = await readFile(path.join(FIXTURES, "config-before.jsonc"), "utf8")
      await writeFile(file, original, { mode: 0o600 })
      const snapshot = await readConfigSnapshot(file)

      // When
      await assert.rejects(
        () =>
          writeConfigChanges(snapshot, fixtureChanges(), {
            before(step) {
              if (step === failureStep) throw new Error(`injected ${step}`)
            },
          }),
        new RegExp(`injected ${failureStep}`),
      )

      // Then
      assert.equal(await readFile(file, "utf8"), original, `destination changed after ${failureStep}`)
      assert.equal((await readdir(scratch)).some((entry) => entry.endsWith(".tmp")), false, `temp remains after ${failureStep}`)
    } finally {
      await rm(scratch, { recursive: true, force: true })
    }
  }
  pass("shouldRestoreOriginalWhenInjectedPersistenceStepFails")
}

async function shouldCompleteStagedWizardAndPersistSelectedChanges(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const toasts: TuiToast[] = []
    let overrideAgentSelection = 0
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Tier profile") return options[0]
        if (title === "Tier: high") return option(options, "openai/new")
        if (title === "Variant for openai/new") return option(options, "high")
        if (title === "Tier: low") return option(options, "__keep_current__")
        if (title === "Choose agent to override") {
          overrideAgentSelection += 1
          return option(options, overrideAgentSelection === 1 ? "beta" : "__done__")
        }
        if (title === "Override: beta") return option(options, "__inherit__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then
    const persisted = await readConfigSnapshot(configFile)
    assert.deepEqual(persisted.mappings, {
      alpha: { model: "openai/new", variant: "high" },
    })
    assert.equal(toasts.at(-1)?.variant, "success")
    assert.equal((await readdir(path.dirname(configFile))).some((entry) => entry.includes(".bak.")), true)
    pass("shouldCompleteStagedWizardAndPersistSelectedChanges")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldLeaveConfigUntouchedWhenFinalReviewIsCancelled(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const original = await readFile(configFile, "utf8")
    const api = createFakeApi(scratch, [], {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Tier profile") return options[0]
        if (title === "Tier: high") return option(options, "openai/new")
        if (title === "Variant for openai/new") return option(options, "high")
        if (title === "Tier: low") return option(options, "__keep_current__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm(title) {
        if (title === "Individual overrides") return false
        if (title.startsWith("Apply ")) return false
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then
    assert.equal(await readFile(configFile, "utf8"), original)
    assert.deepEqual((await readdir(path.dirname(configFile))).sort(), ["opencode.jsonc"])
    pass("shouldLeaveConfigUntouchedWhenFinalReviewIsCancelled")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

type WizardFixture = {
  root: string
  data: string
  project: string
  global: string
}

type DialogPolicy = {
  select: (title: string, options: Array<{ title: string; value: string }>) => { title: string; value: string }
  confirm: (title: string) => boolean
}

async function createWizardFixture(): Promise<WizardFixture> {
  const root = await mkdtemp(path.join(tmpdir(), "model-configurator-wizard."))
  const data = path.join(root, "runtime-data")
  const project = path.join(root, "project")
  const global = path.join(root, "global")
  await Promise.all([
    writeJson(path.join(data, "agents.json"), ["alpha", "beta"]),
    writeJson(path.join(data, "profiles", "default.json"), {
      name: "default",
      description: "Fixture profile",
      tiers: {
        high: { description: "High", variant: "high", agents: ["alpha"] },
        low: { description: "Low", agents: ["beta"] },
      },
    }),
    writeJsonc(
      path.join(project, ".opencode", "opencode.jsonc"),
      '{\n  // Preserve me.\n  "agent": {\n    "alpha": {"model": "openai/old"},\n    "beta": {"model": "anthropic/old"}\n  },\n  "foreign": true\n}\n',
    ),
  ])
  return { root, data, project, global }
}

function createFakeApi(
  fixture: WizardFixture,
  toasts: TuiToast[],
  policy: DialogPolicy,
): TuiPluginApi {
  const dialog = {
    replace(render: () => unknown) {
      render()
    },
    clear() {},
    setSize() {},
    size: "medium" as const,
    depth: 0,
    open: false,
  }
  const api = {
    state: {
      ready: true,
      path: { state: fixture.root, config: fixture.global, worktree: fixture.project, directory: fixture.project },
    },
    client: {
      provider: {
        async list() {
          return {
            data: {
              connected: ["openai", "anthropic"],
              all: [
                { id: "openai", models: { new: { variants: { high: {}, low: {} } } } },
                { id: "anthropic", models: { old: { variants: {} } } },
              ],
            },
          }
        },
      },
    },
    ui: {
      dialog,
      toast(input: TuiToast) {
        toasts.push(input)
      },
      DialogSelect<Value extends string>(props: TuiDialogSelectProps<Value>) {
        queueMicrotask(() => props.onSelect?.(policy.select(props.title, props.options) as TuiDialogSelectProps<Value>["options"][number]))
        return undefined
      },
      DialogConfirm(props: TuiDialogConfirmProps) {
        queueMicrotask(() => (policy.confirm(props.title) ? props.onConfirm?.() : props.onCancel?.()))
        return undefined
      },
    },
  }
  return api as unknown as TuiPluginApi
}

function option<Value extends string>(
  options: Array<{ title: string; value: Value }>,
  value: Value,
): { title: string; value: Value } {
  const selected = options.find((candidate) => candidate.value === value)
  assert.ok(selected, `missing dialog option ${value}`)
  return selected
}

async function writeJson(file: string, value: unknown): Promise<void> {
  await writeJsonc(file, `${JSON.stringify(value, undefined, 2)}\n`)
}

async function writeJsonc(file: string, content: string): Promise<void> {
  const directory = path.dirname(file)
  await mkdir(directory, { recursive: true })
  await writeFile(file, content)
}

function fixtureChanges(): AgentChange[] {
  return [
    {
      agent: "alpha",
      before: { model: "openai/old", variant: "high" },
      after: { model: "openai/new" },
      action: "set",
    },
    {
      agent: "beta",
      before: { model: "anthropic/old", variant: "low" },
      after: {},
      action: "inherit",
    },
    {
      agent: "gamma",
      before: { model: "google/old" },
      after: {},
      action: "inherit",
    },
  ]
}

function pass(name: string): void {
  passes += 1
  process.stdout.write(`PASS ${name}\n`)
}

await shouldValidateProfileAsWholeContractWhenProfileIsComplete()
await shouldRejectDuplicateUnknownAndMalformedAgentsWhenProfileIsInvalid()
await shouldExposeOnlyConnectedProvidersWhenCatalogContainsDisconnectedEntries()
await shouldCalculateOnlyChangedAssignmentsWhenDecisionsMixActions()
await shouldPreserveForeignJsoncWhenRenderingAssignmentChanges()
await shouldWriteBackupAndPreserveModeWhenWriteSucceeds()
await shouldRejectConcurrentEditBeforeCreatingBackup()
await shouldRestoreOriginalWhenInjectedPersistenceStepFails()
await shouldCompleteStagedWizardAndPersistSelectedChanges()
await shouldLeaveConfigUntouchedWhenFinalReviewIsCancelled()
process.stdout.write(`PASS: ${passes} TypeScript model configurator contracts.\n`)
