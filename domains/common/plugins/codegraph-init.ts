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
const AUTOINIT_ENABLED = "1"
const STATUS_ARGS = ["status"] as const
const INIT_ARGS = ["init"] as const
const JSON_FLAG = "--json"
const FORCE_FLAG = "--force"
const GIT_EXCLUDE_ARGS = ["rev-parse", "--is-inside-work-tree", "--git-path", "info/exclude"] as const
const GIT_WORK_TREE_RESULT = "true"
const NOT_GIT_REPOSITORY_ERROR = "not a git repository"
const DEFAULT_INDEX_DIR = ".codegraph"
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

async function initializeCodeGraph(input: ToastInput & { root: string }) {
  if (process.env[AUTOINIT_ENV] !== AUTOINIT_ENABLED) return

  const { root } = input
  const repo = repoName(root)
  const initial = await readStatus(root)
  if (isMissingBinary(initial.result)) {
    await showToastBestEffort(input, missingBinaryMessage(), TOAST_VARIANTS.WARNING, WARNING_DURATION_MS)
    return
  }
  if (!initial.status) {
    const detail = initial.result.error ? errorMessage(initial.result.error) : initial.result.stderr.trim()
    if (detail) console.error(`${LOG_PREFIX} status failed: ${detail}`)
    await showToastBestEffort(
      input,
      processFailureMessage(repo, recoveryStatusCommand(root)),
      TOAST_VARIANTS.ERROR,
      ERROR_DURATION_MS,
    )
    return
  }
  if (isHealthy(initial.status)) return
  if (initial.status.initialized) {
    await showToastBestEffort(
      input,
      incompleteMessage(repo, initial.status.index?.state ?? null, recoveryIndexCommand(root)),
      TOAST_VARIANTS.WARNING,
      WARNING_DURATION_MS,
    )
    return
  }

  await showToastBestEffort(input, startMessage(repo), TOAST_VARIANTS.INFO, INFO_DURATION_MS)
  const startedAt = Date.now()
  const init = await runCodeGraph([...INIT_ARGS, root], root, false)
  if (init.error || init.exitCode !== 0) {
    const detail = init.error ? errorMessage(init.error) : init.stderr.trim()
    if (detail) console.error(`${LOG_PREFIX} init failed: ${detail}`)
    await showToastBestEffort(
      input,
      processFailureMessage(repo, recoveryStatusCommand(root)),
      TOAST_VARIANTS.ERROR,
      ERROR_DURATION_MS,
    )
    return
  }

  const final = await readStatus(root)
  if (!final.status || !isHealthy(final.status)) {
    const state = final.status?.index?.state ?? null
    await showToastBestEffort(
      input,
      incompleteMessage(repo, state, recoveryIndexCommand(root)),
      TOAST_VARIANTS.WARNING,
      WARNING_DURATION_MS,
    )
    return
  }

  await ensureGitExclude(root, resolvedIndexPath(final.status, root))
  await showToastBestEffort(
    input,
    successMessage(repo, final.status.fileCount ?? 0, formatElapsed(Date.now() - startedAt)),
    TOAST_VARIANTS.SUCCESS,
    INFO_DURATION_MS,
  )
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
