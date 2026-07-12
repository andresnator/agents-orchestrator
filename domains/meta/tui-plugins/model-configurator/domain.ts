import { readdir, readFile, realpath, stat } from "fs/promises"
import path from "path"
import { fileURLToPath } from "url"

export const DEFAULT_PROFILE_NAME = "default"
export const JUDGE_A_AGENT = "jd-judge-a"
export const JUDGE_B_AGENT = "jd-judge-b"

export type AgentMapping = {
  model?: string
  variant?: string
}

export type AgentDecision =
  | { action: "keep" }
  | { action: "inherit" }
  | { action: "set"; model: string; variant?: string }

export type AgentChange = {
  agent: string
  before: AgentMapping
  after: AgentMapping
  action: "inherit" | "set"
}

export type ModelOption = {
  id: string
  variants: string[]
}

export type ProviderOption = {
  id: string
  models: ModelOption[]
}

export type TierProfile = {
  description: string
  variant?: string
  agents: string[]
}

export type ModelProfile = {
  name: string
  description: string
  tiers: Record<string, TierProfile>
}

export type ProfileValidation = {
  profile?: ModelProfile
  errors: string[]
  warnings: string[]
}

export type ProfileFile = {
  path: string
  profile: ModelProfile
  warnings: string[]
}

export async function resolveRuntimeDataRoot(moduleUrl: string): Promise<string> {
  const root = path.join(path.dirname(await realpath(fileURLToPath(moduleUrl))), "model-configurator")
  const [agents, profiles] = await Promise.all([stat(path.join(root, "agents.json")), stat(path.join(root, "profiles"))])
  if (!agents.isFile() || !profiles.isDirectory()) throw new Error("Installed model configurator data is incomplete")
  return root
}

export async function discoverHarnessAgents(runtimeDataRoot: string): Promise<string[]> {
  const raw = JSON.parse(await readFile(path.join(runtimeDataRoot, "agents.json"), "utf8")) as unknown
  if (!Array.isArray(raw) || raw.some((agent) => typeof agent !== "string")) {
    throw new Error("Installed model configurator agent catalog is invalid")
  }
  return [...new Set(raw)].sort()
}

export async function loadProfiles(runtimeDataRoot: string, agents: readonly string[]): Promise<ProfileFile[]> {
  const profilesRoot = path.join(runtimeDataRoot, "profiles")
  const files = (await readdir(profilesRoot, { withFileTypes: true }))
    .filter((entry) => entry.isFile() && entry.name.endsWith(".json"))
    .sort((left, right) => left.name.localeCompare(right.name))

  const profiles: ProfileFile[] = []
  for (const file of files) {
    const profilePath = path.join(profilesRoot, file.name)
    const raw = JSON.parse(await readFile(profilePath, "utf8")) as unknown
    const validation = validateProfile(raw, agents)
    if (!validation.profile) {
      throw new Error(`${profilePath}: ${validation.errors.join("; ")}`)
    }
    profiles.push({ path: profilePath, profile: validation.profile, warnings: validation.warnings })
  }
  return profiles
}

export function validateProfile(raw: unknown, agents: readonly string[]): ProfileValidation {
  const errors: string[] = []
  const warnings: string[] = []
  if (!isRecord(raw)) return { errors: ["profile must be an object"], warnings }
  if (!isRecord(raw.tiers)) return { errors: ["profile must contain a tiers object"], warnings }

  const knownAgents = new Set(agents)
  const coveredAgents = new Set<string>()
  const tiers: Record<string, TierProfile> = {}

  for (const [tierName, tierValue] of Object.entries(raw.tiers)) {
    if (!isRecord(tierValue) || !Array.isArray(tierValue.agents)) {
      errors.push(`tier '${tierName}' must contain an agents array`)
      continue
    }
    const tierAgents = tierValue.agents.filter((agent): agent is string => typeof agent === "string")
    if (tierAgents.length !== tierValue.agents.length) errors.push(`tier '${tierName}' contains a non-string agent`)
    for (const agent of tierAgents) {
      if (coveredAgents.has(agent)) errors.push(`agent '${agent}' appears in more than one tier`)
      if (!knownAgents.has(agent)) errors.push(`tier '${tierName}' references unknown agent '${agent}'`)
      coveredAgents.add(agent)
    }
    const tier: TierProfile = {
      description: typeof tierValue.description === "string" ? tierValue.description : "",
      agents: tierAgents,
    }
    if (typeof tierValue.variant === "string") tier.variant = tierValue.variant
    tiers[tierName] = tier
  }

  const uncovered = agents.filter((agent) => !coveredAgents.has(agent))
  if (uncovered.length > 0) warnings.push(`agents not covered by a tier: ${uncovered.join(", ")}`)
  if (errors.length > 0) return { errors, warnings }

  return {
    profile: {
      name: typeof raw.name === "string" ? raw.name : "unnamed",
      description: typeof raw.description === "string" ? raw.description : "",
      tiers,
    },
    errors,
    warnings,
  }
}

export function normalizeProviderCatalog(result: unknown): ProviderOption[] {
  const root = isRecord(result) && "data" in result ? result.data : result
  if (!isRecord(root)) return []

  const connected = new Set(
    Array.isArray(root.connected) ? root.connected.filter((provider): provider is string => typeof provider === "string") : [],
  )
  const providers = Array.isArray(root.all) ? root.all : []

  return providers
    .filter(isRecord)
    .filter((provider) => typeof provider.id === "string" && connected.has(provider.id))
    .map((provider) => ({ id: provider.id as string, models: normalizeModels(provider.models) }))
    .filter((provider) => provider.models.length > 0)
    .sort((left, right) => left.id.localeCompare(right.id))
}

export function flattenModels(providers: readonly ProviderOption[]): ModelOption[] {
  return providers.flatMap((provider) =>
    provider.models.map((model) => ({ id: `${provider.id}/${model.id}`, variants: model.variants })),
  )
}

export function calculateChanges(
  current: Readonly<Record<string, AgentMapping>>,
  decisions: ReadonlyMap<string, AgentDecision>,
): AgentChange[] {
  const changes: AgentChange[] = []
  for (const [agent, decision] of decisions) {
    if (decision.action === "keep") continue
    const before = normalizeMapping(current[agent])
    const after =
      decision.action === "inherit"
        ? {}
        : decision.variant
          ? { model: decision.model, variant: decision.variant }
          : { model: decision.model }
    if (sameMapping(before, after)) continue
    changes.push({ agent, before, after, action: decision.action })
  }
  return changes.sort((left, right) => left.agent.localeCompare(right.agent))
}

export function sameProviderForJudges(changes: readonly AgentChange[], current: Readonly<Record<string, AgentMapping>>): boolean {
  const resolved = { ...current }
  for (const change of changes) resolved[change.agent] = change.after
  const judgeA = providerOf(resolved[JUDGE_A_AGENT]?.model)
  const judgeB = providerOf(resolved[JUDGE_B_AGENT]?.model)
  return Boolean(judgeA && judgeB && judgeA === judgeB)
}

export function formatMapping(mapping: AgentMapping): string {
  if (!mapping.model) return "inherits"
  return mapping.variant ? `${mapping.model} variant=${mapping.variant}` : mapping.model
}

function normalizeModels(raw: unknown): ModelOption[] {
  const entries = Array.isArray(raw)
    ? raw.filter(isRecord).map((model) => [model.id, model] as const)
    : isRecord(raw)
      ? Object.entries(raw)
      : []

  return entries
    .filter((entry): entry is readonly [string, Record<string, unknown>] => typeof entry[0] === "string" && isRecord(entry[1]))
    .map(([id, model]) => ({ id, variants: normalizeVariants(model.variants) }))
    .sort((left, right) => left.id.localeCompare(right.id))
}

function normalizeVariants(raw: unknown): string[] {
  if (Array.isArray(raw)) return raw.filter((variant): variant is string => typeof variant === "string").sort()
  if (isRecord(raw)) return Object.keys(raw).sort()
  return []
}

function normalizeMapping(mapping: AgentMapping | undefined): AgentMapping {
  if (!mapping?.model) return {}
  return mapping.variant ? { model: mapping.model, variant: mapping.variant } : { model: mapping.model }
}

function sameMapping(left: AgentMapping, right: AgentMapping): boolean {
  return left.model === right.model && left.variant === right.variant
}

function providerOf(model: string | undefined): string | undefined {
  return model?.includes("/") ? model.slice(0, model.indexOf("/")) : undefined
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}
