import { spawn } from "node:child_process"
import fs from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

const PLUGIN_ID = "graphify-init"
const LOG_PREFIX = `[${PLUGIN_ID}]`
const GRAPHIFY_BINARY = "graphify"
const GRAPHIFY_INSTALL_HINT = "uv tool install graphifyy (or pipx install graphifyy)"
const GIT_BINARY = "git"
const AUTOINIT_ENV = "OPENCODE_GRAPHIFY_AUTOINIT"
const GLOBAL_ENV = "OPENCODE_GRAPHIFY_GLOBAL"
const DOCS_ENV = "OPENCODE_GRAPHIFY_DOCS"
const BACKEND_ENV = "OPENCODE_GRAPHIFY_BACKEND"
const AUTOINIT_OPT_OUT = "0"
const GLOBAL_OPT_OUT = "0"
const DOCS_OPT_IN = "1"
// Local tool state lives under .ai/ by convention. Graphify's --out flag relocates its
// whole output tree, but the graphify-out leaf name is fixed by the CLI itself.
const OUT_BASE = ".ai"
const OUT_DIR = "graphify-out"
const GRAPH_FILE = "graph.json"
const EMPTY_MARKER_FILE = ".opencode-empty-corpus"
// Marker value for roots where `git rev-parse HEAD` resolves nothing (plain directories,
// repositories with no commits): the marker must still be written there, or the plugin
// would re-extract and re-toast the same empty corpus every session.
const EMPTY_MARKER_NO_COMMIT = "none"
// A repository holding no indexable code is not a failure, but Graphify reports it as one
// (exit 1, no graph.json). These are its two signals for that case.
const EMPTY_CORPUS_PATTERN = /produced no nodes|found 0 code[,\s]/i
const EXTRACT_ARGS = ["extract"] as const
const CODE_ONLY_FLAG = "--code-only"
const BACKEND_FLAG = "--backend"
const OUT_FLAG = "--out"
const GLOBAL_FLAG = "--global"
const AS_FLAG = "--as"
const VERSION_ARGS = ["--version"] as const
const GIT_EXCLUDE_ARGS = ["rev-parse", "--is-inside-work-tree", "--git-path", "info/exclude"] as const
const GIT_HEAD_ARGS = ["rev-parse", "HEAD"] as const
const GIT_HEAD_TIME_ARGS = ["log", "-1", "--format=%ct"] as const
const GIT_WORK_TREE_RESULT = "true"
const NOT_GIT_REPOSITORY_ERROR = "not a git repository"
const IGNORED_DIRECTORY_NAMES = new Set(["node_modules"])
const NESTED_REPO_MAX_DEPTH = 2
const MAX_SUMMARY_FAILURES = 3
const MAX_CAPTURED_OUTPUT_LENGTH = 1_000
const INFO_DURATION_MS = 5_000
const WARNING_DURATION_MS = 8_000
const ERROR_DURATION_MS = 8_000

const TOAST_VARIANTS = {
  ERROR: "error",
  INFO: "info",
  SUCCESS: "success",
  WARNING: "warning",
} as const

type ToastVariant = (typeof TOAST_VARIANTS)[keyof typeof TOAST_VARIANTS]

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

type RepoAction = "build" | "update"

const buildStartMessage = (repo: string) =>
  `Graphify is building the code graph for ${repo} in the background. You can keep working.`

const updateStartMessage = (repo: string) =>
  `Graphify is updating the ${repo} code graph in the background. You can keep working.`

const successMessage = (repo: string, nodeCount: number | undefined, elapsed: string) =>
  nodeCount === undefined
    ? `Graphify graph for ${repo} is ready in ${elapsed}.`
    : `Graphify graph for ${repo} is ready: ${nodeCount} nodes in ${elapsed}.`

const emptyCorpusMessage = (repo: string) =>
  `Graphify found no indexable code in ${repo}; skipping the code graph.`

// Exit-0 shrink: unlike the exit-1 empty corpus, a graph WAS written (0 nodes) and, with
// the global merge inline, already registered globally — "skipping" would be inaccurate.
const zeroNodeMessage = (repo: string) =>
  `Graphify found no indexable code left in ${repo}; the graph is now empty.`

const aggregateEmptyMessage = (rootName: string) =>
  `Graphify found no indexable code in the repositories under ${rootName}; skipping the code graphs.`

const missingBinaryMessage = () => `Graphify CLI was not found. Run: ${GRAPHIFY_INSTALL_HINT}`

const incompleteMessage = (repo: string, command: string) =>
  `Graphify graph for ${repo} is incomplete (${OUT_BASE}/${OUT_DIR}/${GRAPH_FILE} is missing or unreadable). Run: ${command}`

const processFailureMessage = (repo: string, command: string) =>
  `Graphify indexing failed for ${repo}, but this session is still operational. Run: ${command}`

const repositoriesLabel = (count: number) => `${count} ${count === 1 ? "repository" : "repositories"}`

const aggregateStartMessage = (count: number, rootName: string) =>
  `Graphify is building code graphs for ${repositoriesLabel(count)} under ${rootName} in the background. You can keep working.`

const aggregateSuccessMessage = (count: number, rootName: string, elapsed: string) =>
  `Graphify built code graphs for ${repositoriesLabel(count)} under ${rootName} in ${elapsed}.`

const aggregateFailureMessage = (okCount: number, total: number, rootName: string, failedNames: string[]) => {
  const shown = failedNames.slice(0, MAX_SUMMARY_FAILURES)
  const overflow = failedNames.length - shown.length
  const list = overflow > 0 ? `${shown.join(", ")}, +${overflow} more` : shown.join(", ")
  const command = [GRAPHIFY_BINARY, EXTRACT_ARGS[0], "<repo>", ...extractModeArgs(), OUT_FLAG, `<repo>/${OUT_BASE}`].join(" ")
  return `Graphify built ${okCount} of ${total} code graphs under ${rootName}. Failed: ${list}. Run: ${command}`
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

function recoveryBuildCommand(root: string) {
  return [
    GRAPHIFY_BINARY,
    EXTRACT_ARGS[0],
    quoteForDisplay(root),
    ...extractModeArgs(),
    OUT_FLAG,
    quoteForDisplay(outBasePath(root)),
  ].join(" ")
}

function formatElapsed(elapsedMs: number) {
  return `${Math.max(0.1, elapsedMs / 1_000).toFixed(1)}s`
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

// Keep the TAIL of each stream: Graphify's decisive lines — the empty-corpus signal and
// any exception message — are emitted at the end of a run, after arbitrary progress output.
function appendBoundedOutput(current: string, chunk: unknown) {
  return `${current}${String(chunk)}`.slice(-MAX_CAPTURED_OUTPUT_LENGTH)
}

function runCommand(binary: string, args: readonly string[], root: string): Promise<CommandResult> {
  return new Promise((resolve) => {
    const child = spawn(binary, [...args], {
      cwd: root,
      env: process.env,
      shell: false,
      stdio: ["ignore", "pipe", "pipe"],
    })
    let stdout = ""
    let stderr = ""
    let spawnError: Error | undefined

    child.stdout?.on("data", (chunk) => {
      stdout = appendBoundedOutput(stdout, chunk)
    })
    child.stderr?.on("data", (chunk) => {
      stderr = appendBoundedOutput(stderr, chunk)
    })
    child.once("error", (error) => {
      spawnError = error
    })
    child.once("close", (exitCode) => {
      resolve({ exitCode, stdout, stderr, error: spawnError })
    })
  })
}

function runGraphify(args: readonly string[], root: string) {
  return runCommand(GRAPHIFY_BINARY, args, root)
}

function isMissingBinary(result: CommandResult) {
  return Boolean(result.error && "code" in result.error && result.error.code === "ENOENT")
}

// Only ENOENT matters here: a Graphify build is expensive and a whole aggregate run
// should surface one install hint instead of N failures. A non-zero exit still counts
// as "present" so an unrecognized probe flag never blocks indexing.
async function isBinaryMissing(root: string) {
  return isMissingBinary(await runGraphify(VERSION_ARGS, root))
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function outBasePath(root: string) {
  return path.join(root, OUT_BASE)
}

function outDirPath(root: string) {
  return path.join(outBasePath(root), OUT_DIR)
}

function graphFilePath(root: string) {
  return path.join(outDirPath(root), GRAPH_FILE)
}

function nodeCountOf(payload: unknown) {
  if (!isRecord(payload)) return undefined
  if (Array.isArray(payload.nodes)) return payload.nodes.length
  if (isRecord(payload.stats) && typeof payload.stats.nodes === "number") return payload.stats.nodes
  return undefined
}

type GraphSnapshot = { mtimeMs: number; builtAtCommit: string | undefined; nodeCount: number | undefined }

// A graph that cannot be parsed is treated as absent: a truncated or half-written
// graph.json is worse than no graph, and a full rebuild is the only safe repair.
async function readGraph(root: string): Promise<GraphSnapshot | undefined> {
  const graphPath = graphFilePath(root)
  try {
    const stat = await fs.stat(graphPath)
    if (!stat.isFile()) return undefined
    const payload: unknown = JSON.parse(await fs.readFile(graphPath, "utf8"))
    if (!isRecord(payload)) return undefined
    const builtAtCommit = typeof payload.built_at_commit === "string" ? payload.built_at_commit : undefined
    return { mtimeMs: stat.mtimeMs, builtAtCommit, nodeCount: nodeCountOf(payload) }
  } catch {
    return undefined
  }
}

async function gitValue(root: string, args: readonly string[]) {
  const result = await runCommand(GIT_BINARY, args, root)
  if (result.error || result.exitCode !== 0) return undefined
  return result.stdout.trim() || undefined
}

// Graphify stamps the commit it indexed into graph.json, so freshness is an exact
// comparison rather than a guess. Older graphs (or builds made outside Git) carry no
// stamp; those fall back to comparing file mtime against the last commit time, which
// is coarser but still catches a graph left behind by newer work.
async function isGraphStale(root: string, graph: GraphSnapshot) {
  const head = await gitValue(root, GIT_HEAD_ARGS)
  if (!head) return false
  if (graph.builtAtCommit) return graph.builtAtCommit !== head

  const headTime = Number.parseInt((await gitValue(root, GIT_HEAD_TIME_ARGS)) ?? "", 10)
  if (!Number.isFinite(headTime)) return false
  return graph.mtimeMs < headTime * 1_000
}

function emptyMarkerPath(root: string) {
  return path.join(outDirPath(root), EMPTY_MARKER_FILE)
}

// A documentation-only repository produces no graph and no toast, but Graphify still exits
// non-zero every time it is asked. The marker records the commit that had nothing to index so
// reopening that repository stays quiet, while any new commit earns a fresh attempt.
async function readEmptyMarker(root: string) {
  try {
    return (await fs.readFile(emptyMarkerPath(root), "utf8")).trim() || undefined
  } catch {
    return undefined
  }
}

async function writeEmptyMarker(root: string, commit: string | undefined) {
  try {
    await fs.mkdir(outDirPath(root), { recursive: true })
    await fs.writeFile(emptyMarkerPath(root), `${commit ?? EMPTY_MARKER_NO_COMMIT}\n`)
  } catch (error) {
    console.error(`${LOG_PREFIX} cannot record empty-corpus marker for ${root}: ${errorMessage(error)}`)
  }
}

// A successful build invalidates any earlier empty-corpus marker; leaving it behind would
// make a later checkout of the once-empty commit silently serve the newer graph as current.
async function clearEmptyMarker(root: string) {
  try {
    await fs.rm(emptyMarkerPath(root), { force: true })
  } catch (error) {
    console.error(`${LOG_PREFIX} cannot clear empty-corpus marker for ${root}: ${errorMessage(error)}`)
  }
}

type RepoPlan = RepoAction | "none"

async function planRepo(root: string): Promise<RepoPlan> {
  // The marker wins even over an existing stale graph: a repository whose code was all
  // deleted keeps its last graph on disk while every re-extract at that commit keeps
  // reporting an empty corpus, so retrying before a new commit would loop forever.
  const emptyAtCommit = await readEmptyMarker(root)
  if (emptyAtCommit && emptyAtCommit === ((await gitValue(root, GIT_HEAD_ARGS)) ?? EMPTY_MARKER_NO_COMMIT)) {
    return "none"
  }

  const graph = await readGraph(root)
  if (graph) return (await isGraphStale(root, graph)) ? "update" : "none"
  return "build"
}

async function realRoot(dir: string) {
  try {
    return await fs.realpath(dir)
  } catch {
    return path.resolve(dir)
  }
}

// Graphify has no unsafe-root refusal of its own, so the plugin owns the guard:
// indexing a home directory or a filesystem root would walk an unbounded tree and
// write artifacts far outside any project.
async function isUnsafeGraphRoot(resolvedRoot: string) {
  if (path.parse(resolvedRoot).root === resolvedRoot) return true
  const home = await realRoot(os.homedir())
  const caseInsensitive = process.platform === "darwin" || process.platform === "win32"
  const norm = (value: string) => (caseInsensitive ? value.toLowerCase() : value)
  return norm(resolvedRoot) === norm(home) || norm(home).startsWith(norm(resolvedRoot) + path.sep)
}

function slugify(value: string) {
  return value.replaceAll(/[^A-Za-z0-9_-]/g, "-")
}

function isGlobalEnabled() {
  return process.env[GLOBAL_ENV] !== GLOBAL_OPT_OUT
}

// Documentation indexing is opt-in: without --code-only, Graphify routes doc/paper/image
// files through an LLM backend, which needs credentials and spends tokens in the background.
// The default stays pure local AST. OPENCODE_GRAPHIFY_BACKEND pins Graphify's --backend so
// auto-detection from stray API keys never decides where the corpus is sent.
function isDocsEnabled() {
  return process.env[DOCS_ENV] === DOCS_OPT_IN
}

function extractModeArgs() {
  if (!isDocsEnabled()) return [CODE_ONLY_FLAG]
  const backend = process.env[BACKEND_ENV]?.trim()
  return backend ? [BACKEND_FLAG, backend] : []
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

async function ensureGitExclude(root: string, artifactPath: string) {
  const relativeArtifactPath = path.relative(root, artifactPath)
  if (!relativeArtifactPath || relativeArtifactPath.startsWith("..") || path.isAbsolute(relativeArtifactPath)) {
    console.error(`${LOG_PREFIX} cannot exclude artifact path outside project: ${artifactPath}`)
    return
  }

  const entry = relativeArtifactPath.split(path.sep).join("/").replace(/\/$/, "")
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

type RepoOutcome =
  | { kind: "ready"; action: RepoAction; nodeCount: number | undefined }
  | { kind: "empty" }
  | { kind: "zero-nodes" }
  | { kind: "action-failed"; action: RepoAction }
  | { kind: "incomplete"; action: RepoAction }

// Build or refresh one repository's graph. The caller emits toasts; onStart runs immediately
// before the Graphify process spawns so a presenter can time it and announce it.
async function buildRepoGraph(
  root: string,
  action: RepoAction,
  onStart: (action: RepoAction) => Promise<void>,
): Promise<RepoOutcome> {
  // Both first builds and refreshes go through `extract`: it is natively incremental
  // (manifest gate) and it is the only lifecycle command that honours --out, which keeps
  // every artifact under .ai/. `graphify update` would recreate graphify-out/ at the root.
  // --global --as merges the result into ~/.graphify/global-graph.json inline.
  const tag = slugify(repoName(await realRoot(root)))
  const args = [
    ...EXTRACT_ARGS,
    root,
    ...extractModeArgs(),
    OUT_FLAG,
    outBasePath(root),
    ...(isGlobalEnabled() ? [GLOBAL_FLAG, AS_FLAG, tag] : []),
  ]

  // Exclude before indexing, not after: Graphify honours .git/info/exclude, so the entry
  // is what keeps a rebuild from walking its own previous output.
  await ensureGitExclude(root, outDirPath(root))

  await onStart(action)
  const run = await runGraphify(args, root)
  if (run.error || run.exitCode !== 0) {
    if (!run.error && EMPTY_CORPUS_PATTERN.test(`${run.stdout}\n${run.stderr}`)) {
      await writeEmptyMarker(root, await gitValue(root, GIT_HEAD_ARGS))
      return { kind: "empty" }
    }
    const detail = run.error ? errorMessage(run.error) : run.stderr.trim()
    if (detail) console.error(`${LOG_PREFIX} ${action} failed for ${root}: ${detail}`)
    return { kind: "action-failed", action }
  }

  const graph = await readGraph(root)
  if (!graph) return { kind: "incomplete", action }
  // A repository whose code was all deleted refreshes to a 0-node graph with exit 0; that is
  // "nothing to index", not a success. No marker: the freshly stamped graph keeps reopens quiet.
  if (graph.nodeCount === 0) return { kind: "zero-nodes" }

  await clearEmptyMarker(root)
  return { kind: "ready", action, nodeCount: graph.nodeCount }
}

async function presentSingleRoot(input: ToastInput, root: string, action: RepoAction) {
  const repo = repoName(root)
  let startedAt = Date.now()
  const onStart = async (started: RepoAction) => {
    startedAt = Date.now()
    const message = started === "update" ? updateStartMessage(repo) : buildStartMessage(repo)
    await showToastBestEffort(input, message, TOAST_VARIANTS.INFO, INFO_DURATION_MS)
  }

  const outcome = await buildRepoGraph(root, action, onStart)
  switch (outcome.kind) {
    case "empty":
      await showToastBestEffort(input, emptyCorpusMessage(repo), TOAST_VARIANTS.INFO, INFO_DURATION_MS)
      return
    case "zero-nodes":
      await showToastBestEffort(input, zeroNodeMessage(repo), TOAST_VARIANTS.INFO, INFO_DURATION_MS)
      return
    case "action-failed":
      await showToastBestEffort(
        input,
        processFailureMessage(repo, recoveryBuildCommand(root)),
        TOAST_VARIANTS.ERROR,
        ERROR_DURATION_MS,
      )
      return
    case "incomplete":
      await showToastBestEffort(
        input,
        incompleteMessage(repo, recoveryBuildCommand(root)),
        TOAST_VARIANTS.WARNING,
        WARNING_DURATION_MS,
      )
      return
    case "ready":
      await showToastBestEffort(
        input,
        successMessage(repo, outcome.nodeCount, formatElapsed(Date.now() - startedAt)),
        TOAST_VARIANTS.SUCCESS,
        INFO_DURATION_MS,
      )
      return
  }
}

async function presentAggregate(input: ToastInput, root: string, work: { root: string; action: RepoAction }[]) {
  const rootName = repoName(root)
  await showToastBestEffort(input, aggregateStartMessage(work.length, rootName), TOAST_VARIANTS.INFO, INFO_DURATION_MS)
  const startedAt = Date.now()
  const failed: string[] = []
  let built = 0
  for (const item of work) {
    // A nested repository with nothing to index is skipped, not counted as a failure.
    const outcome = await buildRepoGraph(item.root, item.action, async () => {})
    if (outcome.kind === "ready") built += 1
    else if (outcome.kind !== "empty" && outcome.kind !== "zero-nodes") failed.push(item.root)
  }

  if (failed.length === 0) {
    if (built === 0) {
      // Every nested repository turned out empty: say so instead of leaving the start
      // toast dangling with no resolution.
      await showToastBestEffort(input, aggregateEmptyMessage(rootName), TOAST_VARIANTS.INFO, INFO_DURATION_MS)
      return
    }
    await showToastBestEffort(
      input,
      aggregateSuccessMessage(built, rootName, formatElapsed(Date.now() - startedAt)),
      TOAST_VARIANTS.SUCCESS,
      INFO_DURATION_MS,
    )
    return
  }

  await showToastBestEffort(
    input,
    aggregateFailureMessage(
      built,
      work.length,
      rootName,
      failed.map((repo) => path.relative(root, repo)),
    ),
    TOAST_VARIANTS.WARNING,
    WARNING_DURATION_MS,
  )
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

// Planning is local (filesystem plus `git log`), so an already-indexed session never spawns
// Graphify at all and the binary probe happens exactly once, only when there is real work.
async function collectWork(roots: string[]) {
  const work: { root: string; action: RepoAction }[] = []
  for (const root of roots) {
    if (await isUnsafeGraphRoot(await realRoot(root))) {
      console.error(`${LOG_PREFIX} refusing to index unsafe root: ${root}`)
      continue
    }
    const plan = await planRepo(root)
    if (plan !== "none") work.push({ root, action: plan })
  }
  return work
}

async function initializeGraphify(input: ToastInput & { root: string }) {
  if (process.env[AUTOINIT_ENV] === AUTOINIT_OPT_OUT) return

  const { root } = input
  const aggregated = (await hasGitEntry(root)) ? [] : await discoverNestedRepos(root)
  const roots = aggregated.length > 0 ? aggregated : [root]

  const work = await collectWork(roots)
  if (work.length === 0) return

  if (await isBinaryMissing(root)) {
    await showToastBestEffort(input, missingBinaryMessage(), TOAST_VARIANTS.WARNING, WARNING_DURATION_MS)
    return
  }

  if (aggregated.length === 0) return presentSingleRoot(input, work[0].root, work[0].action)
  return presentAggregate(input, root, work)
}

export const GraphifyInitPlugin: Plugin = async (input) => {
  const root = projectRoot(input)
  void initializeGraphify({ client: input.client, directory: input.directory, root }).catch((error) => {
    console.error(`${LOG_PREFIX} ${errorMessage(error)}`)
  })
  return {}
}

export default {
  id: PLUGIN_ID,
  server: GraphifyInitPlugin,
}
