import crypto from "node:crypto"
import { existsSync } from "node:fs"
import fs from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

type SkillEntry = {
  name: string
  version: string
  status: string
  description: string
  path: string
  mtimeMs: number
  project: boolean
  compactRules: string[]
}

const FRONTMATTER_RE = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/
const MAX_RULE_LINES = 15

function scalar(frontmatter: string, key: string) {
  const lines = frontmatter.split(/\r?\n/)
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index]
    const direct = line.match(new RegExp(`^\\s*${key}:\\s*(.*)$`))
    if (!direct) continue

    const value = direct[1].trim()
    if (value === ">" || value === "|" || value === ">-" || value === "|-") {
      const block: string[] = []
      for (let next = index + 1; next < lines.length; next++) {
        if (!/^\s+/.test(lines[next])) break
        block.push(lines[next].trim())
      }
      return block.join(" ").trim()
    }
    return value.replace(/^["']|["']$/g, "").trim()
  }
  return ""
}

function triggerFrom(description: string) {
  const match = description.match(/Trigger:\s*([^.\n]+)/i)
  return (match?.[1] ?? description).replace(/\s+/g, " ").trim()
}

function firstSection(body: string, headings: string[]) {
  const lines = body.split(/\r?\n/)
  for (let index = 0; index < lines.length; index++) {
    const heading = lines[index].trim().toLowerCase()
    if (!headings.some((candidate) => heading === candidate.toLowerCase())) continue

    const out: string[] = []
    for (let next = index + 1; next < lines.length && out.length < MAX_RULE_LINES; next++) {
      if (/^##\s+/.test(lines[next])) break
      const value = lines[next].trim()
      if (value) out.push(value)
    }
    return out
  }
  return []
}

function fallbackRules(body: string) {
  const lines = body.split(/\r?\n/)
  const start = lines.findIndex((line) => /^#\s+/.test(line))
  return lines
    .slice(start >= 0 ? start + 1 : 0)
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 10)
}

async function parseSkill(file: string, project: boolean): Promise<SkillEntry | undefined> {
  const text = await fs.readFile(file, "utf8")
  const stat = await fs.stat(file)
  const match = text.match(FRONTMATTER_RE)
  const frontmatter = match?.[1] ?? ""
  const body = text.slice(match?.[0].length ?? 0)
  const name = scalar(frontmatter, "name") || path.basename(path.dirname(file))
  if (name === "skill-registry") return undefined

  const compactRules =
    firstSection(body, ["## Rules", "## Hard Rules", "## Critical Patterns"]) ??
    fallbackRules(body)

  return {
    name,
    version: scalar(frontmatter, "version") || "0.0.0",
    status: scalar(frontmatter, "status") || "",
    description: scalar(frontmatter, "description"),
    path: file,
    mtimeMs: stat.mtimeMs,
    project,
    compactRules: compactRules.length > 0 ? compactRules : fallbackRules(body),
  }
}

async function listSkillFiles(dir: string) {
  const out: string[] = []
  async function walk(current: string) {
    let entries
    try {
      entries = await fs.readdir(current, { withFileTypes: true })
    } catch {
      return
    }

    for (const entry of entries) {
      const full = path.join(current, entry.name)
      if (entry.isDirectory()) await walk(full)
      else if (entry.isFile() && entry.name === "SKILL.md") out.push(await fs.realpath(full))
    }
  }

  await walk(dir)
  return out
}

async function discoverSkills(worktree: string) {
  const home = os.homedir()
  const roots = [
    { dir: path.join(home, ".config/opencode/skills"), project: false },
    { dir: path.join(home, ".claude/skills"), project: false },
    { dir: path.join(worktree, ".opencode/skills"), project: true },
    { dir: path.join(worktree, ".claude/skills"), project: true },
    { dir: path.join(worktree, ".agents/skills"), project: true },
    { dir: path.join(worktree, "skills"), project: true },
  ]

  const byName = new Map<string, SkillEntry>()
  for (const root of roots) {
    for (const file of await listSkillFiles(root.dir)) {
      const skill = await parseSkill(file, root.project)
      if (!skill) continue
      const existing = byName.get(skill.name)
      if (!existing || (skill.project && !existing.project)) byName.set(skill.name, skill)
    }
  }
  return [...byName.values()].sort((a, b) => a.name.localeCompare(b.name))
}

async function conventionRows(worktree: string) {
  const conventionFiles = ["AGENTS.md", "CLAUDE.md", ".cursorrules", "GEMINI.md", "copilot-instructions.md"]
    .map((file) => path.join(worktree, file))
    .filter(fileExistsSync)

  const rows: string[] = []
  const seen = new Set<string>()
  for (const file of conventionFiles) {
    rows.push(`| ${path.basename(file)} | ${file} | Project convention file |`)
    seen.add(file)

    let text = ""
    try {
      text = await fs.readFile(file, "utf8")
    } catch {
      continue
    }

    for (const match of text.matchAll(/`([^`]+)`/g)) {
      const candidate = match[1]
      if (!candidate || candidate.includes("*") || candidate.includes("{")) continue
      const resolved = path.resolve(worktree, candidate)
      if (!resolved.startsWith(worktree) || seen.has(resolved) || !fileExistsSync(resolved)) continue
      seen.add(resolved)
      rows.push(`| ${path.basename(resolved)} | ${resolved} | Referenced by ${path.basename(file)} |`)
    }
  }
  return rows.join("\n")
}

async function renderRegistry(skills: SkillEntry[], worktree: string) {
  const userRows = skills
    .map((skill) => `| ${triggerFrom(skill.description) || "-"} | ${skill.name} | ${skill.path} |`)
    .join("\n")

  const compactRules = skills
    .map((skill) => {
      const rules = skill.compactRules.map((rule) => `- ${rule.replace(/^[-*]\s*/, "")}`).join("\n")
      return `### ${skill.name}\n${rules || "- No compact rules found."}`
    })
    .join("\n\n")

  const conventions = await conventionRows(worktree)

  return `# Skill Registry

Auto-generated — do not edit.

## User Skills

| Trigger | Skill | Path |
|---|---|---|
${userRows || "| - | - | - |"}

## Compact Rules

${compactRules || "_No skills found._"}

## Project Conventions

| File | Path | Notes |
|---|---|---|
${conventions || "| - | - | - |"}
`
}

function fileExistsSync(file: string) {
  return existsSync(file)
}

async function ensureInfoExclude(worktree: string) {
  const exclude = path.join(worktree, ".git/info/exclude")
  try {
    const text = await fs.readFile(exclude, "utf8")
    if (/(^|\n)\.atl\/?(\n|$)/.test(text)) return
    await fs.appendFile(exclude, text.endsWith("\n") ? ".atl/\n" : "\n.atl/\n")
  } catch {
    // Non-git worktrees are valid OpenCode projects; skip local exclude updates.
  }
}

async function generateRegistry(worktree: string) {
  const skills = await discoverSkills(worktree)
  const orderedHashInput = skills
    .map((skill) => `${skill.name}@${skill.version}@${skill.mtimeMs}`)
    .sort()
    .join("\n")
  const hash = crypto.createHash("sha256").update(orderedHashInput).digest("hex")
  const atlDir = path.join(worktree, ".atl")
  const hashFile = path.join(atlDir, "skill-registry.hash")
  const registryFile = path.join(atlDir, "skill-registry.md")

  await fs.mkdir(atlDir, { recursive: true })
  try {
    if ((await fs.readFile(hashFile, "utf8")).trim() === hash) return
  } catch {
    // Missing hash means the registry should be written.
  }

  await fs.writeFile(registryFile, await renderRegistry(skills, worktree), "utf8")
  await fs.writeFile(hashFile, `${hash}\n`, "utf8")
  await ensureInfoExclude(worktree)
}

export const SkillRegistryPlugin: Plugin = async (input) => {
  let failed = false
  const run = () =>
    generateRegistry(input.worktree).catch((error) => {
      failed = true
      console.error(`[skill-registry] ${error instanceof Error ? error.message : String(error)}`)
    })

  void run()

  return {
    "event": async () => {
      if (!failed) return
      failed = false
      void run()
    },
  }
}

export default {
  id: "skill-registry",
  server: SkillRegistryPlugin,
}
