import { spawn } from "node:child_process"
import fs from "node:fs/promises"
import path from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

const PLUGIN_ID = "codegraph-init"
const LOG_PREFIX = `[${PLUGIN_ID}]`
const CODEGRAPH_BINARY = "codegraph"
const CODEGRAPH_PACKAGE = "@colbymchenry/codegraph@1.4.1"
const GIT_BINARY = "git"
const AUTOINIT_ENV = "OPENCODE_CODEGRAPH_AUTOINIT"
const CODEGRAPH_DIR_ENV = "CODEGRAPH_DIR"
const AUTOINIT_OPT_OUT = "0"
const STATUS_ARGS = ["status"] as const
const INIT_ARGS = ["init"] as const
const INDEX_ARGS = ["index"] as const
const JSON_FLAG = "--json"
const FORCE_FLAG = "--force"
const GIT_EXCLUDE_ARGS = ["rev-parse", "--is-inside-work-tree", "--git-path", "info/exclude"] as const
const GIT_WORK_TREE_RESULT = "true"
const NOT_GIT_REPOSITORY_ERROR = "not a git repository"
const DEFAULT_INDEX_DIR = ".codegraph"
const IGNORED_DIRECTORY_NAMES = new Set(["node_modules"])
const NESTED_REPO_MAX_DEPTH = 2
const MAX_SUMMARY_FAILURES = 3
const MAX_ERROR_OUTPUT_LENGTH = 1_000
const INFO_DURATION_MS = 5_000
const WARNING_DURATION_MS = 8_000
const ERROR_DURATION_MS = 8_000

const INDEX_STATES = {
  COMPLETE: "complete",
  FAILED: "failed",
  INDEXING: "indexing",
  PARTIAL: "partial",
} as const

const TOAST_VARIANTS = {
  ERROR: "error",
  INFO: "info",
  SUCCESS: "success",
  WARNING: "warning",
} as const

type IndexState = (typeof INDEX_STATES)[keyof typeof INDEX_STATES] | null
type ToastVariant = (typeof TOAST_VARIANTS)[keyof typeof TOAST_VARIANTS]

type CodeGraphStatus = {
  initialized: boolean
  indexPath?: string
  fileCount?: number
  index?: {
    state?: IndexState
  }
}

type CommandResult = {
  exitCode: number | null
  stdout: string
  stderr: string
  error?: Error
}

type ToastClient = {
  tui: {
    showToast(options: {
      body: {
        message: string
        variant: ToastVariant
        duration: number
      }
      query: {
        directory: string
      }
    }): Promise<unknown>
  }
}

type ToastInput = {
  client: ToastClient
  directory: string
}

const startMessage = (repo: string) =>
  `CodeGraph is indexing ${repo} in the background. You can keep working.`

const successMessage = (repo: string, fileCount: number, elapsed: string) =>
  `CodeGraph index for ${repo} is ready: ${fileCount} files in ${elapsed}.`

const missingBinaryMessage = () =>
  `CodeGraph CLI was not found. Run: npm install -g ${CODEGRAPH_PACKAGE}`

const incompleteMessage = (repo: string, state: IndexState, command: string) => {
  const cause = state === INDEX_STATES.INDEXING ? "indexing appears abandoned" : `index state is ${state ?? "unknown"}`
  return `CodeGraph index for ${repo} is incomplete (${cause}). Run: ${command}`
}

const processFailureMessage = (repo: string, command: string) =>
  `CodeGraph indexing failed for ${repo}, but this session is still operational. Run: ${command}`

const repairStartMessage = (repo: string) =>
  `CodeGraph is repairing the ${repo} index in the background. You can keep working.`

const repositoriesLabel = (count: number) => `${count} ${count === 1 ? "repository" : "repositories"}`

const aggregateStartMessage = (count: number, rootName: string) =>
  `CodeGraph is indexing ${repositoriesLabel(count)} under ${rootName} in the background. You can keep working.`

const aggregateSuccessMessage = (count: number, rootName: string, elapsed: string) =>
  `CodeGraph indexed ${repositoriesLabel(count)} under ${rootName} in ${elapsed}.`

const aggregateFailureMessage = (okCount: number, total: number, rootName: string, failedNames: string[]) => {
  const shown = failedNames.slice(0, MAX_SUMMARY_FAILURES)
  const overflow = failedNames.length - shown.length
  const list = overflow > 0 ? `${shown.join(", ")}, +${overflow} more` : shown.join(", ")
  return `CodeGraph indexed ${okCount} of ${total} repositories under ${rootName}. Failed: ${list}. Run: ${CODEGRAPH_BINARY} status <repo> ${JSON_FLAG}`
}

function projectRoot(input: { worktree?: string; directory: string }) {
  const worktree = input.worktree ?? ""
  if (!worktree || worktree === path.parse(worktree).root) return input.directory
  return worktree
}

function repoName(root: string) {
  return path.basename(root) || root
}

function quoteForDisplay(value: string) {
  return `'${value.replaceAll("'", `'\\''`)}'`
}

function recoveryStatusCommand(root: string) {
  return `${CODEGRAPH_BINARY} status ${quoteForDisplay(root)}`
}

function recoveryIndexCommand(root: string) {
  return `${CODEGRAPH_BINARY} index ${quoteForDisplay(root)} ${FORCE_FLAG}`
}

function formatElapsed(elapsedMs: number) {
  return `${Math.max(0.1, elapsedMs / 1_000).toFixed(1)}s`
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

function appendErrorOutput(current: string, chunk: unknown) {
  if (current.length >= MAX_ERROR_OUTPUT_LENGTH) return current
  return `${current}${String(chunk)}`.slice(0, MAX_ERROR_OUTPUT_LENGTH)
}

function runCommand(
  binary: string,
  args: readonly string[],
  root: string,
  captureStdout = true,
): Promise<CommandResult> {
  return new Promise((resolve) => {
    const child = spawn(binary, [...args], {
      cwd: root,
      env: process.env,
      shell: false,
      stdio: ["ignore", captureStdout ? "pipe" : "ignore", "pipe"],
    })
    let stdout = ""
    let stderr = ""
    let spawnError: Error | undefined

    child.stdout?.on("data", (chunk) => {
      stdout += String(chunk)
    })
    child.stderr.on("data", (chunk) => {
      stderr = appendErrorOutput(stderr, chunk)
    })
    child.once("error", (error) => {
      spawnError = error
    })
    child.once("close", (exitCode) => {
      resolve({ exitCode, stdout, stderr, error: spawnError })
    })
  })
}

function runCodeGraph(args: readonly string[], root: string, captureStdout = true) {
  return runCommand(CODEGRAPH_BINARY, args, root, captureStdout)
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function isIndexState(value: unknown): value is IndexState {
  return value === null || Object.values(INDEX_STATES).includes(value as Exclude<IndexState, null>)
}

function parseStatusPayload(stdout: string): CodeGraphStatus {
  const payload: unknown = JSON.parse(stdout)
  if (!isRecord(payload) || typeof payload.initialized !== "boolean") {
    throw new Error("status payload must contain a boolean initialized field")
  }
  if (payload.indexPath !== undefined && (typeof payload.indexPath !== "string" || !payload.indexPath)) {
    throw new Error("status payload contains an invalid indexPath")
  }
  if (
    payload.fileCount !== undefined &&
    (typeof payload.fileCount !== "number" || !Number.isInteger(payload.fileCount) || payload.fileCount < 0)
  ) {
    throw new Error("status payload contains an invalid fileCount")
  }

  let index: CodeGraphStatus["index"]
  if (payload.index !== undefined) {
    if (!isRecord(payload.index) || !isIndexState(payload.index.state)) {
      throw new Error("status payload contains an unknown index state")
    }
    index = { state: payload.index.state }
  }

  if (!payload.initialized && (index !== undefined || payload.fileCount !== undefined)) {
    throw new Error("uninitialized status payload contains index data")
  }
  if (payload.initialized && index === undefined) {
    throw new Error("initialized status payload is missing index state")
  }
  if (index?.state === INDEX_STATES.COMPLETE && payload.fileCount === undefined) {
    throw new Error("complete status payload is missing fileCount")
  }

  return {
    initialized: payload.initialized,
    indexPath: payload.indexPath as string | undefined,
    fileCount: payload.fileCount as number | undefined,
    index,
  }
}

async function readStatus(root: string): Promise<{ status?: CodeGraphStatus; result: CommandResult }> {
  const result = await runCodeGraph([...STATUS_ARGS, root, JSON_FLAG], root)
  if (result.error || result.exitCode !== 0) return { result }

  try {
    return { status: parseStatusPayload(result.stdout), result }
  } catch (error) {
    return {
      result: {
        ...result,
        error: new Error(`invalid status JSON: ${errorMessage(error)}`),
      },
    }
  }
}

function isMissingBinary(result: CommandResult) {
  return result.error && "code" in result.error && result.error.code === "ENOENT"
}

function isHealthy(status: CodeGraphStatus) {
  return status.initialized && status.index?.state === INDEX_STATES.COMPLETE
}

function resolvedIndexPath(status: CodeGraphStatus, root: string) {
  return status.indexPath ?? path.join(root, process.env[CODEGRAPH_DIR_ENV] || DEFAULT_INDEX_DIR)
}

async function showToastBestEffort(
  input: ToastInput,
  message: string,
  variant: ToastVariant,
  duration: number,
) {
  try {
    await input.client.tui.showToast({
      body: { message, variant, duration },
      query: { directory: input.directory },
    })
  } catch (error) {
    console.error(`${LOG_PREFIX} toast failed: ${errorMessage(error)}`)
  }
}

async function resolveGitExcludePath(root: string) {
  const result = await runCommand(GIT_BINARY, GIT_EXCLUDE_ARGS, root)
  const stderr = result.stderr.trim()
  if (result.error || result.exitCode !== 0) {
    if (!result.error && stderr.toLowerCase().includes(NOT_GIT_REPOSITORY_ERROR)) return
    const detail = result.error ? errorMessage(result.error) : stderr || `exit ${result.exitCode}`
    console.error(`${LOG_PREFIX} cannot resolve Git exclude path: ${detail}`)
    return
  }

  const [insideWorkTree, excludePath] = result.stdout.trim().split(/\r?\n/, 2)
  if (insideWorkTree !== GIT_WORK_TREE_RESULT) return
  if (!excludePath) {
    console.error(`${LOG_PREFIX} Git did not return an exclude path`)
    return
  }
  return path.resolve(root, excludePath)
}

async function ensureGitExclude(root: string, indexPath: string) {
  const relativeIndexPath = path.relative(root, indexPath)
  if (!relativeIndexPath || relativeIndexPath.startsWith("..") || path.isAbsolute(relativeIndexPath)) {
    console.error(`${LOG_PREFIX} cannot exclude index path outside project: ${indexPath}`)
    return
  }

  const entry = `${relativeIndexPath.split(path.sep).join("/").replace(/\/$/, "")}/`
  const excludePath = await resolveGitExcludePath(root)
  if (!excludePath) return

  let text: string
  try {
    text = await fs.readFile(excludePath, "utf8")
  } catch (error) {
    console.error(`${LOG_PREFIX} cannot read Git exclude file: ${errorMessage(error)}`)
    return
  }
  if (text.split(/\r?\n/).includes(entry)) return

  try {
    await fs.appendFile(excludePath, text.endsWith("\n") ? `${entry}\n` : `\n${entry}\n`)
  } catch (error) {
    console.error(`${LOG_PREFIX} cannot update Git exclude file: ${errorMessage(error)}`)
  }
}

type RepoAction = "init" | "repair"

type RepoOutcome =
  | { kind: "healthy" }
  | { kind: "ready"; action: RepoAction; fileCount: number }
  | { kind: "missing-binary" }
  | { kind: "status-failed" }
  | { kind: "action-failed"; action: RepoAction }
  | { kind: "incomplete"; action: RepoAction; state: IndexState }

// Drive one repository's index to a healthy state. The caller emits toasts; onStart runs
// immediately before the init/repair process spawns so a presenter can time it and announce it.
async function ensureRepoIndex(root: string, onStart: (action: RepoAction) => Promise<void>): Promise<RepoOutcome> {
  const initial = await readStatus(root)
  if (isMissingBinary(initial.result)) return { kind: "missing-binary" }
  if (!initial.status) {
    const detail = initial.result.error ? errorMessage(initial.result.error) : initial.result.stderr.trim()
    if (detail) console.error(`${LOG_PREFIX} status failed for ${root}: ${detail}`)
    return { kind: "status-failed" }
  }
  if (isHealthy(initial.status)) return { kind: "healthy" }

  const action: RepoAction = initial.status.initialized ? "repair" : "init"
  const args = action === "repair" ? [...INDEX_ARGS, root, FORCE_FLAG] : [...INIT_ARGS, root]

  await onStart(action)
  const run = await runCodeGraph(args, root, false)
  if (run.error || run.exitCode !== 0) {
    const detail = run.error ? errorMessage(run.error) : run.stderr.trim()
    if (detail) console.error(`${LOG_PREFIX} ${action} failed for ${root}: ${detail}`)
    return { kind: "action-failed", action }
  }

  const final = await readStatus(root)
  if (!final.status || !isHealthy(final.status)) {
    return { kind: "incomplete", action, state: final.status?.index?.state ?? null }
  }

  await ensureGitExclude(root, resolvedIndexPath(final.status, root))
  return { kind: "ready", action, fileCount: final.status.fileCount ?? 0 }
}

async function initializeSingleRoot(input: ToastInput, root: string) {
  const repo = repoName(root)
  let startedAt = Date.now()
  const onStart = async (action: RepoAction) => {
    startedAt = Date.now()
    const message = action === "repair" ? repairStartMessage(repo) : startMessage(repo)
    await showToastBestEffort(input, message, TOAST_VARIANTS.INFO, INFO_DURATION_MS)
  }

  const outcome = await ensureRepoIndex(root, onStart)
  switch (outcome.kind) {
    case "healthy":
      return
    case "missing-binary":
      await showToastBestEffort(input, missingBinaryMessage(), TOAST_VARIANTS.WARNING, WARNING_DURATION_MS)
      return
    case "status-failed":
    case "action-failed":
      await showToastBestEffort(
        input,
        processFailureMessage(repo, recoveryStatusCommand(root)),
        TOAST_VARIANTS.ERROR,
        ERROR_DURATION_MS,
      )
      return
    case "incomplete":
      await showToastBestEffort(
        input,
        incompleteMessage(repo, outcome.state, recoveryIndexCommand(root)),
        TOAST_VARIANTS.WARNING,
        WARNING_DURATION_MS,
      )
      return
    case "ready":
      await showToastBestEffort(
        input,
        successMessage(repo, outcome.fileCount, formatElapsed(Date.now() - startedAt)),
        TOAST_VARIANTS.SUCCESS,
        INFO_DURATION_MS,
      )
      return
  }
}

async function hasGitEntry(dir: string) {
  try {
    const stat = await fs.stat(path.join(dir, ".git"))
    return stat.isDirectory() || stat.isFile()
  } catch {
    return false
  }
}

// Find git repositories nested up to NESTED_REPO_MAX_DEPTH directory levels below a non-git
// workspace root. Symlinked directories are skipped (no cycle/escape risk); a directory holding
// a .git entry is a repository and is not descended into (its children are submodule territory).
async function discoverNestedRepos(root: string) {
  const repos: string[] = []

  async function scan(dir: string, depth: number) {
    let entries
    try {
      entries = await fs.readdir(dir, { withFileTypes: true })
    } catch {
      return
    }
    for (const entry of entries) {
      if (!entry.isDirectory()) continue
      if (entry.name.startsWith(".") || IGNORED_DIRECTORY_NAMES.has(entry.name)) continue
      const child = path.join(dir, entry.name)
      if (await hasGitEntry(child)) {
        repos.push(child)
        continue
      }
      if (depth < NESTED_REPO_MAX_DEPTH) await scan(child, depth + 1)
    }
  }

  await scan(root, 1)
  return repos.sort((a, b) => a.localeCompare(b))
}

async function initializeAggregate(input: ToastInput, root: string, repos: string[]) {
  const rootName = repoName(root)

  // Classify first so an already-healthy workspace stays silent and a missing binary surfaces
  // exactly one warning before any start toast. Unreadable status is left as work; the engine
  // re-reads it and reports the failure uniformly.
  const work: string[] = []
  for (const repo of repos) {
    const status = await readStatus(repo)
    if (isMissingBinary(status.result)) {
      await showToastBestEffort(input, missingBinaryMessage(), TOAST_VARIANTS.WARNING, WARNING_DURATION_MS)
      return
    }
    if (status.status && isHealthy(status.status)) continue
    work.push(repo)
  }
  if (work.length === 0) return

  await showToastBestEffort(input, aggregateStartMessage(work.length, rootName), TOAST_VARIANTS.INFO, INFO_DURATION_MS)
  const startedAt = Date.now()
  const failed: string[] = []
  for (const repo of work) {
    const outcome = await ensureRepoIndex(repo, async () => {})
    if (outcome.kind !== "ready" && outcome.kind !== "healthy") failed.push(repo)
  }

  if (failed.length === 0) {
    await showToastBestEffort(
      input,
      aggregateSuccessMessage(work.length, rootName, formatElapsed(Date.now() - startedAt)),
      TOAST_VARIANTS.SUCCESS,
      INFO_DURATION_MS,
    )
    return
  }

  await showToastBestEffort(
    input,
    aggregateFailureMessage(
      work.length - failed.length,
      work.length,
      rootName,
      failed.map((repo) => path.relative(root, repo)),
    ),
    TOAST_VARIANTS.WARNING,
    WARNING_DURATION_MS,
  )
}

async function initializeCodeGraph(input: ToastInput & { root: string }) {
  if (process.env[AUTOINIT_ENV] === AUTOINIT_OPT_OUT) return

  const { root } = input
  if (await hasGitEntry(root)) return initializeSingleRoot(input, root)

  const repos = await discoverNestedRepos(root)
  if (repos.length === 0) return initializeSingleRoot(input, root)
  return initializeAggregate(input, root, repos)
}

export const CodeGraphInitPlugin: Plugin = async (input) => {
  const root = projectRoot(input)
  void initializeCodeGraph({ client: input.client, directory: input.directory, root }).catch((error) => {
    console.error(`${LOG_PREFIX} ${errorMessage(error)}`)
  })
  return {}
}

export default {
  id: PLUGIN_ID,
  server: CodeGraphInitPlugin,
}
