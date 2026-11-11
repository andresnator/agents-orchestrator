import type { Plugin } from "@opencode/plugin"
import type { SystemPart } from "@opencode/ai"
import fs from "node:fs"
import { randomUUID } from "node:crypto"
import { homedir } from "node:os"
import { join } from "node:path"

const PLUGIN_ID = "caveman-mode"
const COMMAND_NAME = "caveman"
const DEFAULT_MODE = "lite"
const BARE_COMMAND_MODE = "lite"
const OFF_MODE = "off"
const MODE_MARKER_PREFIX = "CAVEMAN SESSION MODE:"
const VALID_MODES = ["lite", "full", "ultra", "wenyan"] as const
const DEACTIVATION_PHRASES = new Set(["stop caveman", "normal mode"])
const STATE_FILE = "caveman-mode.json"
const COMMAND_USAGE = "Usage: /caveman [lite|full|ultra|wenyan]"
const REQUEST_HOOKS = ["context", "compaction", "generate", "title"] as const

type CavemanLevel = (typeof VALID_MODES)[number]
type CavemanMode = CavemanLevel | typeof OFF_MODE

function parseCommandMode(rawArguments: string): CavemanLevel | null {
  const normalized = rawArguments.trim().toLowerCase()
  if (!normalized) return BARE_COMMAND_MODE
  return VALID_MODES.includes(normalized as CavemanLevel) ? (normalized as CavemanLevel) : null
}

function parseDeactivationPhrase(text: string): typeof OFF_MODE | null {
  const normalized = text.trim().toLowerCase().replace(/[.!]+$/, "").trim()
  return DEACTIVATION_PHRASES.has(normalized) ? OFF_MODE : null
}

function configDirectory(): string {
  return process.env.OPENCODE_CONFIG_DIR ||
    join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "opencode")
}

function readMode(statePath: string): CavemanMode {
  let text: string
  try {
    text = fs.readFileSync(statePath, "utf8")
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return DEFAULT_MODE
    throw error
  }
  const state = JSON.parse(text)
  if (!state || typeof state !== "object" || Array.isArray(state) ||
    Object.keys(state).length !== 1 ||
    !(state.mode === OFF_MODE || VALID_MODES.includes(state.mode))) {
    throw new Error(`Invalid Caveman state: ${statePath}`)
  }
  return state.mode
}

function writeMode(directory: string, statePath: string, mode: CavemanMode): void {
  // Never replace an unreadable or corrupt selection with a new one.
  readMode(statePath)
  fs.mkdirSync(directory, { recursive: true })
  const temporaryPath = `${statePath}.${randomUUID()}.tmp`
  try {
    fs.writeFileSync(temporaryPath, JSON.stringify({ mode }) + "\n", { flag: "wx", mode: 0o600 })
    readMode(statePath)
    // Same-directory rename is the atomic commit point across processes.
    fs.renameSync(temporaryPath, statePath)
  } catch (error) {
    try {
      fs.rmSync(temporaryPath, { force: true })
    } catch {
      // Preserve the original failure; an orphan temporary file is never read.
    }
    throw error
  }
}

function markerFor(mode: CavemanMode): string {
  if (mode === OFF_MODE) {
    return `${MODE_MARKER_PREFIX} off. Use normal prose; this overrides the default lite fallback.`
  }
  return `${MODE_MARKER_PREFIX} ${mode}. Apply the matching Caveman rules from global AGENTS.md.`
}

function injectModeMarker(system: SystemPart[], mode: CavemanMode): void {
  const retained = system.filter((entry) => !entry.text.startsWith(MODE_MARKER_PREFIX))
  system.splice(0, system.length, ...retained, { type: "text", text: markerFor(mode) })
}

function commandMatches(command: string): boolean {
  return command.replace(/^\//, "") === COMMAND_NAME
}

export const cavemanModeContracts = {
  COMMAND_NAME,
  DEFAULT_MODE,
  MODE_MARKER_PREFIX,
  OFF_MODE,
  VALID_MODES,
  STATE_FILE,
  configDirectory,
  commandMatches,
  injectModeMarker,
  markerFor,
  parseCommandMode,
  parseDeactivationPhrase,
}

async function setup(ctx: Plugin.Context): Promise<Plugin.Cleanup> {
  const directory = configDirectory()
  const statePath = join(directory, STATE_FILE)
  const reportFailure = (error: unknown): never => {
    throw new Error(`Caveman global state failed: ${error instanceof Error ? error.message : String(error)}`, { cause: error })
  }
  const selectMode = (mode: CavemanMode): void => {
    try {
      writeMode(directory, statePath, mode)
    } catch (error) {
      reportFailure(error)
    }
  }

  const registrations: Array<{ dispose(): Promise<void> }> = []
  let disposed = false
  const cleanup = async (): Promise<void> => {
    if (disposed) return
    disposed = true
    await Promise.all(registrations.map((registration) => registration.dispose()))
  }
  try {
    registrations.push(await ctx.command.transform((editor) => {
      editor.add({
        name: COMMAND_NAME,
        description: "Save Caveman response compression globally",
        execute: async ({ sessionID, prompt, delivery }) => {
          const mode = parseCommandMode(prompt.text)
          if (!mode) throw new Error(COMMAND_USAGE)
          selectMode(mode)
          await ctx.session.prompt({
            ...prompt,
            sessionID,
            delivery,
            text: `Caveman mode ${mode} was saved globally. Acknowledge in one short sentence using that style.`,
          })
        },
      })
    }))
    registrations.push(await ctx.session.hook("prompt", (event) => {
      const mode = parseDeactivationPhrase(event.prompt.text)
      if (mode) selectMode(mode)
    }))
    for (const hook of REQUEST_HOOKS) {
      registrations.push(await ctx.session.hook(hook, (event) => {
        try {
          injectModeMarker(event.system, readMode(statePath))
        } catch (error) {
          reportFailure(error)
        }
      }))
    }
    return cleanup
  } catch (error) {
    await cleanup()
    throw error
  }
}

// Plugin.define is an identity function in V2. A typed definition keeps standalone
// Node tests dependency-free while exposing the same native loader/setup shape.
export const CavemanModePlugin: Plugin.Plugin = {
  id: PLUGIN_ID,
  setup,
}

export default CavemanModePlugin
