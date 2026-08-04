import { execFile, spawn } from "node:child_process"
import { createHash, randomBytes } from "node:crypto"
import { closeSync, existsSync, openSync } from "node:fs"
import fs from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import { promisify } from "node:util"
import { fileURLToPath, pathToFileURL } from "node:url"
import type { Plugin } from "@opencode-ai/plugin"

const execFileAsync = promisify(execFile)

const PLUGIN_ID = "sdd-swarm"
const SCHEMA_VERSION = 1
const DEFAULT_MAX_WORKERS = 4
const MAX_WORKERS = 4
const DEFAULT_WORKER_TIMEOUT_SECONDS = 1_200
const TECHNICAL_RETRY_LIMIT = 1
const PROCESS_KILL_GRACE_MS = 2_000
const MAX_CAPTURE_BYTES = 10 * 1024 * 1024
const CHANGE_NAME = /^[a-z0-9][a-z0-9-]{0,63}$/
const GROUP_HEADING = /^##\s+(\d+)\.\s+(.+?)\s*$/
const TASK_LINE = /^- \[([ xX])\]\s+(\d+\.\d+)\s+(.+?)\s*$/
const FILES_LINE = /^Files:\s*(.*?)\s*$/
const DEPENDS_LINE = /^Depends on:\s*(.*?)\s*$/
const HOTSPOTS_LINE = /^Shared hotspots:\s*(.*?)\s*$/
const WORKER_ENV = "SDD_SWARM_WORKER"
const WORKTREE_ROOT_ENV = "SDD_SWARM_WORKTREE_ROOT"
const WORKER_MODEL_ENV = "SDD_SWARM_WORKER_MODEL"
const OPENCODE_BIN_ENV = "OPENCODE_BIN"
const NODE_BIN_ENV = "SDD_SWARM_NODE_BIN"
const BRANCH_NAMESPACE = "sdd-swarm"
const SUPERVISOR_AGENT = "sdd-swarm"
const READY_MARKER = /^Status: ready-for-sdd \| Source: ([a-z0-9][a-z0-9-]{0,63})$/
const ROADMAP_MARKER = /^Roadmap: ([a-z0-9][a-z0-9-]{0,63}) \| Slice: \d+\/\d+$/
const TERMINAL_STATUSES = new Set(["completed", "blocked", "failed", "aborted", "interrupted"])
const INTRINSIC_HOTSPOT_FILES = new Set([
  "build.gradle",
  "build.gradle.kts",
  "cargo.lock",
  "cargo.toml",
  "go.mod",
  "go.sum",
  "gradle.properties",
  "package-lock.json",
  "package.json",
  "pnpm-lock.yaml",
  "pom.xml",
  "pyproject.toml",
  "settings.gradle",
  "settings.gradle.kts",
  "yarn.lock",
])
const INTRINSIC_HOTSPOT_SEGMENTS = new Set([
  "fixtures",
  "generated",
  "generated-sources",
  "generated-test-sources",
  "registries",
  "registry",
])
const MODULE_PATH = fileURLToPath(import.meta.url)

type ExecutionMode = "mock" | "opencode"
type RunStatus = "queued" | "running" | "completed" | "blocked" | "failed" | "aborted" | "interrupted"
type WorkerStatus = "pending" | "running" | "passed" | "failed" | "timed_out"

type TaskItem = {
  id: string
  text: string
  done: boolean
}

type TaskGroup = {
  id: string
  title: string
  files: string[]
  depends_on: string[] | null
  tasks: TaskItem[]
  completed: boolean
  touches_hotspot: boolean
}

type SwarmPlan = {
  tasks_path: string
  shared_hotspots: string[]
  shared_hotspots_declared: boolean
  groups: TaskGroup[]
  waves: string[][]
  warnings: string[]
}

type SwarmConfig = {
  schema_version: number
  scoped_validation: Record<string, string[]>
  full_validation: string[]
  final_validation?: string[]
  mock_worker?: string[]
}

type Usage = {
  cost: number
  cost_measurable: boolean
  input_tokens: number
  output_tokens: number
  cache_tokens: number
}

type WorkerState = {
  group_id: string
  branch: string
  worktree: string
  status: WorkerStatus
  attempts: number
  pid?: number
  base_sha?: string
  commit?: string
  duration_ms?: number
  files_changed?: string[]
  validation?: string
  error?: string
  usage: Usage
}

type RunState = {
  schema_version: number
  run_id: string
  root: string
  change: string
  execution: ExecutionMode
  status: RunStatus
  created_at: string
  updated_at: string
  baseline_sha: string
  max_workers: number
  worker_timeout_seconds: number
  controller_pid?: number
  integration_branch: string
  integration_worktree: string
  plan: SwarmPlan
  config: SwarmConfig
  workers: Record<string, WorkerState>
  current_wave: number
  max_parallel: number
  error?: string
  cleaned?: boolean
  metrics: Usage & {
    wall_time_ms: number
    worker_wall_time_ms: number
    integration_wall_time_ms: number
  }
}

type ProcessResult = {
  exitCode: number | null
  timedOut: boolean
  durationMs: number
}

type Receipt = {
  wave: string
  tasksDone: string[]
  assertions: Array<{ task: string; file: string; line: number }>
  filesChanged: string[]
  outOfScope: string[]
  validation: string
  commit: string
  blockers: string[]
}

type BundleResolution = {
  directory: string
  warnings: string[]
}

type RoadmapUpdate = {
  file: string
  content: string
}

function nowIso(): string {
  return new Date().toISOString()
}

function splitList(value: string): string[] {
  const trimmed = value.trim()
  if (!trimmed || trimmed.toLowerCase() === "none") return []
  return trimmed.split(",").map((item) => item.trim()).filter(Boolean)
}

function normalizeRepoPath(value: string): string {
  return value.replaceAll("\\", "/").replace(/^\.\//, "").replace(/\/+$/, "")
}

function staticPrefix(glob: string): string {
  const normalized = normalizeRepoPath(glob)
  const wildcard = normalized.search(/[?*[]/)
  return (wildcard === -1 ? normalized : normalized.slice(0, wildcard)).replace(/\/+$/, "")
}

function scopesOverlap(left: string, right: string): boolean {
  const a = staticPrefix(left)
  const b = staticPrefix(right)
  if (!a || !b) return true
  return a === b || a.startsWith(`${b}/`) || b.startsWith(`${a}/`)
}

function globToRegExp(glob: string): RegExp {
  const normalized = normalizeRepoPath(glob)
  let result = "^"
  for (let index = 0; index < normalized.length; index += 1) {
    const character = normalized[index]
    if (character === "*" && normalized[index + 1] === "*") {
      if (normalized[index + 2] === "/") {
        result += "(?:.*/)?"
        index += 2
      } else {
        result += ".*"
        index += 1
      }
    } else if (character === "*") {
      result += "[^/]*"
    } else if (character === "?") {
      result += "[^/]"
    } else {
      result += character.replace(/[|\\{}()[\]^$+?.]/g, "\\$&")
    }
  }
  if (!/[?*[]/.test(normalized)) result += "(?:/.*)?"
  return new RegExp(`${result}$`)
}

function pathInScopes(file: string, scopes: string[]): boolean {
  const normalized = normalizeRepoPath(file)
  return scopes.some((scope) => globToRegExp(scope).test(normalized))
}

function groupTouchesHotspot(files: string[], hotspots: string[]): boolean {
  return files.some((scope) => hotspots.some((hotspot) => scopesOverlap(scope, hotspot)) || isIntrinsicHotspot(scope))
}

function isIntrinsicHotspot(scope: string): boolean {
  const normalized = normalizeRepoPath(scope).toLowerCase()
  const segments = normalized.split("/").filter(Boolean)
  const basename = segments.at(-1) ?? ""
  return INTRINSIC_HOTSPOT_FILES.has(basename) ||
    segments.some((segment) => INTRINSIC_HOTSPOT_SEGMENTS.has(segment)) ||
    normalized.includes("meta-inf/services")
}

function groupsOverlap(left: TaskGroup, right: TaskGroup): boolean {
  return left.files.some((leftScope) => right.files.some((rightScope) => scopesOverlap(leftScope, rightScope)))
}

function parseTasks(markdown: string, tasksPath = "tasks.md"): SwarmPlan {
  const groups: TaskGroup[] = []
  const warnings: string[] = []
  let sharedHotspots: string[] = []
  let sharedHotspotsDeclared = false
  let current: TaskGroup | undefined

  for (const rawLine of markdown.split("\n")) {
    const line = rawLine.trim()
    const hotspots = line.match(HOTSPOTS_LINE)
    if (hotspots) {
      if (sharedHotspotsDeclared) throw new Error(`${tasksPath} has duplicate Shared hotspots declarations`)
      sharedHotspotsDeclared = true
      sharedHotspots = splitList(hotspots[1]).map(normalizeRepoPath)
      continue
    }
    const heading = line.match(GROUP_HEADING)
    if (heading) {
      if (groups.some((group) => group.id === heading[1])) throw new Error(`duplicate task group ${heading[1]}`)
      current = {
        id: heading[1],
        title: heading[2],
        files: [],
        depends_on: null,
        tasks: [],
        completed: false,
        touches_hotspot: false,
      }
      groups.push(current)
      continue
    }
    if (!current) continue
    const files = line.match(FILES_LINE)
    if (files) {
      current.files = splitList(files[1]).map(normalizeRepoPath)
      continue
    }
    const dependencies = line.match(DEPENDS_LINE)
    if (dependencies) {
      const parsed = splitList(dependencies[1])
      current.depends_on = parsed.every((dependency) => /^\d+$/.test(dependency)) ? parsed : null
      if (current.depends_on === null) warnings.push(`group ${current.id} has malformed Depends on; serialized`)
      continue
    }
    const task = line.match(TASK_LINE)
    if (task) current.tasks.push({ id: task[2], text: task[3], done: task[1].toLowerCase() === "x" })
  }

  if (groups.length === 0) throw new Error(`${tasksPath} has no numbered task groups`)
  const known = new Set(groups.map((group) => group.id))
  for (const [index, group] of groups.entries()) {
    if (group.tasks.length === 0) throw new Error(`task group ${group.id} has no checklist tasks`)
    if (group.files.length === 0) throw new Error(`task group ${group.id} has no Files scope`)
    if (group.depends_on === null) {
      warnings.push(`group ${group.id} has no valid Depends on; serialized in document order`)
    } else {
      const earlier = new Set(groups.slice(0, index).map((candidate) => candidate.id))
      const invalid = group.depends_on.filter((dependency) => !known.has(dependency) || !earlier.has(dependency))
      if (invalid.length > 0) {
        warnings.push(`group ${group.id} has invalid dependencies (${invalid.join(", ")}); serialized`)
        group.depends_on = null
      }
    }
    group.completed = group.tasks.every((task) => task.done)
    group.touches_hotspot = groupTouchesHotspot(group.files, sharedHotspots)
    if (group.touches_hotspot && !group.files.some((scope) => sharedHotspots.some((hotspot) => scopesOverlap(scope, hotspot)))) {
      warnings.push(`group ${group.id} touches a manifest, registry, fixture, or generated-code hotspot; serialized`)
    }
  }

  if (!sharedHotspotsDeclared) {
    warnings.push(`${tasksPath} has no Shared hotspots declaration; all groups serialized`)
  }
  const plan = {
    tasks_path: tasksPath,
    shared_hotspots: sharedHotspots,
    shared_hotspots_declared: sharedHotspotsDeclared,
    groups,
    waves: [],
    warnings,
  }
  plan.waves = buildWaves(plan, DEFAULT_MAX_WORKERS)
  return plan
}

function buildWaves(plan: Omit<SwarmPlan, "waves"> | SwarmPlan, maxWorkers: number): string[][] {
  const limit = Math.max(1, Math.min(MAX_WORKERS, maxWorkers))
  const pending = plan.groups.filter((group) => !group.completed)
  const completed = new Set(plan.groups.filter((group) => group.completed).map((group) => group.id))
  const waves: string[][] = []

  while (pending.length > 0) {
    const ready = pending.filter((group) => {
      if (group.depends_on !== null) return group.depends_on.every((dependency) => completed.has(dependency))
      const groupIndex = plan.groups.findIndex((candidate) => candidate.id === group.id)
      return plan.groups.slice(0, groupIndex).every((candidate) => completed.has(candidate.id))
    })
    if (ready.length === 0) throw new Error("task dependency graph contains a cycle or an unsatisfied dependency")

    const first = ready[0]
    const parallelEligible = (group: TaskGroup) =>
      plan.shared_hotspots_declared && group.depends_on !== null && !group.touches_hotspot
    const wave: TaskGroup[] = [first]
    if (parallelEligible(first)) {
      for (const candidate of ready.slice(1)) {
        if (wave.length >= limit) break
        if (!parallelEligible(candidate)) continue
        if (wave.some((selected) => groupsOverlap(selected, candidate))) continue
        wave.push(candidate)
      }
    }

    waves.push(wave.map((group) => group.id))
    for (const group of wave) {
      completed.add(group.id)
      pending.splice(pending.findIndex((candidate) => candidate.id === group.id), 1)
    }
  }
  return waves
}

function parseJsonArray(line: string, field: string): string[] {
  const pattern = new RegExp(`^${field}:\\s*(\\[.*\\])\\s*$`, "m")
  const match = line.match(pattern)
  if (!match) throw new Error(`receipt is missing ${field}`)
  const value = JSON.parse(match[1])
  if (!Array.isArray(value) || !value.every((item) => typeof item === "string")) {
    throw new Error(`receipt ${field} must be a string array`)
  }
  return value
}

function parseReceipt(text: string): Receipt {
  const wave = text.match(/^wave:\s*["']?(.+?)["']?\s*$/m)?.[1]
  const validation = text.match(/^validation:\s*["']?(.+?)["']?\s*$/m)?.[1]
  const commit = text.match(/^commit:\s*["']?([0-9a-f]{7,40}|none)["']?\s*$/m)?.[1]
  if (!wave || !validation || !commit) throw new Error("receipt is missing wave, validation, or commit")
  const assertions: Receipt["assertions"] = []
  for (const line of text.split("\n")) {
    const match = line.match(/^\s*-\s*["']?(\d+\.\d+)\s*->\s*([^:"']+):(\d+)["']?\s*$/)
    if (match) assertions.push({ task: match[1], file: normalizeRepoPath(match[2].trim()), line: Number(match[3]) })
  }
  return {
    wave,
    tasksDone: parseJsonArray(text, "tasks_done"),
    assertions,
    filesChanged: parseJsonArray(text, "files_changed").map(normalizeRepoPath),
    outOfScope: parseJsonArray(text, "out_of_scope"),
    validation,
    commit,
    blockers: parseJsonArray(text, "blockers"),
  }
}

function efficiencyScore(baselineTime: number, armTime: number, baselineCost: number, armCost: number): number {
  if ([baselineTime, armTime, baselineCost, armCost].some((value) => !Number.isFinite(value) || value <= 0)) return 0
  return Math.sqrt((baselineTime / armTime) * (baselineCost / armCost))
}

function emptyUsage(): Usage {
  return { cost: 0, cost_measurable: false, input_tokens: 0, output_tokens: 0, cache_tokens: 0 }
}

function addUsage(target: Usage, incoming: Usage): void {
  target.cost += incoming.cost
  target.cost_measurable = target.cost_measurable && incoming.cost_measurable
  target.input_tokens += incoming.input_tokens
  target.output_tokens += incoming.output_tokens
  target.cache_tokens += incoming.cache_tokens
}

function extractOpenCodeTextAndUsage(jsonl: string): { text: string; usage: Usage } {
  const text: string[] = []
  const usage = emptyUsage()
  for (const line of jsonl.split("\n")) {
    if (!line.trim()) continue
    try {
      const event = JSON.parse(line)
      if (event.part?.type === "text" && typeof event.part.text === "string") text.push(event.part.text)
      const tokens = event.part?.tokens
      if (tokens && typeof tokens === "object") {
        usage.input_tokens += Number(tokens.input ?? 0)
        usage.output_tokens += Number(tokens.output ?? 0)
        usage.cache_tokens += Number(tokens.cache?.read ?? 0) + Number(tokens.cache?.write ?? 0)
      }
      if (typeof event.part?.cost === "number") {
        usage.cost += event.part.cost
        usage.cost_measurable = true
      }
    } catch {
      // A malformed diagnostic line is ignored; receipt validation still fails closed.
    }
  }
  return { text: text.join("\n"), usage }
}

async function capture(command: string, args: string[], cwd: string): Promise<string> {
  try {
    const result = await execFileAsync(command, args, {
      cwd,
      encoding: "utf8",
      maxBuffer: MAX_CAPTURE_BYTES,
      env: { ...process.env, GIT_TERMINAL_PROMPT: "0" },
    })
    return String(result.stdout).trim()
  } catch (error) {
    const detail = error as Error & { stdout?: string; stderr?: string }
    throw new Error(`${command} ${args.join(" ")} failed: ${detail.stderr || detail.stdout || detail.message}`.trim())
  }
}

async function git(root: string, args: string[], cwd = root): Promise<string> {
  return capture("git", args, cwd)
}

async function gitBestEffort(root: string, args: string[], cwd = root): Promise<boolean> {
  try {
    await git(root, args, cwd)
    return true
  } catch {
    return false
  }
}

async function atomicWriteText(file: string, content: string): Promise<void> {
  await fs.mkdir(path.dirname(file), { recursive: true })
  const temporary = `${file}.${process.pid}.${randomBytes(3).toString("hex")}.tmp`
  await fs.writeFile(temporary, content, "utf8")
  await fs.rename(temporary, file)
}

async function atomicWriteJson(file: string, value: unknown): Promise<void> {
  await atomicWriteText(file, `${JSON.stringify(value, null, 2)}\n`)
}

async function isDirectory(directory: string): Promise<boolean> {
  try {
    return (await fs.stat(directory)).isDirectory()
  } catch {
    return false
  }
}

async function requireRegularFile(file: string, label: string): Promise<void> {
  try {
    if ((await fs.stat(file)).isFile()) return
  } catch {
    // Report one stable bundle-shape error below.
  }
  throw new Error(`full-depth bundle is missing ${label}: ${file}`)
}

async function validateFullDepthBundle(directory: string, expectedSource?: string): Promise<string> {
  const proposal = path.join(directory, "proposal.md")
  await requireRegularFile(proposal, "proposal.md")
  await requireRegularFile(path.join(directory, "design.md"), "design.md")
  await requireRegularFile(path.join(directory, "tasks.md"), "tasks.md")

  const specsDirectory = path.join(directory, "specs")
  let capabilities: import("node:fs").Dirent[]
  try {
    capabilities = await fs.readdir(specsDirectory, { withFileTypes: true })
  } catch {
    throw new Error(`full-depth bundle is missing specs/<capability>/spec.md: ${specsDirectory}`)
  }
  const specFiles = await Promise.all(
    capabilities
      .filter((entry) => entry.isDirectory())
      .map((entry) => path.join(specsDirectory, entry.name, "spec.md"))
      .map(async (file) => ((await fs.stat(file).catch(() => undefined))?.isFile() ? file : undefined)),
  )
  if (!specFiles.some(Boolean)) {
    throw new Error(`full-depth bundle is missing specs/<capability>/spec.md: ${specsDirectory}`)
  }

  const proposalText = await fs.readFile(proposal, "utf8")
  if (expectedSource !== undefined) {
    const firstLine = proposalText.split(/\r?\n/, 1)[0]
    const markerSource = firstLine.match(READY_MARKER)?.[1]
    if (markerSource !== expectedSource) {
      throw new Error(`external bundle must start with: Status: ready-for-sdd | Source: ${expectedSource}`)
    }
  }
  return proposalText
}

function parseMarkdownTableRow(line: string): string[] | undefined {
  const trimmed = line.trim()
  if (!trimmed.startsWith("|") || !trimmed.endsWith("|")) return undefined
  return trimmed.slice(1, -1).split("|").map((cell) => cell.trim())
}

async function prepareRoadmapUpdate(
  root: string,
  proposalText: string,
  change: string,
): Promise<{ update?: RoadmapUpdate; warnings: string[] }> {
  const warnings: string[] = []
  const proposalLines = proposalText.split(/\r?\n/)
  const roadmapMatch = proposalLines[1]?.match(ROADMAP_MARKER)
  if (!roadmapMatch) {
    if (proposalLines[1]?.startsWith("Roadmap:")) warnings.push("bundle has a malformed Roadmap marker; adopted as a plain bundle")
    return { warnings }
  }

  const goal = roadmapMatch[1]
  const roadmapFile = path.join(root, ".ai", "roadmaps", `${goal}.md`)
  let roadmapText: string
  try {
    roadmapText = await fs.readFile(roadmapFile, "utf8")
  } catch {
    warnings.push(`roadmap ${goal} is missing; adopted as a plain bundle`)
    return { warnings }
  }
  if (/^Status:\s*abandoned\b/m.test(roadmapText)) {
    warnings.push(`roadmap ${goal} is abandoned; adopted as a plain bundle`)
    return { warnings }
  }
  if (!/^Status:\s*active\s*\|\s*Source:\s*[a-z0-9][a-z0-9-]{0,63}\s*$/m.test(roadmapText)) {
    warnings.push(`roadmap ${goal} is malformed; adopted as a plain bundle`)
    return { warnings }
  }

  const lines = roadmapText.split("\n")
  const headerIndex = lines.findIndex((line) => {
    const cells = parseMarkdownTableRow(line)
    return cells?.includes("#") && cells.includes("Slice") && cells.includes("Depends on") && cells.includes("Status") && cells.includes("Bundle")
  })
  if (headerIndex === -1) {
    warnings.push(`roadmap ${goal} has no valid slice table; adopted as a plain bundle`)
    return { warnings }
  }
  const header = parseMarkdownTableRow(lines[headerIndex]) ?? []
  const numberColumn = header.indexOf("#")
  const sliceColumn = header.indexOf("Slice")
  const dependencyColumn = header.indexOf("Depends on")
  const statusColumn = header.indexOf("Status")
  const bundleColumn = header.indexOf("Bundle")
  const rows = lines
    .map((line, index) => ({ cells: parseMarkdownTableRow(line), index }))
    .filter((row) => row.index > headerIndex + 1 && row.cells?.length === header.length)
  const matches = rows.filter((row) => row.cells?.[sliceColumn] === change)
  if (matches.length !== 1) {
    warnings.push(`roadmap ${goal} does not contain exactly one slice named ${change}; adopted as a plain bundle`)
    return { warnings }
  }

  const target = matches[0]
  const targetCells = target.cells ?? []
  const statusByNumber = new Map(rows.map((row) => [row.cells?.[numberColumn], row.cells?.[statusColumn]]))
  const dependencies = splitList(targetCells[dependencyColumn] ?? "").filter((dependency) => dependency !== "—" && dependency !== "-")
  const incomplete = dependencies.filter((dependency) => statusByNumber.get(dependency) !== "done")
  if (incomplete.length > 0) {
    throw new Error(`roadmap slice ${change} depends on incomplete slices: ${incomplete.join(", ")}`)
  }

  targetCells[statusColumn] = "adopted"
  targetCells[bundleColumn] = `.ai/orchestrator/changes/${change}/`
  lines[target.index] = `| ${targetCells.join(" | ")} |`
  return { update: { file: roadmapFile, content: lines.join("\n") }, warnings }
}

async function ensureAiIgnored(root: string): Promise<void> {
  const ignored = await gitBestEffort(root, ["check-ignore", "--quiet", ".ai/"])
  if (!ignored) {
    throw new Error("sdd_swarm requires .ai/ to be ignored; add '.ai/' to .gitignore or .git/info/exclude")
  }
}

async function externalBundleCandidates(root: string, change: string): Promise<Array<{ directory: string; source: string }>> {
  const aiDirectory = path.join(root, ".ai")
  const entries = await fs.readdir(aiDirectory, { withFileTypes: true }).catch(() => [])
  const candidates: Array<{ directory: string; source: string }> = []
  for (const entry of entries) {
    if (!entry.isDirectory() || entry.name === "orchestrator") continue
    const directory = path.join(aiDirectory, entry.name, "changes", change)
    if (await isDirectory(directory)) candidates.push({ directory, source: entry.name })
  }
  return candidates
}

async function resolveOrAdoptBundle(root: string, change: string): Promise<BundleResolution> {
  await ensureAiIgnored(root)
  const destination = path.join(root, ".ai", "orchestrator", "changes", change)
  if (existsSync(destination)) {
    if (!(await isDirectory(destination))) throw new Error(`change bundle destination is not a directory: ${destination}`)
    await validateFullDepthBundle(destination)
    return { directory: destination, warnings: [] }
  }

  const candidates = await externalBundleCandidates(root, change)
  if (candidates.length === 0) {
    throw new Error(`no orchestrator or ready-for-sdd bundle found for change ${change}`)
  }
  if (candidates.length > 1) {
    const relative = candidates.map((candidate) => path.relative(root, candidate.directory)).join(", ")
    throw new Error(`ambiguous ready-for-sdd bundles for change ${change}: ${relative}`)
  }

  const candidate = candidates[0]
  const proposalText = await validateFullDepthBundle(candidate.directory, candidate.source)
  const roadmap = await prepareRoadmapUpdate(root, proposalText, change)
  await fs.mkdir(path.dirname(destination), { recursive: true })
  if (existsSync(destination)) throw new Error(`change bundle destination appeared during adoption: ${destination}`)
  await fs.rename(candidate.directory, destination)
  try {
    if (roadmap.update) await atomicWriteText(roadmap.update.file, roadmap.update.content)
  } catch (error) {
    const rolledBack = await fs.rename(destination, candidate.directory).then(() => true).catch(() => false)
    throw new Error(
      `could not update roadmap after adopting ${change}${rolledBack ? "; adoption rolled back" : "; manual recovery required"}: ${error instanceof Error ? error.message : String(error)}`,
    )
  }

  return {
    directory: destination,
    warnings: [
      `adopted ready-for-sdd bundle from ${path.relative(root, candidate.directory)}`,
      ...roadmap.warnings,
    ],
  }
}

async function readState(file: string): Promise<RunState> {
  return JSON.parse(await fs.readFile(file, "utf8")) as RunState
}

async function persistState(file: string, state: RunState): Promise<void> {
  state.updated_at = nowIso()
  await atomicWriteJson(file, state)
  const event = {
    schema_version: SCHEMA_VERSION,
    at: state.updated_at,
    type: "state",
    run_id: state.run_id,
    status: state.status,
    current_wave: state.current_wave,
    max_parallel: state.max_parallel,
    controller_pid: state.controller_pid,
    workers: Object.fromEntries(
      Object.entries(state.workers).map(([groupId, worker]) => [groupId, {
        status: worker.status,
        attempts: worker.attempts,
        pid: worker.pid,
        commit: worker.commit,
        error: worker.error,
      }]),
    ),
    error: state.error,
  }
  await fs.appendFile(path.join(path.dirname(file), "events.jsonl"), `${JSON.stringify(event)}\n`, "utf8")
}

function stateFile(root: string, runId: string): string {
  if (!/^[a-z0-9-]+$/.test(runId)) throw new Error("invalid run_id")
  return path.join(root, ".ai", "sdd-swarm", runId, "run.json")
}

function projectRoot(input: { worktree?: string; directory: string }): string {
  const worktree = input.worktree ?? ""
  if (!worktree || worktree === path.parse(worktree).root) return input.directory
  return worktree
}

function validateMaxWorkers(value: number): void {
  if (!Number.isInteger(value) || value < 1 || value > MAX_WORKERS) {
    throw new Error(`max_workers must be an integer between 1 and ${MAX_WORKERS}`)
  }
}

function validateWorkerTimeout(value: number): void {
  if (!Number.isInteger(value) || value < 1) {
    throw new Error("worker_timeout_seconds must be a positive integer")
  }
}

async function loadToolHelper(input: { directory: string }): Promise<typeof import("@opencode-ai/plugin").tool> {
  try {
    return (await import("@opencode-ai/plugin")).tool
  } catch {
    // OpenCode installs repository plugins as symlinks. Node and Bun resolve the
    // module to its real repository path, so a bare import cannot see the
    // dependency installed beside the symlink. Resolve from each supported
    // OpenCode config root explicitly instead of silently disabling the tool.
  }
  const configHome = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config")
  const configDirectories = [
    path.join(input.directory, ".opencode"),
    process.env.OPENCODE_CONFIG_DIR,
    path.join(configHome, "opencode"),
  ].filter((candidate): candidate is string => Boolean(candidate))
  for (const directory of configDirectories) {
    try {
      const entrypoint = path.join(directory, "node_modules", "@opencode-ai", "plugin", "dist", "index.js")
      if (!existsSync(entrypoint)) continue
      return (await import(pathToFileURL(entrypoint).href)).tool
    } catch {
      // Try the next supported config root.
    }
  }
  throw new Error("cannot resolve @opencode-ai/plugin from the project or user OpenCode config")
}

function validateArgv(value: unknown, field: string): string[] {
  if (!Array.isArray(value) || value.length === 0 || !value.every((item) => typeof item === "string" && item.length > 0)) {
    throw new Error(`${field} must be a non-empty string array`)
  }
  if (value.some((item) => item.includes("\0") || item.includes("\n"))) throw new Error(`${field} contains an unsafe argument`)
  return value
}

async function loadConfig(root: string): Promise<SwarmConfig> {
  const file = path.join(root, ".sdd-swarm.json")
  if (!existsSync(file)) {
    if (!existsSync(path.join(root, "pom.xml"))) throw new Error("missing .sdd-swarm.json and no Maven fallback is available")
    return {
      schema_version: SCHEMA_VERSION,
      scoped_validation: {},
      full_validation: ["mvn", "-B", "test"],
    }
  }
  const parsed = JSON.parse(await fs.readFile(file, "utf8")) as Record<string, unknown>
  if (parsed.schema_version !== SCHEMA_VERSION) throw new Error(`unsupported .sdd-swarm.json schema_version: ${parsed.schema_version}`)
  const scoped: Record<string, string[]> = {}
  if (parsed.scoped_validation !== undefined) {
    if (!parsed.scoped_validation || typeof parsed.scoped_validation !== "object" || Array.isArray(parsed.scoped_validation)) {
      throw new Error("scoped_validation must be an object")
    }
    for (const [group, argv] of Object.entries(parsed.scoped_validation as Record<string, unknown>)) {
      scoped[group] = validateArgv(argv, `scoped_validation.${group}`)
    }
  }
  return {
    schema_version: SCHEMA_VERSION,
    scoped_validation: scoped,
    full_validation: validateArgv(parsed.full_validation, "full_validation"),
    ...(parsed.final_validation === undefined ? {} : { final_validation: validateArgv(parsed.final_validation, "final_validation") }),
    ...(parsed.mock_worker === undefined ? {} : { mock_worker: validateArgv(parsed.mock_worker, "mock_worker") }),
  }
}

function replaceCommandPlaceholders(argv: string[], values: Record<string, string>): string[] {
  return argv.map((argument) => argument.replace(/\{([a-z_]+)\}/g, (placeholder, key) => values[key] ?? placeholder))
}

function terminateProcessGroup(pid: number): void {
  if (!Number.isInteger(pid) || pid <= 1) return
  const target = process.platform === "win32" ? pid : -pid
  try {
    process.kill(target, "SIGTERM")
  } catch {
    return
  }
  setTimeout(() => {
    try {
      process.kill(target, "SIGKILL")
    } catch {
      // The process exited during the grace period.
    }
  }, PROCESS_KILL_GRACE_MS).unref()
}

async function runProcess(options: {
  argv: string[]
  cwd: string
  stdout: string
  stderr: string
  timeoutSeconds: number
  env?: NodeJS.ProcessEnv
  onSpawn?: (pid: number) => Promise<void> | void
}): Promise<ProcessResult> {
  await fs.mkdir(path.dirname(options.stdout), { recursive: true })
  const stdoutFd = openSync(options.stdout, "w")
  const stderrFd = openSync(options.stderr, "w")
  const started = Date.now()
  let timedOut = false
  try {
    return await new Promise<ProcessResult>((resolve, reject) => {
      const child = spawn(options.argv[0], options.argv.slice(1), {
        cwd: options.cwd,
        detached: process.platform !== "win32",
        env: { ...process.env, GIT_TERMINAL_PROMPT: "0", ...options.env },
        stdio: ["ignore", stdoutFd, stderrFd],
      })
      void options.onSpawn?.(child.pid ?? 0)
      const timer = setTimeout(() => {
        timedOut = true
        if (child.pid) terminateProcessGroup(child.pid)
      }, options.timeoutSeconds * 1_000)
      child.once("error", (error) => {
        clearTimeout(timer)
        reject(error)
      })
      child.once("close", (exitCode) => {
        clearTimeout(timer)
        resolve({ exitCode, timedOut, durationMs: Date.now() - started })
      })
    })
  } finally {
    closeSync(stdoutFd)
    closeSync(stderrFd)
  }
}

async function runValidation(argv: string[], cwd: string, logDir: string, timeoutSeconds: number): Promise<ProcessResult> {
  const javaTemp = path.join(logDir, "java-tmp")
  await fs.mkdir(javaTemp, { recursive: true })
  const inheritedMavenOptions = process.env.MAVEN_OPTS ? `${process.env.MAVEN_OPTS} ` : ""
  return runProcess({
    argv,
    cwd,
    stdout: path.join(logDir, "validation.stdout.log"),
    stderr: path.join(logDir, "validation.stderr.log"),
    timeoutSeconds,
    env: { MAVEN_OPTS: `${inheritedMavenOptions}-Djansi.tmpdir=${javaTemp} -Djava.io.tmpdir=${javaTemp}` },
  })
}

async function ensureWorktree(root: string, destination: string, branch: string, startPoint: string, reason: string): Promise<void> {
  await fs.mkdir(path.dirname(destination), { recursive: true })
  if (!existsSync(path.join(destination, ".git"))) {
    const branchExists = await gitBestEffort(root, ["show-ref", "--verify", `refs/heads/${branch}`])
    await git(root, branchExists
      ? ["worktree", "add", destination, branch]
      : ["worktree", "add", "-b", branch, destination, startPoint])
  }
  await gitBestEffort(root, ["worktree", "lock", "--reason", reason, destination])
}

async function copyChangeBundle(root: string, worktree: string, change: string): Promise<void> {
  const relative = path.join(".ai", "orchestrator", "changes", change)
  const source = path.join(root, relative)
  const destination = path.join(worktree, relative)
  if (!existsSync(source)) throw new Error(`missing change bundle: ${source}`)
  await fs.rm(destination, { recursive: true, force: true })
  await fs.mkdir(path.dirname(destination), { recursive: true })
  await fs.cp(source, destination, { recursive: true })
}

function workerPrompt(state: RunState, group: TaskGroup, baseSha: string, validation: string[]): string {
  const taskLines = group.tasks.filter((task) => !task.done).map((task) => `- ${task.id}: ${task.text}`).join("\n")
  return [
    `Implement exactly SDD swarm group ${group.id} (${group.title}) for change ${state.change}.`,
    `Baseline SHA: ${baseSha}`,
    `Change bundle: .ai/orchestrator/changes/${state.change}/`,
    `Allowed files: ${group.files.join(", ")}`,
    "Assigned tasks:",
    taskLines,
    `Validation argv: ${JSON.stringify(validation)}`,
    "Rules: read the change bundle first; modify only the allowed files; never push, merge, edit .ai, call Task, or call sdd_swarm.",
    "Run the validation, then create exactly one commit with git -c commit.gpgSign=false commit.",
    "Return only the sdd-swarm-worker Output receipt; every assertion must point inside the allowed files.",
  ].join("\n")
}

async function workerCommand(state: RunState, group: TaskGroup, worktree: string, baseSha: string, attempt: number): Promise<string[]> {
  if (state.execution === "mock") {
    if (!state.config.mock_worker) throw new Error("mock execution requires mock_worker in .sdd-swarm.json")
    return replaceCommandPlaceholders(state.config.mock_worker, {
      attempt: String(attempt),
      base: baseSha,
      group: group.id,
      worktree,
    })
  }
  const binary = process.env[OPENCODE_BIN_ENV] || "opencode"
  const validation = state.config.scoped_validation[group.id] ?? state.config.full_validation
  const args = [
    binary,
    "run",
    "--dir",
    worktree,
    "--agent",
    "sdd-swarm-worker",
    "--format",
    "json",
    "--auto",
    "--title",
    `sdd-swarm ${state.run_id} group ${group.id}`,
  ]
  const model = process.env[WORKER_MODEL_ENV]
  if (model) args.push("--model", model)
  args.push(workerPrompt(state, group, baseSha, validation))
  return args
}

async function validateWorkerResult(options: {
  state: RunState
  group: TaskGroup
  worker: WorkerState
  baseSha: string
  outputText: string
  logDir: string
}): Promise<void> {
  const { state, group, worker, baseSha, outputText, logDir } = options
  const receipt = parseReceipt(outputText)
  const expectedTasks = group.tasks.filter((task) => !task.done).map((task) => task.id).sort()
  if (receipt.wave !== group.id) throw new Error(`receipt wave ${receipt.wave} does not match group ${group.id}`)
  if (JSON.stringify([...receipt.tasksDone].sort()) !== JSON.stringify(expectedTasks)) {
    throw new Error(`receipt tasks_done does not match group ${group.id}`)
  }
  if (receipt.blockers.length > 0) throw new Error(`worker blockers: ${receipt.blockers.join("; ")}`)
  if (receipt.outOfScope.length > 0) throw new Error(`worker reported out-of-scope changes: ${receipt.outOfScope.join(", ")}`)
  if (!receipt.validation.startsWith("pass")) throw new Error(`worker validation was not successful: ${receipt.validation}`)
  const assertedTasks = receipt.assertions.map((assertion) => assertion.task).sort()
  if (JSON.stringify(assertedTasks) !== JSON.stringify(expectedTasks)) {
    throw new Error(`receipt assertions do not match group ${group.id}`)
  }
  for (const task of expectedTasks) {
    const assertion = receipt.assertions.find((candidate) => candidate.task === task)
    if (!assertion || !pathInScopes(assertion.file, group.files)) throw new Error(`missing in-scope assertion for task ${task}`)
  }

  const count = await git(state.root, ["rev-list", "--count", `${baseSha}..HEAD`], worker.worktree)
  if (count !== "1") throw new Error(`worker must create exactly one commit; found ${count}`)
  const commit = await git(state.root, ["rev-parse", "HEAD"], worker.worktree)
  if (receipt.commit !== commit && !commit.startsWith(receipt.commit)) throw new Error("receipt commit does not match worker HEAD")
  const dirty = await git(state.root, ["status", "--porcelain"], worker.worktree)
  if (dirty) throw new Error(`worker worktree is dirty after commit: ${dirty.split("\n")[0]}`)
  const changed = (await git(state.root, ["diff", "--name-only", `${baseSha}..${commit}`], worker.worktree))
    .split("\n").map(normalizeRepoPath).filter(Boolean).sort()
  const outside = changed.filter((file) => !pathInScopes(file, group.files))
  if (outside.length > 0) throw new Error(`worker changed files outside scope: ${outside.join(", ")}`)
  for (const assertion of receipt.assertions) {
    if (!changed.includes(assertion.file)) throw new Error(`assertion file was not changed: ${assertion.file}`)
    const assertedFile = await fs.readFile(path.join(worker.worktree, assertion.file), "utf8")
    if (assertion.line < 1 || assertion.line > assertedFile.split("\n").length) {
      throw new Error(`assertion line is outside ${assertion.file}: ${assertion.line}`)
    }
  }
  if (JSON.stringify([...receipt.filesChanged].sort()) !== JSON.stringify(changed)) {
    throw new Error("receipt files_changed does not match the committed diff")
  }

  const validation = state.config.scoped_validation[group.id] ?? state.config.full_validation
  const validationResult = await runValidation(validation, worker.worktree, logDir, state.worker_timeout_seconds)
  if (validationResult.timedOut || validationResult.exitCode !== 0) throw new Error("controller scoped validation failed")
  worker.commit = commit
  worker.files_changed = changed
  worker.validation = "pass"
}

function isTechnicalExit(exitCode: number | null, timedOut: boolean): boolean {
  return timedOut || exitCode === null || (exitCode >= 70 && exitCode <= 79)
}

async function executeWorker(stateFilePath: string, state: RunState, group: TaskGroup, baseSha: string): Promise<WorkerState> {
  const worker = state.workers[group.id]
  worker.base_sha = baseSha
  const groupDir = path.join(path.dirname(stateFilePath), "workers", group.id)
  const javaTemp = path.join(groupDir, "java-tmp")
  await fs.mkdir(javaTemp, { recursive: true })
  await ensureWorktree(state.root, worker.worktree, worker.branch, baseSha, `${state.run_id} group ${group.id}`)
  await copyChangeBundle(state.root, worker.worktree, state.change)

  for (let attempt = 1; attempt <= TECHNICAL_RETRY_LIMIT + 1; attempt += 1) {
    if (attempt > 1) {
      await git(state.root, ["reset", "--hard", baseSha], worker.worktree)
      await git(state.root, ["clean", "-fdx"], worker.worktree)
      await copyChangeBundle(state.root, worker.worktree, state.change)
    }
    worker.attempts = attempt
    worker.status = "running"
    delete worker.error
    const stdout = path.join(groupDir, `attempt-${attempt}.stdout.log`)
    const stderr = path.join(groupDir, `attempt-${attempt}.stderr.log`)
    const command = await workerCommand(state, group, worker.worktree, baseSha, attempt)
    await persistState(stateFilePath, state)
    const result = await runProcess({
      argv: command,
      cwd: worker.worktree,
      stdout,
      stderr,
      timeoutSeconds: state.worker_timeout_seconds,
      env: {
        [WORKER_ENV]: "1",
        SDD_SWARM_ATTEMPT: String(attempt),
        SDD_SWARM_GROUP: group.id,
        GIT_AUTHOR_NAME: "sdd-swarm-worker",
        GIT_AUTHOR_EMAIL: "sdd-swarm-worker@example.invalid",
        GIT_COMMITTER_NAME: "sdd-swarm-worker",
        GIT_COMMITTER_EMAIL: "sdd-swarm-worker@example.invalid",
        MAVEN_OPTS: `${process.env.MAVEN_OPTS ? `${process.env.MAVEN_OPTS} ` : ""}-Djansi.tmpdir=${javaTemp} -Djava.io.tmpdir=${javaTemp}`,
      },
      onSpawn: async (pid) => {
        worker.pid = pid
        await persistState(stateFilePath, state)
      },
    })
    worker.duration_ms = (worker.duration_ms ?? 0) + result.durationMs
    delete worker.pid
    const raw = await fs.readFile(stdout, "utf8")
    const extracted = state.execution === "opencode" ? extractOpenCodeTextAndUsage(raw) : { text: raw, usage: emptyUsage() }
    addUsage(worker.usage, extracted.usage)
    if (result.timedOut) worker.status = "timed_out"
    if (result.exitCode !== 0 || result.timedOut) {
      if (attempt <= TECHNICAL_RETRY_LIMIT && isTechnicalExit(result.exitCode, result.timedOut)) continue
      worker.status = result.timedOut ? "timed_out" : "failed"
      worker.error = result.timedOut ? "worker timed out" : `worker exited ${result.exitCode}`
      await persistState(stateFilePath, state)
      return worker
    }
    try {
      await validateWorkerResult({ state, group, worker, baseSha, outputText: extracted.text, logDir: groupDir })
      worker.status = "passed"
      await persistState(stateFilePath, state)
      return worker
    } catch (error) {
      worker.status = "failed"
      worker.error = error instanceof Error ? error.message : String(error)
      await persistState(stateFilePath, state)
      return worker
    }
  }
  return worker
}

async function integrateWave(stateFilePath: string, state: RunState, wave: string[]): Promise<void> {
  for (const groupId of wave) {
    const worker = state.workers[groupId]
    if (!worker.commit) throw new Error(`group ${groupId} has no verified commit`)
    await cherryPickCommit(state.root, state.integration_worktree, worker.commit, `group ${groupId}`)
  }
  const waveDir = path.join(path.dirname(stateFilePath), "waves", String(state.current_wave + 1))
  const result = await runValidation(state.config.full_validation, state.integration_worktree, waveDir, state.worker_timeout_seconds)
  if (result.timedOut || result.exitCode !== 0) throw new Error(`full validation failed after wave ${state.current_wave + 1}`)
}

async function cherryPickCommit(root: string, integrationWorktree: string, commit: string, label = commit): Promise<void> {
  try {
    await git(root, ["-c", "commit.gpgSign=false", "cherry-pick", commit], integrationWorktree)
  } catch (error) {
    await gitBestEffort(root, ["cherry-pick", "--abort"], integrationWorktree)
    throw new Error(`cherry-pick conflict for ${label}: ${error instanceof Error ? error.message : String(error)}`)
  }
}

async function executeRun(stateFilePath: string): Promise<RunState> {
  const state = await readState(stateFilePath)
  if (TERMINAL_STATUSES.has(state.status)) return state
  const started = Date.now()
  state.status = "running"
  state.controller_pid = process.pid
  await persistState(stateFilePath, state)

  try {
    await ensureWorktree(
      state.root,
      state.integration_worktree,
      state.integration_branch,
      state.baseline_sha,
      `${state.run_id} integration`,
    )
    for (let waveIndex = state.current_wave; waveIndex < state.plan.waves.length; waveIndex += 1) {
      state.current_wave = waveIndex
      const wave = state.plan.waves[waveIndex]
      state.max_parallel = Math.max(state.max_parallel, wave.length)
      const baseSha = await git(state.root, ["rev-parse", "HEAD"], state.integration_worktree)
      const workersStarted = Date.now()
      const workers = await Promise.all(wave.map((groupId) => {
        const group = state.plan.groups.find((candidate) => candidate.id === groupId)
        if (!group) throw new Error(`unknown group ${groupId}`)
        return executeWorker(stateFilePath, state, group, baseSha)
      }))
      state.metrics.worker_wall_time_ms += Date.now() - workersStarted
      const failed = workers.find((worker) => worker.status !== "passed")
      if (failed) throw new Error(`group ${failed.group_id} failed: ${failed.error ?? failed.status}`)
      const integrationStarted = Date.now()
      await integrateWave(stateFilePath, state, wave)
      state.metrics.integration_wall_time_ms += Date.now() - integrationStarted
      state.current_wave = waveIndex + 1
      await persistState(stateFilePath, state)
    }
    if (state.config.final_validation) {
      const finalStarted = Date.now()
      const finalResult = await runValidation(
        state.config.final_validation,
        state.integration_worktree,
        path.join(path.dirname(stateFilePath), "final"),
        state.worker_timeout_seconds,
      )
      state.metrics.integration_wall_time_ms += Date.now() - finalStarted
      if (finalResult.timedOut || finalResult.exitCode !== 0) throw new Error("final golden validation failed")
    }
    state.status = "completed"
  } catch (error) {
    state.status = "blocked"
    state.error = error instanceof Error ? error.message : String(error)
  } finally {
    for (const worker of Object.values(state.workers)) addUsage(state.metrics, worker.usage)
    state.metrics.wall_time_ms = Date.now() - started
    delete state.controller_pid
    await persistState(stateFilePath, state)
  }
  return state
}

function makeRunId(): string {
  const timestamp = nowIso().replace(/[-:.]/g, "").replace("Z", "").toLowerCase()
  return `${timestamp}-${randomBytes(3).toString("hex")}`
}

function runBranchPrefix(runId: string): string {
  return `${BRANCH_NAMESPACE}/${runId}`
}

async function prepareRun(options: {
  root: string
  change: string
  execution: ExecutionMode
  maxWorkers: number
  workerTimeoutSeconds: number
}): Promise<{ state: RunState; file: string }> {
  if (!CHANGE_NAME.test(options.change)) throw new Error("change must be a lowercase kebab-case name")
  validateMaxWorkers(options.maxWorkers)
  validateWorkerTimeout(options.workerTimeoutSeconds)
  const root = await git(options.root, ["rev-parse", "--show-toplevel"], options.root)
  await ensureAiIgnored(root)
  const dirty = await git(root, ["status", "--porcelain"])
  if (dirty) throw new Error("sdd_swarm requires a clean Git working tree")
  const bundle = await resolveOrAdoptBundle(root, options.change)
  const tasksPath = path.join(bundle.directory, "tasks.md")
  const markdown = await fs.readFile(tasksPath, "utf8")
  const parsed = parseTasks(markdown, path.relative(root, tasksPath))
  parsed.warnings.unshift(...bundle.warnings)
  parsed.waves = buildWaves(parsed, options.maxWorkers)
  const config = await loadConfig(root)
  const baseline = await git(root, ["rev-parse", "HEAD"])
  const runId = makeRunId()
  const repoId = `${path.basename(root)}-${createHash("sha256").update(root).digest("hex").slice(0, 10)}`
  const dataHome = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share")
  const worktreeBase = process.env[WORKTREE_ROOT_ENV] || path.join(dataHome, "opencode", "sdd-swarm")
  const runWorktrees = path.join(worktreeBase, repoId, runId)
  const branchPrefix = runBranchPrefix(runId)
  const workers: Record<string, WorkerState> = {}
  for (const group of parsed.groups.filter((candidate) => !candidate.completed)) {
    workers[group.id] = {
      group_id: group.id,
      branch: `${branchPrefix}/task-${group.id}`,
      worktree: path.join(runWorktrees, `task-${group.id}`),
      status: "pending",
      attempts: 0,
      usage: { ...emptyUsage(), cost_measurable: true },
    }
  }
  const state: RunState = {
    schema_version: SCHEMA_VERSION,
    run_id: runId,
    root,
    change: options.change,
    execution: options.execution,
    status: "queued",
    created_at: nowIso(),
    updated_at: nowIso(),
    baseline_sha: baseline,
    max_workers: options.maxWorkers,
    worker_timeout_seconds: options.workerTimeoutSeconds,
    integration_branch: `${branchPrefix}/integration`,
    integration_worktree: path.join(runWorktrees, "integration"),
    plan: parsed,
    config,
    workers,
    current_wave: 0,
    max_parallel: 0,
    metrics: {
      ...emptyUsage(),
      cost_measurable: true,
      wall_time_ms: 0,
      worker_wall_time_ms: 0,
      integration_wall_time_ms: 0,
    },
  }
  const file = stateFile(root, runId)
  await persistState(file, state)
  return { state, file }
}

async function startBackgroundRun(prepared: { state: RunState; file: string }): Promise<RunState> {
  const controllerLog = path.join(path.dirname(prepared.file), "controller.log")
  const startSignal = path.join(path.dirname(prepared.file), ".controller-start")
  const logFd = openSync(controllerLog, "a")
  try {
    await fs.rm(startSignal, { force: true })
    const nodeBinary = process.env[NODE_BIN_ENV] || "node"
    const child = spawn(nodeBinary, [MODULE_PATH, "__run", prepared.file, startSignal], {
      detached: process.platform !== "win32",
      env: process.env,
      stdio: ["ignore", logFd, logFd],
    })
    if (!child.pid) throw new Error("could not start sdd-swarm controller")
    prepared.state.controller_pid = child.pid
    await persistState(prepared.file, prepared.state)
    await fs.writeFile(startSignal, `${child.pid}\n`, "utf8")
    child.unref()
    return prepared.state
  } finally {
    closeSync(logFd)
  }
}

async function waitForStartSignal(file: string): Promise<void> {
  const deadline = Date.now() + 10_000
  while (!existsSync(file)) {
    if (Date.now() >= deadline) throw new Error("controller start signal timed out")
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
}

function pidAlive(pid: number | undefined): boolean {
  if (!pid || pid <= 1) return false
  try {
    process.kill(pid, 0)
    return true
  } catch {
    return false
  }
}

async function statusRun(root: string, runId: string): Promise<RunState> {
  const file = stateFile(root, runId)
  const state = await readState(file)
  if ((state.status === "queued" || state.status === "running") && !pidAlive(state.controller_pid)) {
    for (const worker of Object.values(state.workers)) {
      if (worker.pid && pidAlive(worker.pid)) terminateProcessGroup(worker.pid)
      if (worker.status === "running") {
        worker.status = "failed"
        worker.error = "worker stopped after the controller process disappeared"
      }
      delete worker.pid
    }
    state.status = "interrupted"
    state.error = "controller process is no longer running; inspect the ledger before restarting"
    delete state.controller_pid
    await persistState(file, state)
  }
  return state
}

async function abortRun(root: string, runId: string): Promise<RunState> {
  const file = stateFile(root, runId)
  const state = await readState(file)
  if (TERMINAL_STATUSES.has(state.status)) return state
  for (const worker of Object.values(state.workers)) if (worker.pid) terminateProcessGroup(worker.pid)
  if (state.controller_pid) terminateProcessGroup(state.controller_pid)
  state.status = "aborted"
  state.error = "aborted by user"
  delete state.controller_pid
  await persistState(file, state)
  return state
}

async function cleanupRun(root: string, runId: string): Promise<RunState> {
  const file = stateFile(root, runId)
  const state = await statusRun(root, runId)
  if (state.status === "queued" || state.status === "running") throw new Error("abort the run before cleanup")
  const paths = [...Object.values(state.workers).map((worker) => worker.worktree), state.integration_worktree]
  for (const worktree of paths) {
    if (!existsSync(worktree)) continue
    const dirty = await git(root, ["status", "--porcelain"], worktree)
    if (dirty) throw new Error(`refusing to remove dirty worktree: ${worktree}`)
  }
  for (const worktree of paths) {
    if (!existsSync(worktree)) continue
    await gitBestEffort(root, ["worktree", "unlock", worktree])
    await git(root, ["worktree", "remove", worktree])
  }
  state.cleaned = true
  await persistState(file, state)
  return state
}

async function planChange(root: string, change: string, maxWorkers = DEFAULT_MAX_WORKERS): Promise<SwarmPlan> {
  if (!CHANGE_NAME.test(change)) throw new Error("change must be a lowercase kebab-case name")
  validateMaxWorkers(maxWorkers)
  const repositoryRoot = await git(root, ["rev-parse", "--show-toplevel"], root)
  const bundle = await resolveOrAdoptBundle(repositoryRoot, change)
  const tasksPath = path.join(bundle.directory, "tasks.md")
  const plan = parseTasks(await fs.readFile(tasksPath, "utf8"), path.relative(repositoryRoot, tasksPath))
  plan.warnings.unshift(...bundle.warnings)
  plan.waves = buildWaves(plan, maxWorkers)
  return plan
}

function assertSupervisorAgent(agent: string): void {
  if (agent !== SUPERVISOR_AGENT) {
    throw new Error(`sdd_swarm is restricted to the ${SUPERVISOR_AGENT} supervisor; invoked by ${agent || "unknown"}`)
  }
}

export const sddSwarmContracts = {
  DEFAULT_MAX_WORKERS,
  MAX_WORKERS,
  buildWaves,
  cherryPickCommit,
  efficiencyScore,
  extractOpenCodeTextAndUsage,
  assertSupervisorAgent,
  parseReceipt,
  parseTasks,
  pathInScopes,
  runBranchPrefix,
  scopesOverlap,
}

export const SddSwarmPlugin: Plugin = async (input) => {
  if (process.env[WORKER_ENV] === "1") return {}
  const tool = await loadToolHelper(input)
  const root = projectRoot(input)
  const schema = tool.schema
  return {
    tool: {
      sdd_swarm: tool({
        description:
          "Deterministic SDD worktree swarm controller. Plan dependency-safe waves; run up to four isolated OpenCode workers; inspect, abort, or safely clean a durable run. It never pushes or opens PRs.",
        args: {
          action: schema.enum(["plan", "run", "status", "abort", "cleanup"]),
          change: schema.string().optional().describe("Lowercase kebab-case SDD change name; required for plan and run"),
          run_id: schema.string().optional().describe("Durable run id; required for status, abort, and cleanup"),
          execution: schema.enum(["mock", "opencode"]).optional().describe("Worker adapter; defaults to opencode"),
          max_workers: schema.number().int().min(1).max(MAX_WORKERS).optional().describe("Concurrency cap; defaults to 4"),
          worker_timeout_seconds: schema.number().int().min(1).optional().describe("Per-worker timeout; defaults to 1200"),
        },
        async execute(args, context) {
          assertSupervisorAgent(context.agent)
          const maxWorkers = args.max_workers ?? DEFAULT_MAX_WORKERS
          if (args.action === "plan") {
            if (!args.change) throw new Error("change is required for plan")
            return JSON.stringify(await planChange(root, args.change, maxWorkers), null, 2)
          }
          if (args.action === "run") {
            if (!args.change) throw new Error("change is required for run")
            const prepared = await prepareRun({
              root,
              change: args.change,
              execution: args.execution ?? "opencode",
              maxWorkers,
              workerTimeoutSeconds: args.worker_timeout_seconds ?? DEFAULT_WORKER_TIMEOUT_SECONDS,
            })
            return JSON.stringify(await startBackgroundRun(prepared), null, 2)
          }
          if (!args.run_id) throw new Error(`run_id is required for ${args.action}`)
          if (args.action === "status") return JSON.stringify(await statusRun(root, args.run_id), null, 2)
          if (args.action === "abort") return JSON.stringify(await abortRun(root, args.run_id), null, 2)
          return JSON.stringify(await cleanupRun(root, args.run_id), null, 2)
        },
      }),
    },
  }
}

function cliValue(name: string): string | undefined {
  const index = process.argv.indexOf(name)
  return index === -1 ? undefined : process.argv[index + 1]
}

async function runCli(): Promise<void> {
  const action = process.argv[2]
  if (!action) return
  if (action === "__run") {
    if (process.argv[4]) await waitForStartSignal(process.argv[4])
    await executeRun(process.argv[3])
    return
  }
  const root = path.resolve(cliValue("--root") ?? process.cwd())
  if (action === "plan") {
    const change = cliValue("--change")
    if (!change) throw new Error("--change is required")
    console.log(JSON.stringify(await planChange(root, change, Number(cliValue("--max-workers") ?? DEFAULT_MAX_WORKERS)), null, 2))
    return
  }
  if (action === "run") {
    const change = cliValue("--change")
    if (!change) throw new Error("--change is required")
    const execution = (cliValue("--execution") ?? "mock") as ExecutionMode
    if (execution !== "mock" && execution !== "opencode") throw new Error("--execution must be mock or opencode")
    const prepared = await prepareRun({
      root,
      change,
      execution,
      maxWorkers: Number(cliValue("--max-workers") ?? DEFAULT_MAX_WORKERS),
      workerTimeoutSeconds: Number(cliValue("--timeout") ?? DEFAULT_WORKER_TIMEOUT_SECONDS),
    })
    console.log(JSON.stringify(await startBackgroundRun(prepared), null, 2))
    return
  }
  if (action === "run-sync") {
    const change = cliValue("--change")
    if (!change) throw new Error("--change is required")
    const execution = (cliValue("--execution") ?? "mock") as ExecutionMode
    if (execution !== "mock" && execution !== "opencode") throw new Error("--execution must be mock or opencode")
    const prepared = await prepareRun({
      root,
      change,
      execution,
      maxWorkers: Number(cliValue("--max-workers") ?? DEFAULT_MAX_WORKERS),
      workerTimeoutSeconds: Number(cliValue("--timeout") ?? DEFAULT_WORKER_TIMEOUT_SECONDS),
    })
    console.log(JSON.stringify(await executeRun(prepared.file), null, 2))
    return
  }
  const runId = cliValue("--run-id")
  if (!runId) throw new Error("--run-id is required")
  if (action === "status") console.log(JSON.stringify(await statusRun(root, runId), null, 2))
  else if (action === "abort") console.log(JSON.stringify(await abortRun(root, runId), null, 2))
  else if (action === "cleanup") console.log(JSON.stringify(await cleanupRun(root, runId), null, 2))
  else throw new Error(`unknown action: ${action}`)
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(MODULE_PATH)) {
  void runCli().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error))
    process.exitCode = 1
  })
}

export default {
  id: PLUGIN_ID,
  server: SddSwarmPlugin,
}
