import path from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

const ALLOWED_PLAN_PATH = /^\.ia-refactor\/plan\/\d{8}\/[^/]+\.md$/
const GUARDED_TOOLS = new Set(["edit", "write", "patch", "apply_patch"])

function toPosix(value: string) {
  return value.split(path.sep).join("/")
}

function stripQuotes(value: string) {
  return value.trim().replace(/^['"]|['"]$/g, "")
}

function normalizeRelativePath(candidate: string, worktree: string) {
  const cleaned = stripQuotes(candidate)
  if (!cleaned) return ""

  const absolute = path.isAbsolute(cleaned)
    ? cleaned
    : path.resolve(worktree, cleaned)

  const relative = toPosix(path.relative(worktree, absolute))
  return relative.replace(/^\.\/+/, "")
}

function isAllowedPlanPath(candidate: string, worktree: string) {
  const relative = normalizeRelativePath(candidate, worktree)
  return ALLOWED_PLAN_PATH.test(relative)
}

function permissionPatterns(input: { pattern?: string | string[] }) {
  if (!input.pattern) return []
  return Array.isArray(input.pattern) ? input.pattern : [input.pattern]
}

function collectPathCandidates(value: unknown, out = new Set<string>()) {
  if (typeof value === "string") return out
  if (Array.isArray(value)) {
    for (const item of value) collectPathCandidates(item, out)
    return out
  }
  if (!value || typeof value !== "object") return out

  for (const [key, child] of Object.entries(value)) {
    if (typeof child === "string") {
      const normalizedKey = key.toLowerCase()
      if (
        normalizedKey.includes("path") ||
        normalizedKey.includes("file") ||
        normalizedKey === "target"
      ) {
        out.add(child)
      }
    } else {
      collectPathCandidates(child, out)
    }
  }

  return out
}

function collectPatchTargets(patchText: string, out = new Set<string>()) {
  const targetPattern = /^\*\*\* (?:Add File|Update File|Delete File): (.+)$/gm
  const movePattern = /^\*\*\* Move to: (.+)$/gm

  for (const pattern of [targetPattern, movePattern]) {
    for (const match of patchText.matchAll(pattern)) {
      const candidate = match[1]?.trim()
      if (candidate) out.add(candidate)
    }
  }

  return out
}

function collectRedirectionTargets(command: string) {
  const targets = new Set<string>()
  const redirectPattern = /(?:^|[\s;(])(?:\d?>>?|>>)\s*([^\s;|&]+)/g
  const teePattern = /\btee\b(?:\s+-a)?\s+([^\s;|&]+)/g

  for (const pattern of [redirectPattern, teePattern]) {
    for (const match of command.matchAll(pattern)) {
      const candidate = match[1]
      if (candidate) targets.add(candidate)
    }
  }

  return [...targets]
}

function extractShellCommand(args: any) {
  if (typeof args === "string") return args
  if (!args || typeof args !== "object") return ""
  return [args.command, args.cmd, args.input, args.script].find(
    (value) => typeof value === "string" && value.trim().length > 0,
  ) ?? ""
}

export const WriteGuardPlugin: Plugin = async (input) => {
  return {
    "permission.ask": async (request, output) => {
      if (request.type !== "edit") return
      const blocked = permissionPatterns(request).filter(
        (candidate) => !isAllowedPlanPath(candidate, input.worktree),
      )
      if (blocked.length > 0) output.status = "deny"
    },

    "tool.execute.before": async (request, output) => {
      if (GUARDED_TOOLS.has(request.tool)) {
        const candidates = collectPathCandidates(output.args)
        const patchText = output.args?.patchText
        if (typeof patchText === "string" && patchText.trim().length > 0) {
          collectPatchTargets(patchText, candidates)
        }

        const blocked = [...candidates].filter(
          (candidate) => !isAllowedPlanPath(candidate, input.worktree),
        )
        if (blocked.length > 0) {
          throw new Error(
            `write-guard blocked edit outside .ia-refactor/plan/YYYYMMDD/<target>.md: ${blocked.join(", ")}`,
          )
        }
      }

      if (request.tool === "bash") {
        const command = extractShellCommand(output.args)
        const blocked = collectRedirectionTargets(command).filter(
          (candidate) => !isAllowedPlanPath(candidate, input.worktree),
        )
        if (blocked.length > 0) {
          throw new Error(
            `write-guard blocked shell redirection outside allowed plan path: ${blocked.join(", ")}`,
          )
        }
      }
    },
  }
}

export default {
  id: "write-guard",
  server: WriteGuardPlugin,
}
