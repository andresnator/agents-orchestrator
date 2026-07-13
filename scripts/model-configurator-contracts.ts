import assert from "node:assert/strict"
import { mkdir, mkdtemp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises"
import { homedir, tmpdir } from "node:os"
import path from "node:path"
import {
  calculateChanges,
  normalizeProviderCatalog,
  validateProfile,
  type AgentChange,
} from "../domains/meta/tui-plugins/model-configurator/domain"
import {
  displayConfigFile,
  readConfigSnapshot,
  renderConfigChanges,
  writeConfigChanges,
  type ConfigSnapshot,
  type PersistenceStep,
} from "../domains/meta/tui-plugins/model-configurator/persistence"
import {
  deletePreset,
  loadPresets,
  partitionPresetAssignments,
  savePreset,
} from "../domains/meta/tui-plugins/model-configurator/presets"
import { runModelConfigurator } from "../domains/meta/tui-plugins/model-configurator/wizard"
import type {
  TuiDialogConfirmProps,
  TuiDialogPromptProps,
  TuiDialogSelectProps,
  TuiPluginApi,
  TuiToast,
} from "@opencode-ai/plugin/tui"

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
        if (title === "Individual overrides") return option(options, "__override_yes__")
        if (title === "Choose agent to override") {
          overrideAgentSelection += 1
          return option(options, overrideAgentSelection === 1 ? "beta" : "__done__")
        }
        if (title === "Override: beta") return option(options, "__inherit__")
        if (title.startsWith("Apply ")) return option(options, "__apply__")
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
        if (title === "Individual overrides") return option(options, "__override_no__")
        if (title.startsWith("Apply ")) return option(options, "__cancel__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
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

async function shouldReshowPreviousDialogWhenEscapingBack(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a wizard that escapes the first tier dialog once, then completes
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const toasts: TuiToast[] = []
    let tierProfileVisits = 0
    let highTierVisits = 0
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Tier profile") {
          tierProfileVisits += 1
          return options[0]
        }
        if (title === "Tier: high") {
          highTierVisits += 1
          return highTierVisits === 1 ? "escape" : option(options, "openai/new")
        }
        if (title === "Variant for openai/new") return option(options, "high")
        if (title === "Tier: low") return option(options, "__keep_current__")
        if (title === "Individual overrides") return option(options, "__override_no__")
        if (title.startsWith("Apply ")) return option(options, "__apply__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then esc on the first tier returned to the source step, which re-showed both dialogs
    assert.equal(tierProfileVisits, 2)
    assert.equal(highTierVisits, 2)
    const persisted = await readConfigSnapshot(configFile)
    assert.deepEqual(persisted.mappings, {
      alpha: { model: "openai/new", variant: "high" },
      beta: { model: "anthropic/old", variant: undefined },
    })
    assert.equal(toasts.at(-1)?.variant, "success")
    pass("shouldReshowPreviousDialogWhenEscapingBack")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldExitWithoutWritingWhenScopeIsEscaped(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const original = await readFile(configFile, "utf8")
    const api = createFakeApi(scratch, [], {
      select(title) {
        if (title === "Configuration scope") return "escape"
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then esc on the first dialog exits silently, touching nothing
    assert.equal(await readFile(configFile, "utf8"), original)
    assert.deepEqual((await readdir(path.dirname(configFile))).sort(), ["opencode.jsonc"])
    pass("shouldExitWithoutWritingWhenScopeIsEscaped")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldSavePresetWhenApplyingAndSaving(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a run that inherits beta then applies-and-saves under a name
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
        if (title === "Individual overrides") return option(options, "__override_yes__")
        if (title === "Choose agent to override") {
          overrideAgentSelection += 1
          return option(options, overrideAgentSelection === 1 ? "beta" : "__done__")
        }
        if (title === "Override: beta") return option(options, "__inherit__")
        if (title.startsWith("Apply ")) return option(options, "__apply_save__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
      prompt(title) {
        if (title === "Preset name") return "prod"
        throw new Error(`unexpected prompt dialog: ${title}`)
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then the config is written and a preset with only concrete (non-inherited) assignments is saved
    const persisted = await readConfigSnapshot(configFile)
    assert.deepEqual(persisted.mappings, { alpha: { model: "openai/new", variant: "high" } })
    const presets = await loadPresets(path.join(scratch.global, "model-configurator-presets.json"))
    assert.equal(presets.length, 1)
    assert.equal(presets[0].name, "prod")
    assert.deepEqual(presets[0].assignments, { alpha: { model: "openai/new", variant: "high" } })
    pass("shouldSavePresetWhenApplyingAndSaving")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldApplyPresetSkippingTiersAndOverrides(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a seeded preset in the global config root
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const presetsPath = path.join(scratch.global, "model-configurator-presets.json")
    await savePreset(presetsPath, {
      name: "saved",
      savedAt: "2026-01-01T00:00:00.000Z",
      assignments: { alpha: { model: "openai/new", variant: "high" } },
    })
    const toasts: TuiToast[] = []
    const api = createFakeApi(scratch, toasts, {
      // No tier/override handlers: reaching one throws and fails the test
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Tier profile") return option(options, "__preset__:saved")
        if (title === "Preset: saved") return option(options, "__apply_preset__")
        if (title.startsWith("Apply ")) return option(options, "__apply__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then the preset assignments are applied without visiting tiers or overrides
    const persisted = await readConfigSnapshot(configFile)
    assert.deepEqual(persisted.mappings, {
      alpha: { model: "openai/new", variant: "high" },
      beta: { model: "anthropic/old", variant: undefined },
    })
    assert.equal(toasts.at(-1)?.variant, "success")
    pass("shouldApplyPresetSkippingTiersAndOverrides")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldDeletePresetWithoutTouchingConfig(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a seeded preset and an untouched config
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const original = await readFile(configFile, "utf8")
    const presetsPath = path.join(scratch.global, "model-configurator-presets.json")
    await savePreset(presetsPath, {
      name: "saved",
      savedAt: "2026-01-01T00:00:00.000Z",
      assignments: { alpha: { model: "openai/new", variant: "high" } },
    })
    const toasts: TuiToast[] = []
    let scopeVisits = 0
    let tierProfileVisits = 0
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") {
          scopeVisits += 1
          return scopeVisits === 1 ? option(options, "project") : "escape"
        }
        if (title === "Tier profile") {
          tierProfileVisits += 1
          return tierProfileVisits === 1 ? option(options, "__preset__:saved") : "escape"
        }
        if (title === "Preset: saved") return option(options, "__delete_preset__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When: apply project, delete the preset, esc back through the source and scope dialogs to exit
    await runModelConfigurator(api, scratch.data)

    // Then the preset is gone and the config is untouched
    assert.deepEqual(await loadPresets(presetsPath), [])
    assert.equal(await readFile(configFile, "utf8"), original)
    assert.ok(toasts.some((toast) => toast.message?.includes('Deleted preset "saved"')))
    pass("shouldDeletePresetWithoutTouchingConfig")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldOpenAdjacentAgentViaNextAgent(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a run that only ever picks "alpha" from the chooser
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const toasts: TuiToast[] = []
    let chooserVisits = 0
    let sawOverrideBeta = false
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Tier profile") return options[0]
        if (title === "Tier: high") return option(options, "__keep_current__")
        if (title === "Tier: low") return option(options, "__keep_current__")
        if (title === "Individual overrides") return option(options, "__override_yes__")
        if (title === "Choose agent to override") {
          chooserVisits += 1
          return option(options, chooserVisits === 1 ? "alpha" : "__done__")
        }
        if (title === "Override: alpha") return option(options, "__next_agent__")
        if (title === "Override: beta") {
          sawOverrideBeta = true
          return option(options, "openai/new")
        }
        if (title === "Variant for openai/new") return option(options, "high")
        if (title.startsWith("Apply ")) return option(options, "__apply__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then "→ Next agent" opened beta's override dialog without selecting it in the chooser
    assert.equal(sawOverrideBeta, true)
    const persisted = await readConfigSnapshot(configFile)
    assert.deepEqual(persisted.mappings, {
      alpha: { model: "openai/old", variant: undefined },
      beta: { model: "openai/new", variant: "high" },
    })
    pass("shouldOpenAdjacentAgentViaNextAgent")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldPreserveOverridesWhenEscapingAgentChooser(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given an override for alpha, then esc at the chooser (which must NOT discard it)
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const toasts: TuiToast[] = []
    let individualOverridesVisits = 0
    let chooserVisits = 0
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Tier profile") return options[0]
        if (title === "Tier: high") return option(options, "__keep_current__")
        if (title === "Tier: low") return option(options, "__keep_current__")
        if (title === "Individual overrides") {
          individualOverridesVisits += 1
          return option(options, "__override_yes__")
        }
        if (title === "Choose agent to override") {
          chooserVisits += 1
          if (chooserVisits === 1) return option(options, "alpha")
          if (chooserVisits === 2) return "escape"
          return option(options, "__done__")
        }
        if (title === "Override: alpha") return option(options, "openai/new")
        if (title === "Variant for openai/new") return option(options, "high")
        if (title.startsWith("Apply ")) return option(options, "__apply__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then esc re-showed the Yes/No prompt (not tiers) and the alpha override survived
    assert.equal(individualOverridesVisits, 2)
    assert.equal(chooserVisits, 3)
    const persisted = await readConfigSnapshot(configFile)
    assert.deepEqual(persisted.mappings, {
      alpha: { model: "openai/new", variant: "high" },
      beta: { model: "anthropic/old", variant: undefined },
    })
    assert.equal(toasts.at(-1)?.variant, "success")
    pass("shouldPreserveOverridesWhenEscapingAgentChooser")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldRoundTripAndOverwritePresetsWhenSaved(): Promise<void> {
  const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-presets."))
  try {
    // Given
    const file = path.join(scratch, "model-configurator-presets.json")

    // When two presets are saved out of order
    await savePreset(file, { name: "b", savedAt: "2026-01-02T00:00:00.000Z", assignments: { alpha: { model: "openai/new" } } })
    await savePreset(file, {
      name: "a",
      savedAt: "2026-01-01T00:00:00.000Z",
      assignments: { beta: { model: "anthropic/old", variant: "high" } },
    })

    // Then they round-trip sorted by name
    let presets = await loadPresets(file)
    assert.deepEqual(
      presets.map((preset) => preset.name),
      ["a", "b"],
    )

    // When a same-named preset is saved, it overwrites in place
    await savePreset(file, { name: "b", savedAt: "2026-01-03T00:00:00.000Z", assignments: { gamma: { model: "google/x" } } })
    presets = await loadPresets(file)
    assert.equal(presets.length, 2)
    assert.deepEqual(presets.find((preset) => preset.name === "b")?.assignments, { gamma: { model: "google/x" } })

    // When one is deleted, only the other remains
    await deletePreset(file, "a")
    presets = await loadPresets(file)
    assert.deepEqual(
      presets.map((preset) => preset.name),
      ["b"],
    )
    pass("shouldRoundTripAndOverwritePresetsWhenSaved")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldPartitionPresetAssignmentsByLiveCatalog(): Promise<void> {
  // Given a live catalog and a preset referencing unknown agents, gone models, and gone variants
  const models = [
    { id: "openai/new", variants: ["high", "low"] },
    { id: "anthropic/old", variants: [] },
  ]

  // When
  const { valid, stale } = partitionPresetAssignments(
    {
      alpha: { model: "openai/new", variant: "high" },
      beta: { model: "anthropic/old" },
      known1: { model: "openai/gone" },
      known2: { model: "openai/new", variant: "gone" },
      gamma: { model: "openai/new" },
    },
    ["alpha", "beta", "known1", "known2"],
    models,
  )

  // Then only live agent/model/variant triples survive; the rest are stale and sorted
  assert.deepEqual(valid, {
    alpha: { model: "openai/new", variant: "high" },
    beta: { model: "anthropic/old" },
  })
  assert.deepEqual(stale, ["gamma", "known1", "known2"])
  pass("shouldPartitionPresetAssignmentsByLiveCatalog")
}

async function shouldShortenConfigFilePathsForDisplay(): Promise<void> {
  // Given
  const runtime = { config: path.join(homedir(), ".config", "opencode"), worktree: "/work/project", directory: "/work/project" }

  // Then project paths are relative to the project root
  assert.equal(
    displayConfigFile("project", path.join("/work", "project", ".opencode", "opencode.jsonc"), runtime),
    path.join(".opencode", "opencode.jsonc"),
  )
  // And global paths under home collapse the home prefix to ~
  assert.equal(
    displayConfigFile("global", path.join(homedir(), ".config", "opencode", "opencode.jsonc"), runtime),
    `~${path.sep}${path.join(".config", "opencode", "opencode.jsonc")}`,
  )
  // And global paths outside home stay absolute
  assert.equal(displayConfigFile("global", "/etc/opencode/opencode.jsonc", runtime), "/etc/opencode/opencode.jsonc")
  pass("shouldShortenConfigFilePathsForDisplay")
}

type WizardFixture = {
  root: string
  data: string
  project: string
  global: string
}

type PolicyOption = { title: string; value: string }

type DialogPolicy = {
  select: (title: string, options: Array<PolicyOption>) => PolicyOption | "escape"
  confirm: (title: string) => boolean | "escape"
  prompt?: (title: string) => string | "escape"
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
  let currentOnClose: (() => void) | undefined
  const dialog = {
    replace(render: () => unknown, onClose?: () => void) {
      currentOnClose = onClose
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
        const onClose = currentOnClose
        queueMicrotask(() => {
          const answer = policy.select(props.title, props.options as unknown as PolicyOption[])
          if (answer === "escape") onClose?.()
          else props.onSelect?.(answer as TuiDialogSelectProps<Value>["options"][number])
        })
        return undefined
      },
      DialogConfirm(props: TuiDialogConfirmProps) {
        const onClose = currentOnClose
        queueMicrotask(() => {
          const answer = policy.confirm(props.title)
          if (answer === "escape") onClose?.()
          else if (answer) props.onConfirm?.()
          else props.onCancel?.()
        })
        return undefined
      },
      DialogPrompt(props: TuiDialogPromptProps) {
        const onClose = currentOnClose
        queueMicrotask(() => {
          if (!policy.prompt) throw new Error(`unexpected prompt dialog: ${props.title}`)
          const answer = policy.prompt(props.title)
          if (answer === "escape") onClose?.()
          else props.onConfirm?.(answer)
        })
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
await shouldReshowPreviousDialogWhenEscapingBack()
await shouldExitWithoutWritingWhenScopeIsEscaped()
await shouldSavePresetWhenApplyingAndSaving()
await shouldApplyPresetSkippingTiersAndOverrides()
await shouldDeletePresetWithoutTouchingConfig()
await shouldOpenAdjacentAgentViaNextAgent()
await shouldPreserveOverridesWhenEscapingAgentChooser()
await shouldRoundTripAndOverwritePresetsWhenSaved()
await shouldPartitionPresetAssignmentsByLiveCatalog()
await shouldShortenConfigFilePathsForDisplay()
process.stdout.write(`PASS: ${passes} TypeScript model configurator contracts.\n`)
