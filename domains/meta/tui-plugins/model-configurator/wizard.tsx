import type { TuiDialogSelectOption, TuiPluginApi } from "@opencode-ai/plugin/tui"
import {
  DEFAULT_PROFILE_NAME,
  calculateChanges,
  discoverHarnessAgents,
  flattenModels,
  formatMapping,
  loadProfiles,
  normalizeProviderCatalog,
  sameProviderForJudges,
  type AgentDecision,
  type AgentMapping,
  type ModelOption,
  type ModelProfile,
  type ProfileFile,
} from "./domain"
import {
  higherPrecedenceWarning,
  readConfigSnapshot,
  resolveConfigFile,
  writeConfigChanges,
  type ConfigScope,
} from "./persistence"

const DONE = "__done__"
const KEEP_CURRENT = "__keep_current__"
const USE_TIER = "__use_tier__"
const INHERIT = "__inherit__"
const NO_VARIANT = "__no_variant__"
let configuratorRunning = false

export async function runModelConfigurator(api: TuiPluginApi, runtimeDataRoot: string): Promise<void> {
  if (configuratorRunning) {
    api.ui.toast({ variant: "warning", message: "The model configurator is already open." })
    return
  }
  configuratorRunning = true
  try {
    if (!api.state.ready || !api.state.path.directory) {
      api.ui.toast({ variant: "warning", message: "OpenCode paths are still syncing. Try again in a moment." })
      return
    }

    const agents = await discoverHarnessAgents(runtimeDataRoot)
    const profiles = await loadProfiles(runtimeDataRoot, agents)
    const scope = await selectScope(api)
    if (!scope) return

    const configFile = await resolveConfigFile(scope, api.state.path)
    const snapshot = await readConfigSnapshot(configFile)
    const profileFile = await selectProfile(api, profiles)
    if (!profileFile) return
    for (const warning of profileFile.warnings) api.ui.toast({ variant: "warning", message: warning })

    const catalog = await loadCatalog(api)
    if (catalog.length === 0) {
      api.ui.toast({ variant: "warning", message: "No connected providers with models are available. Connect one and retry." })
      return
    }

    const models = flattenModels(catalog)
    const tierDecisions = await selectTierDecisions(api, profileFile.profile, models, snapshot.mappings)
    if (!tierDecisions) return
    const decisions = new Map(tierDecisions)
    const overridesCompleted = await selectOverrides(api, agents, models, tierDecisions, decisions, snapshot.mappings)
    if (!overridesCompleted) return

    const changes = calculateChanges(snapshot.mappings, decisions)
    if (changes.length === 0) {
      api.ui.toast({ variant: "info", message: "No model assignment changes selected." })
      return
    }

    if (sameProviderForJudges(changes, snapshot.mappings)) {
      const continueWithSharedProvider = await confirm(
        api,
        "Judges share a provider",
        "jd-judge-a and jd-judge-b resolve to the same provider. Different providers strengthen blind review. Continue anyway?",
      )
      if (!continueWithSharedProvider) return
    }

    const refreshedModels = flattenModels(await loadCatalog(api))
    const stale = findStaleSelections(decisions, refreshedModels)
    if (stale.length > 0) {
      api.ui.toast({ variant: "warning", message: `Selections changed in the live catalog: ${stale.join(", ")}. Reopen and select again.` })
      return
    }

    const warning = higherPrecedenceWarning()
    const summary = changes
      .map((change) => `${change.agent}: ${formatMapping(change.before)} -> ${formatMapping(change.after)}`)
      .join("\n")
    const approved = await confirm(
      api,
      `Apply ${changes.length} model change${changes.length === 1 ? "" : "s"}?`,
      [warning, summary].filter(Boolean).join("\n\n"),
    )
    if (!approved) return

    const result = await writeConfigChanges(snapshot, changes)
    const backup = result.backup ? ` Backup: ${result.backup}.` : ""
    api.ui.toast({
      variant: "success",
      title: "Agent models updated",
      message: `Wrote ${result.file}.${backup} Restart OpenCode sessions to apply the assignments.`,
      duration: 8000,
    })
  } catch (error) {
    api.ui.toast({ variant: "error", title: "Model configurator failed", message: errorMessage(error), duration: 8000 })
  } finally {
    api.ui.dialog.clear()
    configuratorRunning = false
  }
}

async function selectScope(api: TuiPluginApi): Promise<ConfigScope | undefined> {
  const [projectFile, globalFile] = await Promise.all([
    resolveConfigFile("project", api.state.path),
    resolveConfigFile("global", api.state.path),
  ])
  const warning = higherPrecedenceWarning()
  return select(api, "Configuration scope", [
    { title: "Project", value: "project", description: `${projectFile}${warning ? ` — ${warning}` : ""}` },
    { title: "Global", value: "global", description: `${globalFile}${warning ? ` — ${warning}` : ""}` },
  ])
}

async function selectProfile(api: TuiPluginApi, profiles: readonly ProfileFile[]): Promise<ProfileFile | undefined> {
  const selected = await select(
    api,
    "Tier profile",
    profiles.map((file) => ({
      title: file.profile.name,
      value: file.profile.name,
      description: file.profile.description,
    })),
    DEFAULT_PROFILE_NAME,
  )
  return profiles.find((file) => file.profile.name === selected)
}

async function selectTierDecisions(
  api: TuiPluginApi,
  profile: ModelProfile,
  models: readonly ModelOption[],
  current: Readonly<Record<string, AgentMapping>>,
): Promise<Map<string, AgentDecision> | undefined> {
  const decisions = new Map<string, AgentDecision>()
  for (const [tierName, tier] of Object.entries(profile.tiers)) {
    if (tier.agents.length === 0) continue
    const currentSummary = tier.agents.map((agent) => `${agent}: ${formatMapping(current[agent] ?? {})}`).join("; ")
    const decision = await selectDecision(api, `Tier: ${tierName}`, models, tier.variant, currentSummary)
    if (!decision) return undefined
    if (decision.action !== "keep") for (const agent of tier.agents) decisions.set(agent, decision)
  }
  return decisions
}

async function selectOverrides(
  api: TuiPluginApi,
  agents: readonly string[],
  models: readonly ModelOption[],
  tierDecisions: ReadonlyMap<string, AgentDecision>,
  decisions: Map<string, AgentDecision>,
  current: Readonly<Record<string, AgentMapping>>,
): Promise<boolean> {
  const wantsOverrides = await confirm(api, "Individual overrides", "Override any individual agent after applying tier decisions?")
  if (!wantsOverrides) return true

  while (true) {
    const selected = await select(api, "Choose agent to override", [
      { title: "Done", value: DONE },
      ...agents.map((agent) => ({
        title: agent,
        value: agent,
        description: decisionDisplay(decisions.get(agent), current[agent]),
      })),
    ])
    if (!selected) return false
    if (selected === DONE) return true

    const action = await select(api, `Override: ${selected}`, [
      { title: "Use tier decision", value: USE_TIER, description: decisionDisplay(tierDecisions.get(selected), current[selected]) },
      { title: "Keep current", value: KEEP_CURRENT, description: formatMapping(current[selected] ?? {}) },
      { title: "Inherit", value: INHERIT, description: "Remove model and variant at this scope" },
      ...models.map((model) => ({ title: model.id, value: model.id, description: variantDescription(model) })),
    ])
    if (!action) return false
    if (action === USE_TIER) {
      const tier = tierDecisions.get(selected)
      if (tier) decisions.set(selected, tier)
      else decisions.delete(selected)
    } else if (action === KEEP_CURRENT) {
      decisions.delete(selected)
    } else if (action === INHERIT) {
      decisions.set(selected, { action: "inherit" })
    } else {
      const model = models.find((candidate) => candidate.id === action)
      if (!model) return false
      const variant = await selectVariant(api, model)
      if (variant === undefined) return false
      decisions.set(selected, { action: "set", model: model.id, variant: variant || undefined })
    }
  }
}

async function selectDecision(
  api: TuiPluginApi,
  title: string,
  models: readonly ModelOption[],
  suggestedVariant: string | undefined,
  currentSummary: string,
): Promise<AgentDecision | undefined> {
  const action = await select(api, title, [
    { title: "Keep current", value: KEEP_CURRENT, description: currentSummary },
    { title: "Inherit", value: INHERIT, description: "Remove model and variant at this scope" },
    ...models.map((model) => ({ title: model.id, value: model.id, description: variantDescription(model) })),
  ])
  if (!action) return undefined
  if (action === KEEP_CURRENT) return { action: "keep" }
  if (action === INHERIT) return { action: "inherit" }
  const model = models.find((candidate) => candidate.id === action)
  if (!model) return undefined
  const variant = await selectVariant(api, model, suggestedVariant)
  if (variant === undefined) return undefined
  return { action: "set", model: model.id, variant: variant || undefined }
}

async function selectVariant(api: TuiPluginApi, model: ModelOption, suggested?: string): Promise<string | undefined> {
  const selected = await select(
    api,
    `Variant for ${model.id}`,
    [
      { title: "None", value: NO_VARIANT },
      ...model.variants.map((variant) => ({ title: variant, value: variant })),
    ],
    suggested && model.variants.includes(suggested) ? suggested : NO_VARIANT,
  )
  if (selected === undefined) return undefined
  return selected === NO_VARIANT ? "" : selected
}

async function loadCatalog(api: TuiPluginApi) {
  const result = await api.client.provider.list()
  return normalizeProviderCatalog(result)
}

function findStaleSelections(decisions: ReadonlyMap<string, AgentDecision>, models: readonly ModelOption[]): string[] {
  const live = new Map(models.map((model) => [model.id, new Set(model.variants)]))
  const stale = new Set<string>()
  for (const decision of decisions.values()) {
    if (decision.action !== "set") continue
    const variants = live.get(decision.model)
    if (!variants || (decision.variant && !variants.has(decision.variant))) stale.add(decision.model)
  }
  return [...stale].sort()
}

function decisionDisplay(decision: AgentDecision | undefined, current: AgentMapping | undefined): string {
  if (!decision || decision.action === "keep") return `keep (${formatMapping(current ?? {})})`
  if (decision.action === "inherit") return "inherit"
  return formatMapping({ model: decision.model, variant: decision.variant })
}

function variantDescription(model: ModelOption): string {
  return model.variants.length === 0 ? "No variants" : `${model.variants.length} variant${model.variants.length === 1 ? "" : "s"}`
}

function select<Value extends string>(
  api: TuiPluginApi,
  title: string,
  options: TuiDialogSelectOption<Value>[],
  current?: Value,
): Promise<Value | undefined> {
  return new Promise((resolve) => {
    const DialogSelect = api.ui.DialogSelect<Value>
    let settled = false
    const finish = (value?: Value) => {
      if (settled) return
      settled = true
      resolve(value)
    }
    api.ui.dialog.replace(
      () =>
        DialogSelect({
          title,
          options,
          current,
          onSelect: (option) => {
            finish(option.value)
            api.ui.dialog.clear()
          },
        }),
      () => finish(undefined),
    )
  })
}

function confirm(api: TuiPluginApi, title: string, message: string): Promise<boolean> {
  return new Promise((resolve) => {
    const DialogConfirm = api.ui.DialogConfirm
    let settled = false
    const finish = (value: boolean) => {
      if (settled) return
      settled = true
      api.ui.dialog.clear()
      resolve(value)
    }
    api.ui.dialog.replace(
      () => DialogConfirm({ title, message, onConfirm: () => finish(true), onCancel: () => finish(false) }),
      () => finish(false),
    )
  })
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown model configurator error"
}
