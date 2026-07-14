import assert from "node:assert/strict"
import { mkdir, mkdtemp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises"
import { homedir, tmpdir } from "node:os"
import path from "node:path"
import {
  calculateChanges,
  discoverHarnessAgents,
  groupAgentsByDomain,
  normalizeProviderCatalog,
  validateProfile,
  type AgentChange,
  type CatalogAgent,
} from "../domains/meta/tui-plugins/model-configurator/domain"
import {
  applyConfigChanges,
  planGlobalHotApply,
} from "../domains/meta/tui-plugins/model-configurator/hot-apply"
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

async function shouldWriteWithoutBackupAndPreserveModeWhenWriteSucceeds(): Promise<void> {
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
    assert.equal(result.file, file)
    assert.equal(await readFile(file, "utf8"), await readFile(path.join(FIXTURES, "config-after.jsonc"), "utf8"))
    assert.equal((await stat(file)).mode & 0o777, 0o640)
    assert.deepEqual((await readdir(scratch)).sort(), ["opencode.jsonc"])
    pass("shouldWriteWithoutBackupAndPreserveModeWhenWriteSucceeds")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldRejectConcurrentEditBeforeWriting(): Promise<void> {
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
    pass("shouldRejectConcurrentEditBeforeWriting")
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
        if (title === "Select domain") return option(options, "default")
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
    assert.equal((await readdir(path.dirname(configFile))).some((entry) => entry.includes(".bak")), false)
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
        if (title === "Select domain") return option(options, "default")
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
    let hubVisits = 0
    let highTierVisits = 0
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Select domain") {
          hubVisits += 1
          return option(options, "default")
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

    // Then esc on the first tier returned to the domain hub, which re-showed both dialogs
    assert.equal(hubVisits, 2)
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
        if (title === "Select domain") return option(options, "default")
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
        if (title === "Select domain") return option(options, "__preset__:saved")
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
    let hubVisits = 0
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") {
          scopeVisits += 1
          return scopeVisits === 1 ? option(options, "project") : "escape"
        }
        if (title === "Select domain") {
          hubVisits += 1
          return hubVisits === 1 ? option(options, "__preset__:saved") : "escape"
        }
        if (title === "Preset: saved") return option(options, "__delete_preset__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When: apply project, delete the preset, esc back through the hub and scope dialogs to exit
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
        if (title === "Select domain") return option(options, "default")
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
        if (title === "Select domain") return option(options, "default")
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

async function shouldConfigureAgentThroughDomainBrowseAndApply(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a run that browses domain "one", configures alpha, and applies from the hub
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const toasts: TuiToast[] = []
    let domainAgentsVisits = 0
    let sawPendingMarker = false
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Select domain") {
          const review = options.find((candidate) => candidate.value === "__review_changes__")
          return review ?? option(options, "__domain__:one")
        }
        if (title === "one agents") {
          domainAgentsVisits += 1
          if (domainAgentsVisits === 1) return option(options, "alpha")
          sawPendingMarker = options.some((candidate) => candidate.title === "● alpha")
          return option(options, "__done__")
        }
        if (title === "Configure: alpha") return option(options, "openai/new")
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

    // Then the domain-browsed decision is applied and the pending marker was visible
    assert.equal(sawPendingMarker, true)
    const persisted = await readConfigSnapshot(configFile)
    assert.deepEqual(persisted.mappings, {
      alpha: { model: "openai/new", variant: "high" },
      beta: { model: "anthropic/old", variant: undefined },
    })
    assert.equal(toasts.at(-1)?.variant, "success")
    pass("shouldConfigureAgentThroughDomainBrowseAndApply")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldWalkBackFromDomainAgentsToScopeWithoutWriting(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given esc pressed at each level: domain agents → hub → scope
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const original = await readFile(configFile, "utf8")
    let scopeVisits = 0
    let hubVisits = 0
    let domainAgentsVisits = 0
    const api = createFakeApi(scratch, [], {
      select(title, options) {
        if (title === "Configuration scope") {
          scopeVisits += 1
          return scopeVisits === 1 ? option(options, "project") : "escape"
        }
        if (title === "Select domain") {
          hubVisits += 1
          return hubVisits === 1 ? option(options, "__domain__:one") : "escape"
        }
        if (title === "one agents") {
          domainAgentsVisits += 1
          return "escape"
        }
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then each esc stepped back exactly one level and nothing was written
    assert.equal(domainAgentsVisits, 1)
    assert.equal(hubVisits, 2)
    assert.equal(scopeVisits, 2)
    assert.equal(await readFile(configFile, "utf8"), original)
    assert.deepEqual((await readdir(path.dirname(configFile))).sort(), ["opencode.jsonc"])
    pass("shouldWalkBackFromDomainAgentsToScopeWithoutWriting")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldParseDomainCatalogWhenDiscoveringAgents(): Promise<void> {
  const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-catalog."))
  try {
    // Given duplicate names, a missing mode, and unsorted entries
    await writeJson(path.join(scratch, "agents.json"), [
      { name: "beta", domain: "two" },
      { name: "alpha", domain: "one", mode: "primary" },
      { name: "beta", domain: "two", mode: "primary" },
    ])

    // When
    const agents = await discoverHarnessAgents(scratch)

    // Then names are deduplicated (last entry wins), sorted, and mode falls back to subagent
    assert.deepEqual(agents, [
      { name: "alpha", domain: "one", mode: "primary" },
      { name: "beta", domain: "two", mode: "primary" },
    ])

    // And legacy flat string catalogs are rejected
    await writeJson(path.join(scratch, "agents.json"), ["alpha"])
    await assert.rejects(() => discoverHarnessAgents(scratch), /agent catalog is invalid/)

    // And entries without a domain are rejected
    await writeJson(path.join(scratch, "agents.json"), [{ name: "alpha" }])
    await assert.rejects(() => discoverHarnessAgents(scratch), /agent catalog is invalid/)
    pass("shouldParseDomainCatalogWhenDiscoveringAgents")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldGroupAgentsByDomainOrderedBySizeThenName(): Promise<void> {
  // Given
  const agents: CatalogAgent[] = [
    { name: "a1", domain: "small-b", mode: "subagent" },
    { name: "a2", domain: "big", mode: "primary" },
    { name: "a3", domain: "big", mode: "subagent" },
    { name: "a4", domain: "small-a", mode: "subagent" },
  ]

  // When
  const groups = groupAgentsByDomain(agents)

  // Then bigger domains come first and ties break alphabetically
  assert.deepEqual(
    groups.map((group) => group.domain),
    ["big", "small-a", "small-b"],
  )
  assert.deepEqual(
    groups[0].agents.map((agent) => agent.name),
    ["a2", "a3"],
  )
  pass("shouldGroupAgentsByDomainOrderedBySizeThenName")
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

async function shouldOverwritePresetWhenSavingUnderExistingName(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a saved preset that differs from the current config
    const configFile = path.join(scratch.project, ".opencode", "opencode.jsonc")
    const presetsPath = path.join(scratch.global, "model-configurator-presets.json")
    await savePreset(presetsPath, {
      name: "saved",
      savedAt: "2026-01-01T00:00:00.000Z",
      assignments: { alpha: { model: "openai/new", variant: "high" } },
    })
    const toasts: TuiToast[] = []
    let promptedValue: string | undefined
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Select domain") return option(options, "__preset__:saved")
        if (title === "Preset: saved") return option(options, "__apply_preset__")
        if (title.startsWith("Apply ")) return option(options, "__apply_save__")
        if (title === 'Overwrite preset "saved"?') return option(options, "__overwrite_preset__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
      prompt(title, value) {
        if (title !== "Preset name") throw new Error(`unexpected prompt dialog: ${title}`)
        promptedValue = value
        return "saved"
      },
    })

    // When the preset is re-applied and saved back under its existing name
    await runModelConfigurator(api, scratch.data)

    // Then the prompt opened empty (no default), the config was written, and the preset was overwritten in place
    assert.equal(promptedValue, undefined)
    const persisted = await readConfigSnapshot(configFile)
    assert.deepEqual(persisted.mappings, {
      alpha: { model: "openai/new", variant: "high" },
      beta: { model: "anthropic/old", variant: undefined },
    })
    const presets = await loadPresets(presetsPath)
    assert.equal(presets.length, 1)
    assert.equal(presets[0].name, "saved")
    assert.deepEqual(presets[0].assignments, {
      alpha: { model: "openai/new", variant: "high" },
      beta: { model: "anthropic/old" },
    })
    pass("shouldOverwritePresetWhenSavingUnderExistingName")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldToastAndRepromptWhenPresetNameIsEmpty(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a domain-browse run that ends in "Apply and save as preset"
    const presetsPath = path.join(scratch.global, "model-configurator-presets.json")
    const toasts: TuiToast[] = []
    let hubVisits = 0
    let domainVisits = 0
    let prompts = 0
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Select domain") {
          hubVisits += 1
          return option(options, hubVisits === 1 ? "__domain__:one" : "__review_changes__")
        }
        if (title === "one agents") {
          domainVisits += 1
          return option(options, domainVisits === 1 ? "alpha" : "__done__")
        }
        if (title === "Configure: alpha") return option(options, "openai/new")
        if (title === "Variant for openai/new") return option(options, "high")
        if (title.startsWith("Apply ")) return option(options, "__apply_save__")
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
      prompt(title) {
        if (title !== "Preset name") throw new Error(`unexpected prompt dialog: ${title}`)
        prompts += 1
        return prompts === 1 ? "   " : "x"
      },
    })

    // When the first name is blank
    await runModelConfigurator(api, scratch.data)

    // Then a warning toast fires, the prompt re-opens, and the second name is saved
    assert.equal(prompts, 2)
    assert.ok(toasts.some((toast) => toast.variant === "warning" && toast.message === "Preset name cannot be empty."))
    const presets = await loadPresets(presetsPath)
    assert.deepEqual(
      presets.map((preset) => preset.name),
      ["x"],
    )
    pass("shouldToastAndRepromptWhenPresetNameIsEmpty")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
}

async function shouldGroupReviewChangesByDomain(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given pending changes in two domains
    const toasts: TuiToast[] = []
    let hubVisits = 0
    let oneVisits = 0
    let twoVisits = 0
    let reviewRows: Array<{ value: string; category?: string }> = []
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Select domain") {
          hubVisits += 1
          if (hubVisits === 1) return option(options, "__domain__:one")
          if (hubVisits === 2) return option(options, "__domain__:two")
          return option(options, "__review_changes__")
        }
        if (title === "one agents") {
          oneVisits += 1
          return option(options, oneVisits === 1 ? "alpha" : "__done__")
        }
        if (title === "two agents") {
          twoVisits += 1
          return option(options, twoVisits === 1 ? "beta" : "__done__")
        }
        if (title === "Configure: alpha" || title === "Configure: beta") return option(options, "openai/new")
        if (title === "Variant for openai/new") return option(options, "high")
        if (title.startsWith("Apply ")) {
          reviewRows = (options as Array<{ value: string; category?: string }>).filter((candidate) =>
            candidate.value.startsWith("__change__:"),
          )
          return option(options, "__apply__")
        }
        throw new Error(`unexpected select dialog: ${title}`)
      },
      confirm() {
        return true
      },
    })

    // When
    await runModelConfigurator(api, scratch.data)

    // Then each change row is categorized by its agent's domain
    assert.deepEqual(
      reviewRows.map((row) => ({ value: row.value, category: row.category })),
      [
        { value: "__change__:alpha", category: "one" },
        { value: "__change__:beta", category: "two" },
      ],
    )
    assert.equal(toasts.at(-1)?.variant, "success")
    pass("shouldGroupReviewChangesByDomain")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
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

async function shouldPlanGlobalHotApplyAsPatchWithLocalPreludeForDeletions(): Promise<void> {
  // Given a mix of a model set, an inherit, and a variant-removal-only set
  const changes: AgentChange[] = [
    { agent: "alpha", before: { model: "openai/old" }, after: { model: "openai/new", variant: "high" }, action: "set" },
    { agent: "beta", before: { model: "anthropic/old" }, after: {}, action: "inherit" },
    { agent: "gamma", before: { model: "openai/keep", variant: "low" }, after: { model: "openai/keep" }, action: "set" },
  ]

  // When
  const plan = planGlobalHotApply(changes)

  // Then deletions go to the local prelude and PATCHable leaves to the payload
  assert.equal(plan.strategy, "patch")
  if (plan.strategy !== "patch") return
  assert.deepEqual(plan.preludeChanges, [
    changes[1],
    { agent: "gamma", before: { model: "openai/keep", variant: "low" }, after: { model: "openai/keep" }, action: "set" },
  ])
  assert.deepEqual(plan.patch, {
    agent: {
      alpha: { model: "openai/new", variant: "high" },
      gamma: { model: "openai/keep" },
    },
  })
  assert.deepEqual(plan.fallbackChanges, [changes[0], changes[2]])
  pass("shouldPlanGlobalHotApplyAsPatchWithLocalPreludeForDeletions")
}

async function shouldPlanWriteOnlyWhenGlobalChangesAreRemovalOnly(): Promise<void> {
  // Given inherit-only changes, and separately a variant-removal-only set
  const inheritOnly: AgentChange[] = [
    { agent: "beta", before: { model: "anthropic/old" }, after: {}, action: "inherit" },
  ]
  const variantRemovalOnly: AgentChange[] = [
    { agent: "gamma", before: { model: "openai/keep", variant: "low" }, after: { model: "openai/keep" }, action: "set" },
  ]

  // Then neither has a byte-changing leaf the global PATCH could carry
  assert.equal(planGlobalHotApply(inheritOnly).strategy, "write-only")
  assert.equal(planGlobalHotApply(variantRemovalOnly).strategy, "write-only")
  pass("shouldPlanWriteOnlyWhenGlobalChangesAreRemovalOnly")
}

async function shouldHotApplyProjectScopeByDisposingTheProjectInstance(): Promise<void> {
  const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-hot-apply."))
  try {
    // Given a project config snapshot and a client exposing instance disposal.
    // Like the SDK v2 generated groups, the fake is a class whose method reads
    // this — a detached (unbound) call fails here like it does in production.
    const file = path.join(scratch, "opencode.jsonc")
    await writeFile(file, '{\n  "agent": {\n    "alpha": {"model": "openai/old"}\n  }\n}\n')
    const snapshot = await readConfigSnapshot(file)
    class FakeInstanceGroup {
      disposedDirectories: string[] = []
      async dispose(parameters: { directory: string }) {
        this.disposedDirectories.push(parameters.directory)
        return { data: true }
      }
    }
    const instance = new FakeInstanceGroup()
    const client = { instance }
    const runtime = { config: scratch, worktree: "/work/project", directory: "/work/project" }
    const changes: AgentChange[] = [
      { agent: "alpha", before: { model: "openai/old" }, after: { model: "openai/new" }, action: "set" },
    ]

    // When
    const result = await applyConfigChanges(client, "project", runtime, snapshot, changes)

    // Then the write lands and the project instance is disposed once
    assert.deepEqual(result, { file, hotApplied: true })
    assert.deepEqual(instance.disposedDirectories, ["/work/project"])
    assert.deepEqual((await readConfigSnapshot(file)).mappings, { alpha: { model: "openai/new", variant: undefined } })
    pass("shouldHotApplyProjectScopeByDisposingTheProjectInstance")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldHotApplyGlobalScopeViaConfigPatchAfterLocalDeletions(): Promise<void> {
  const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-hot-apply."))
  try {
    // Given a global config with an inherit target and a stale variant to delete
    const file = path.join(scratch, "opencode.jsonc")
    await writeFile(
      file,
      '{\n  // Keep me.\n  "agent": {\n    "alpha": {"model": "openai/old"},\n    "beta": {"model": "anthropic/old"},\n    "gamma": {"model": "openai/keep", "variant": "low"}\n  }\n}\n',
    )
    const snapshot = await readConfigSnapshot(file)
    // Class-based fake like the SDK v2 groups: update reads this, so an
    // unbound call fails here like it does in production.
    class FakeGlobalConfigGroup {
      patches: Array<{ config: unknown; fileAtPatchTime: string }> = []
      async update(parameters: { config: unknown }) {
        this.patches.push({ config: parameters.config, fileAtPatchTime: await readFile(file, "utf8") })
        return { data: {} }
      }
    }
    const globalConfig = new FakeGlobalConfigGroup()
    const client = { global: { config: globalConfig } }
    const runtime = { config: scratch, worktree: "/work/project", directory: "/work/project" }
    const changes: AgentChange[] = [
      { agent: "alpha", before: { model: "openai/old" }, after: { model: "openai/new", variant: "high" }, action: "set" },
      { agent: "beta", before: { model: "anthropic/old" }, after: {}, action: "inherit" },
      { agent: "gamma", before: { model: "openai/keep", variant: "low" }, after: { model: "openai/keep" }, action: "set" },
    ]

    // When
    const result = await applyConfigChanges(client, "global", runtime, snapshot, changes)

    // Then deletions were on disk before the PATCH, which carried only the set leaves
    assert.deepEqual(result, { file, hotApplied: true })
    assert.equal(globalConfig.patches.length, 1)
    assert.deepEqual(globalConfig.patches[0].config, {
      agent: { alpha: { model: "openai/new", variant: "high" }, gamma: { model: "openai/keep" } },
    })
    assert.equal(globalConfig.patches[0].fileAtPatchTime.includes("beta"), false)
    assert.equal(globalConfig.patches[0].fileAtPatchTime.includes("low"), false)
    assert.equal(globalConfig.patches[0].fileAtPatchTime.includes("// Keep me."), true)
    // And the set leaves stay with the server-side PATCH, not a second local write
    assert.deepEqual((await readConfigSnapshot(file)).mappings, {
      alpha: { model: "openai/old", variant: undefined },
      gamma: { model: "openai/keep", variant: undefined },
    })
    pass("shouldHotApplyGlobalScopeViaConfigPatchAfterLocalDeletions")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldFallBackToLocalWriteWhenGlobalPatchFails(): Promise<void> {
  const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-hot-apply."))
  try {
    // Given a global PATCH that the server rejects
    const file = path.join(scratch, "opencode.jsonc")
    await writeFile(file, '{\n  "agent": {\n    "alpha": {"model": "openai/old"},\n    "beta": {"model": "anthropic/old"}\n  }\n}\n')
    const snapshot = await readConfigSnapshot(file)
    const client = {
      global: {
        config: {
          update: async () => ({ error: { name: "BadRequest" }, response: { status: 400 } }),
        },
      },
    }
    const runtime = { config: scratch, worktree: "/work/project", directory: "/work/project" }
    const changes: AgentChange[] = [
      { agent: "alpha", before: { model: "openai/old" }, after: { model: "openai/new" }, action: "set" },
      { agent: "beta", before: { model: "anthropic/old" }, after: {}, action: "inherit" },
    ]

    // When
    const result = await applyConfigChanges(client, "global", runtime, snapshot, changes)

    // Then every change still lands locally and the outcome reports the failure
    assert.equal(result.hotApplied, false)
    assert.equal(result.detail?.includes("status 400"), true)
    assert.deepEqual((await readConfigSnapshot(file)).mappings, { alpha: { model: "openai/new", variant: undefined } })
    pass("shouldFallBackToLocalWriteWhenGlobalPatchFails")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldReportRestartFallbackWhenClientLacksHotApplyRoutes(): Promise<void> {
  const scratch = await mkdtemp(path.join(tmpdir(), "model-configurator-hot-apply."))
  try {
    // Given clients without the disposal and global config update capabilities
    const file = path.join(scratch, "opencode.jsonc")
    await writeFile(file, '{\n  "agent": {\n    "alpha": {"model": "openai/old"}\n  }\n}\n')
    const runtime = { config: scratch, worktree: "/work/project", directory: "/work/project" }
    const changes: AgentChange[] = [
      { agent: "alpha", before: { model: "openai/old" }, after: { model: "openai/new" }, action: "set" },
    ]

    // When / Then the write still lands and the outcome degrades to restart guidance
    const project = await applyConfigChanges({}, "project", runtime, await readConfigSnapshot(file), changes)
    assert.equal(project.hotApplied, false)
    assert.equal(project.detail?.includes("instance disposal"), true)
    assert.deepEqual((await readConfigSnapshot(file)).mappings, { alpha: { model: "openai/new", variant: undefined } })

    const back: AgentChange[] = [
      { agent: "alpha", before: { model: "openai/new" }, after: { model: "openai/old" }, action: "set" },
    ]
    const global = await applyConfigChanges({}, "global", runtime, await readConfigSnapshot(file), back)
    assert.equal(global.hotApplied, false)
    assert.equal(global.detail?.includes("global config route"), true)
    assert.deepEqual((await readConfigSnapshot(file)).mappings, { alpha: { model: "openai/old", variant: undefined } })
    pass("shouldReportRestartFallbackWhenClientLacksHotApplyRoutes")
  } finally {
    await rm(scratch, { recursive: true, force: true })
  }
}

async function shouldToastLiveApplyWhenProjectInstanceDisposalSucceeds(): Promise<void> {
  const scratch = await createWizardFixture()
  try {
    // Given a wizard client that can dispose the project instance
    const toasts: TuiToast[] = []
    class FakeInstanceGroup {
      disposedDirectories: string[] = []
      async dispose(parameters: { directory: string }) {
        this.disposedDirectories.push(parameters.directory)
        return { data: true }
      }
    }
    const instanceGroup = new FakeInstanceGroup()
    const api = createFakeApi(scratch, toasts, {
      select(title, options) {
        if (title === "Configuration scope") return option(options, "project")
        if (title === "Select domain") return option(options, "default")
        if (title === "Tier: high") return option(options, "openai/new")
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
    ;(api.client as unknown as Record<string, unknown>).instance = instanceGroup

    // When
    await runModelConfigurator(api, scratch.data)

    // Then the success toast reports a live apply and the project instance was disposed
    assert.deepEqual(instanceGroup.disposedDirectories, [scratch.project])
    assert.equal(toasts.at(-1)?.variant, "success")
    assert.equal(toasts.at(-1)?.message?.includes("Applied live"), true)
    pass("shouldToastLiveApplyWhenProjectInstanceDisposalSucceeds")
  } finally {
    await rm(scratch.root, { recursive: true, force: true })
  }
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
  prompt?: (title: string, value?: string) => string | "escape"
}

async function createWizardFixture(): Promise<WizardFixture> {
  const root = await mkdtemp(path.join(tmpdir(), "model-configurator-wizard."))
  const data = path.join(root, "runtime-data")
  const project = path.join(root, "project")
  const global = path.join(root, "global")
  await Promise.all([
    writeJson(path.join(data, "agents.json"), [
      { name: "alpha", domain: "one", mode: "primary" },
      { name: "beta", domain: "two", mode: "subagent" },
    ]),
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
          const answer = policy.prompt(props.title, props.value)
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
await shouldWriteWithoutBackupAndPreserveModeWhenWriteSucceeds()
await shouldRejectConcurrentEditBeforeWriting()
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
await shouldConfigureAgentThroughDomainBrowseAndApply()
await shouldWalkBackFromDomainAgentsToScopeWithoutWriting()
await shouldParseDomainCatalogWhenDiscoveringAgents()
await shouldGroupAgentsByDomainOrderedBySizeThenName()
await shouldRoundTripAndOverwritePresetsWhenSaved()
await shouldOverwritePresetWhenSavingUnderExistingName()
await shouldToastAndRepromptWhenPresetNameIsEmpty()
await shouldGroupReviewChangesByDomain()
await shouldPartitionPresetAssignmentsByLiveCatalog()
await shouldPlanGlobalHotApplyAsPatchWithLocalPreludeForDeletions()
await shouldPlanWriteOnlyWhenGlobalChangesAreRemovalOnly()
await shouldHotApplyProjectScopeByDisposingTheProjectInstance()
await shouldHotApplyGlobalScopeViaConfigPatchAfterLocalDeletions()
await shouldFallBackToLocalWriteWhenGlobalPatchFails()
await shouldReportRestartFallbackWhenClientLacksHotApplyRoutes()
await shouldToastLiveApplyWhenProjectInstanceDisposalSucceeds()
await shouldShortenConfigFilePathsForDisplay()
process.stdout.write(`PASS: ${passes} TypeScript model configurator contracts.\n`)
