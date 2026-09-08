import { readFile, realpath } from "node:fs/promises"
import { homedir } from "node:os"
import { isAbsolute, join, relative, resolve, sep } from "node:path"
import { pathToFileURL } from "node:url"
import type { Plugin } from "@opencode-ai/plugin"

const PLUGIN_ID = "recall-calc"
const MAX_BOX = 5
const BOX_INTERVAL_DAYS: Record<number, number> = { 1: 1, 2: 3, 3: 7, 4: 14, 5: 30 }
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/
const CARD_ID = /^C-\d+$/
const SOURCE_REFERENCE = /^(?:K-\d{4}@r\d+|(?:notes|exercises|teachbacks|dialogues)\/[a-z0-9][a-z0-9._-]*\.md)$/
const SECTION_HEADING = /^##\s+/
const QUEUE_HEADING = /^##\s+Queue\s*$/i
const HEADER_ID_CELL = "ID"
const SEPARATOR_CELL = /^:?-{3,}:?$/
const GRADES = ["New", "Again", "Hard", "Good", "Easy"] as const
const MAX_QUEUE_BYTES = 1_000_000

type Grade = (typeof GRADES)[number]

interface QueueCard {
  id: string
  cue: string
  box: number
  last: string
  next: string
  note: string
}

interface ParsedQueue {
  cards: QueueCard[]
  malformed: string[]
}

interface DueReport {
  today: string
  scheduled: number
  due_count: number
  due: QueueCard[]
  next_upcoming: string | null
  malformed: string[]
}

interface Transition {
  grade: Grade
  from_box: number | null
  to_box: number | null
  last: string
  next: string | null
}

function isIsoDate(value: string): boolean {
  if (!ISO_DATE.test(value)) return false
  const [y, m, d] = value.split("-").map(Number)
  const parsed = new Date(Date.UTC(y, m - 1, d))
  return parsed.getUTCFullYear() === y && parsed.getUTCMonth() === m - 1 && parsed.getUTCDate() === d
}

// All date arithmetic is done in UTC on noon-free date-only values so month,
// year, and DST boundaries can never shift the result.
function addDays(date: string, days: number): string {
  if (!isIsoDate(date)) throw new Error(`invalid date: ${date}`)
  const [y, m, d] = date.split("-").map(Number)
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10)
}

function localToday(now: Date = new Date()): string {
  const y = now.getFullYear()
  const m = String(now.getMonth() + 1).padStart(2, "0")
  const d = String(now.getDate()).padStart(2, "0")
  return `${y}-${m}-${d}`
}

function splitMarkdownRow(line: string): string[] {
  const cells: string[] = []
  let cell = ""
  let escaped = false
  for (const character of line.slice(1, -1)) {
    if (escaped) {
      cell += character === "|" ? "|" : `\\${character}`
      escaped = false
    } else if (character === "\\") {
      escaped = true
    } else if (character === "|") {
      cells.push(cell.trim())
      cell = ""
    } else {
      cell += character
    }
  }
  if (escaped) cell += "\\"
  cells.push(cell.trim())
  return cells
}

function parseQueue(markdown: string): ParsedQueue {
  const cards: QueueCard[] = []
  const malformed: string[] = []
  const seen = new Set<string>()
  let activeSection = true
  for (const raw of markdown.split("\n")) {
    const line = raw.trim()
    if (SECTION_HEADING.test(line)) {
      activeSection = QUEUE_HEADING.test(line)
      continue
    }
    if (!activeSection) continue
    if (!line.startsWith("|")) continue
    if (!line.endsWith("|")) {
      malformed.push(`${line} — missing trailing |`)
      continue
    }
    const cells = splitMarkdownRow(line)
    if (cells.length === 0) continue
    if (cells[0] === HEADER_ID_CELL || cells.every((cell) => SEPARATOR_CELL.test(cell))) continue
    if (cells.length !== 6) {
      malformed.push(`${line} — expected 6 cells, got ${cells.length}`)
      continue
    }
    const [id, cue, boxCell, last, next, note] = cells
    const reasons: string[] = []
    if (!CARD_ID.test(id)) reasons.push(`bad card id "${id}"`)
    if (!cue) reasons.push("empty cue")
    if (!SOURCE_REFERENCE.test(note)) reasons.push(`bad source reference "${note}"`)
    const box = Number(boxCell)
    if (!Number.isInteger(box) || box < 1 || box > MAX_BOX) reasons.push(`box must be an integer 1-${MAX_BOX}`)
    if (!isIsoDate(last)) reasons.push(`bad Last date "${last}"`)
    if (!isIsoDate(next)) reasons.push(`bad Next date "${next}"`)
    if (seen.has(id)) reasons.push(`duplicate card id "${id}"`)
    if (isIsoDate(last) && isIsoDate(next) && Number.isInteger(box) && box >= 1 && box <= MAX_BOX) {
      const expected = addDays(last, BOX_INTERVAL_DAYS[box])
      if (next !== expected) reasons.push(`Next must equal Last + ${BOX_INTERVAL_DAYS[box]}d (${expected})`)
    }
    if (CARD_ID.test(id)) seen.add(id)
    if (reasons.length > 0) {
      malformed.push(`${line} — ${reasons.join("; ")}`)
      continue
    }
    cards.push({ id, cue, box, last, next, note })
  }
  return { cards, malformed }
}

function dueReport(parsed: ParsedQueue, today: string): DueReport {
  if (!isIsoDate(today)) throw new Error(`invalid today: ${today}`)
  const due = parsed.cards
    .filter((card) => card.next <= today)
    .sort((a, b) => (a.next === b.next ? a.id.localeCompare(b.id) : a.next.localeCompare(b.next)))
  let upcoming: string | null = null
  for (const card of parsed.cards) {
    if (card.next > today && (upcoming === null || card.next < upcoming)) upcoming = card.next
  }
  return {
    today,
    scheduled: parsed.cards.length,
    due_count: due.length,
    due,
    next_upcoming: upcoming,
    malformed: parsed.malformed,
  }
}

function applyGrade(grade: Grade, box: number | undefined, today: string): Transition {
  if (!isIsoDate(today)) throw new Error(`invalid today: ${today}`)
  if (!GRADES.includes(grade)) throw new Error(`invalid grade: ${grade}`)
  if (grade === "New") {
    return { grade, from_box: null, to_box: 1, last: today, next: addDays(today, BOX_INTERVAL_DAYS[1]) }
  }
  if (box === undefined || !Number.isInteger(box) || box < 1 || box > MAX_BOX) {
    throw new Error(`box must be an integer 1-${MAX_BOX} for grade ${grade}`)
  }
  const to = grade === "Again" ? 1 : grade === "Hard" ? box : grade === "Good" ? box + 1 : Math.min(box + 2, MAX_BOX)
  const capped = Math.min(to, MAX_BOX)
  return { grade, from_box: box, to_box: capped, last: today, next: addDays(today, BOX_INTERVAL_DAYS[capped]) }
}

// The plugin loader treats every exported function as a plugin entrypoint, so
// the pure calculator surface is exported as one object for runtime consumers.
export const recallCalcContracts = {
  BOX_INTERVAL_DAYS,
  MAX_BOX,
  isIsoDate,
  addDays,
  localToday,
  parseQueue,
  dueReport,
  applyGrade,
}

async function loadTool(directory: string): Promise<typeof import("@opencode-ai/plugin").tool> {
  try {
    return (await import("@opencode-ai/plugin")).tool
  } catch { /* Symlinks resolve at the source; try the host's dependency roots. */ }
  const roots = [
    process.env.OPENCODE_CONFIG_DIR,
    join(directory, ".opencode"),
    join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "opencode"),
  ].filter((root): root is string => Boolean(root))
  for (const root of roots) {
    try {
      const packageRoot = join(root, "node_modules", "@opencode-ai/plugin")
      const manifest = JSON.parse(await readFile(join(packageRoot, "package.json"), "utf8"))
      const entry = manifest.exports?.["./tool"]?.import
      if (typeof entry !== "string" || !entry.startsWith("./") || entry.includes("..")) continue
      return (await import(pathToFileURL(join(packageRoot, entry)).href)).tool
    } catch { /* Only resolve the fixed host package, never a caller-supplied module. */ }
  }
  throw new Error("learning_tool_helper_unavailable: install @opencode-ai/plugin in the OpenCode config directory")
}

async function learningPath(directory: string, path: string): Promise<string> {
  const base = await realpath(directory)
  const root = await realpath(join(base, ".ai", "learning"))
  const target = await realpath(resolve(base, path))
  const inside = (parent: string, child: string) => {
    const part = relative(parent, child)
    return part !== "" && part !== ".." && !part.startsWith(`..${sep}`) && !isAbsolute(part)
  }
  if (!inside(base, root) || !inside(root, target)) throw new Error("source_outside_learning")
  return target
}

export const recallCalcHost = { loadTool, learningPath }

export const RecallCalcPlugin: Plugin = async ({ directory }) => {
  const tool = await loadTool(directory)
  const schema = tool.schema
  return {
    tool: {
      recall_due: tool({
        description:
          "Read-only due cards, upcoming date, and malformed rows. Path reads stay inside this project's .ai/learning; inline queues need no files.",
        args: {
          queue_path: schema.string().optional().describe("Path to a review-queue.md file (use this or queue, not both)"),
          queue: schema.string().optional().describe("Raw review-queue.md Markdown content (use this or queue_path, not both)"),
          today: schema.string().optional().describe("Today's date as YYYY-MM-DD; defaults to the system date"),
        },
        async execute(args, context) {
          if (args.queue_path !== undefined && args.queue !== undefined) {
            throw new Error("pass only one of queue_path or queue")
          }
          if (args.queue_path === undefined && args.queue === undefined) {
            throw new Error("pass queue_path or queue")
          }
          const today = args.today ?? localToday()
          const source = args.queue ?? (await readFile(await learningPath(context.directory, args.queue_path as string), "utf8"))
          if (Buffer.byteLength(source, "utf8") > MAX_QUEUE_BYTES) throw new Error("queue_too_large")
          return JSON.stringify(dueReport(parseQueue(source), today), null, 2)
        },
      }),
      recall_schedule: tool({
        description:
          "Deterministic Leitner transitions for the learning domain: given cards with their current box and a grade (New, Again, Hard, Good, Easy) plus today's date, return each card's new box, Last, and Next. This tool performs no writes.",
        args: {
          cards: schema
            .array(
              schema.object({
                id: schema.string().optional().describe("Card ID, echoed back unchanged (e.g. C-0012)"),
                box: schema.number().optional().describe("Current Leitner box 1-5; omit for grade New"),
                grade: schema.enum(GRADES).describe("New, Again, Hard, Good, or Easy"),
              }),
            )
            .min(1)
            .describe("Cards to schedule"),
          today: schema.string().optional().describe("Today's date as YYYY-MM-DD; defaults to the system date"),
        },
        async execute(args) {
          const today = args.today ?? localToday()
          const transitions = args.cards.map((card) => ({
            ...(card.id === undefined ? {} : { id: card.id }),
            ...applyGrade(card.grade, card.box, today),
          }))
          return JSON.stringify({ today, transitions }, null, 2)
        },
      }),
    },
  }
}

export default {
  id: PLUGIN_ID,
  server: RecallCalcPlugin,
}
