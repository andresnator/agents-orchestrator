import type { Plugin } from "@opencode-ai/plugin"

const PLUGIN_ID = "caveman-mode"
const COMMAND_NAME = "caveman"
const DEFAULT_MODE = "lite"
const OFF_MODE = "off"
const MODE_MARKER_PREFIX = "CAVEMAN SESSION MODE:"
const VALID_MODES = ["lite", "full", "ultra", "wenyan"] as const
const DEACTIVATION_PHRASES = new Set(["stop caveman", "normal mode"])

type CavemanLevel = (typeof VALID_MODES)[number]
type CavemanMode = CavemanLevel | typeof OFF_MODE
type ParentResolver = (sessionID: string) => Promise<string | undefined>

function parseCommandMode(rawArguments: string): CavemanLevel | null {
  const normalized = rawArguments.trim().toLowerCase()
  if (!normalized) return DEFAULT_MODE
  return VALID_MODES.includes(normalized as CavemanLevel) ? (normalized as CavemanLevel) : null
}

function parseDeactivationPhrase(text: string): typeof OFF_MODE | null {
  const normalized = text.trim().toLowerCase().replace(/[.!]+$/, "").trim()
  return DEACTIVATION_PHRASES.has(normalized) ? OFF_MODE : null
}

async function resolveEffectiveMode(
  sessionID: string | undefined,
  explicitModes: ReadonlyMap<string, CavemanMode>,
  parentOf: ParentResolver,
): Promise<CavemanMode> {
  if (!sessionID) return DEFAULT_MODE
  const visited = new Set<string>()
  let current: string | undefined = sessionID

  while (current && !visited.has(current)) {
    visited.add(current)
    const explicit = explicitModes.get(current)
    if (explicit) return explicit
    try {
      current = await parentOf(current)
    } catch {
      return DEFAULT_MODE
    }
  }
  return DEFAULT_MODE
}

function markerFor(mode: CavemanMode): string {
  if (mode === OFF_MODE) {
    return `${MODE_MARKER_PREFIX} off. Use normal prose; this overrides the default lite fallback.`
  }
  return `${MODE_MARKER_PREFIX} ${mode}. Apply the matching Caveman rules from global AGENTS.md.`
}

function injectModeMarker(system: string[], mode: CavemanMode): void {
  const retained = system.filter((entry) => !entry.startsWith(MODE_MARKER_PREFIX))
  system.splice(0, system.length, ...retained, markerFor(mode))
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
  commandMatches,
  injectModeMarker,
  markerFor,
  parseCommandMode,
  parseDeactivationPhrase,
  resolveEffectiveMode,
}

export const CavemanModePlugin: Plugin = async ({ client, directory }) => {
  const explicitModes = new Map<string, CavemanMode>()
  const parentIDs = new Map<string, string | null>()

  const parentOf: ParentResolver = async (sessionID) => {
    if (parentIDs.has(sessionID)) return parentIDs.get(sessionID) ?? undefined
    const response = await client.session.get({
      path: { id: sessionID },
      query: { directory },
    })
    const parentID = response.data?.parentID
    parentIDs.set(sessionID, parentID ?? null)
    return parentID
  }

  return {
    "command.execute.before": async (input) => {
      if (!commandMatches(input.command)) return
      const mode = parseCommandMode(input.arguments)
      if (mode) explicitModes.set(input.sessionID, mode)
    },

    "chat.message": async (input, output) => {
      for (const part of output.parts) {
        if (part.type !== "text" || typeof part.text !== "string") continue
        const mode = parseDeactivationPhrase(part.text)
        if (mode) explicitModes.set(input.sessionID, mode)
      }
    },

    "experimental.chat.system.transform": async (input, output) => {
      const mode = await resolveEffectiveMode(input.sessionID, explicitModes, parentOf)
      injectModeMarker(output.system, mode)
    },

    event: async ({ event }) => {
      if (event.type === "session.created" || event.type === "session.updated") {
        parentIDs.set(event.properties.info.id, event.properties.info.parentID ?? null)
      }
      if (event.type === "session.deleted") {
        explicitModes.delete(event.properties.info.id)
        parentIDs.delete(event.properties.info.id)
      }
    },
  }
}

export default {
  id: PLUGIN_ID,
  server: CavemanModePlugin,
}
