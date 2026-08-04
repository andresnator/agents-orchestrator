import fs from "node:fs"
import path from "node:path"

type BenchmarkRow = {
  arm: "single" | "swarm-same" | "swarm-tiered"
  repetition: number
  correct: boolean
  wall_ms: number
  cost: number
  tokens: number
  model: string
  supervisor_model?: string
  worker_ms: number
  integration_ms: number
  verified_groups: number
  retries: number
  timeouts: number
  conflicts: number
  out_of_scope: number
}

const [resultsPath, reportPath] = process.argv.slice(2)
if (!resultsPath || !reportPath) throw new Error("usage: sdd-swarm-benchmark-report.ts <results.jsonl> <report.md>")

const rows = fs.readFileSync(resultsPath, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line) as BenchmarkRow)
const expectedArms = ["single", "swarm-same", "swarm-tiered"] as const
for (const arm of expectedArms) {
  const repetitions = rows.filter((row) => row.arm === arm).map((row) => row.repetition).sort()
  if (JSON.stringify(repetitions) !== JSON.stringify([1, 2, 3])) {
    throw new Error(`benchmark requires exactly repetitions 1, 2, and 3 for ${arm}`)
  }
}

function median(values: number[]): number {
  const sorted = [...values].sort((left, right) => left - right)
  if (sorted.length === 0) return 0
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

function pairedUnits(baseline: BenchmarkRow, arm: BenchmarkRow): { baseline: number; arm: number } {
  if (baseline.cost > 0 && arm.cost > 0) return { baseline: baseline.cost, arm: arm.cost }
  return { baseline: baseline.tokens, arm: arm.tokens }
}

function efficiency(row: BenchmarkRow): number {
  if (!row.correct) return 0
  const baseline = rows.find((candidate) => candidate.arm === "single" && candidate.repetition === row.repetition)
  if (!baseline?.correct) return 0
  const units = pairedUnits(baseline, row)
  if (baseline.wall_ms <= 0 || row.wall_ms <= 0 || units.baseline <= 0 || units.arm <= 0) return 0
  return Math.sqrt((baseline.wall_ms / row.wall_ms) * (units.baseline / units.arm))
}

function decision(score: number, correct: number, baselineCorrect: number): string {
  if (baselineCorrect !== 3) return "DO NOT PROMOTE — the control arm was not correct 3/3"
  if (correct !== 3) return "DO NOT PROMOTE — correctness was not 3/3"
  if (score >= 1.25) return "PROMOTE TO A CONTROLLED PILOT"
  if (score >= 1) return "INCONCLUSIVE — efficiency is between 1.00x and 1.24x"
  return "DO NOT PROMOTE — efficiency is below the single-agent baseline"
}

const lines = [
  "# OpenCode SDD Swarm Benchmark",
  "",
  `Generated: ${new Date().toISOString()}`,
  "",
  "Efficiency uses provider-reported USD only when both paired runs report cost; otherwise it uses tokens for both runs. A failed correctness gate scores zero.",
  "",
  "## Configuration",
  "",
  "- Repetitions: 3 fresh repositories per arm, with rotated arm order.",
  `- Single-agent model: ${process.env.SDD_SWARM_SINGLE_MODEL ?? process.env.SDD_SWARM_SAME_MODEL ?? "not recorded"}.`,
  `- Same-model supervisor/workers: ${process.env.SDD_SWARM_SAME_MODEL ?? "not recorded"}.`,
  `- Tiered supervisor: ${process.env.SDD_SWARM_TIERED_SUPERVISOR_MODEL ?? "not recorded"}.`,
  `- Tiered workers: ${process.env.SDD_SWARM_TIERED_WORKER_MODEL ?? "not recorded"}.`,
  `- Maximum approved provider cost: USD ${process.env.SDD_SWARM_MAX_COST_USD ?? "not recorded"}.`,
  "- Correctness gate: fixture golden verification after all implementation commits.",
  "",
  "## Results",
  "",
  "Verified work means fixture task groups that passed the golden gate. Verified/unit uses USD when the row reports provider cost, otherwise tokens.",
  "",
  "| Arm | Correct | Median wall | Worker phase | Integration phase | Median USD | Median tokens | Groups/min | Groups/unit | Efficiency | Decision |",
  "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
]

const baselineCorrect = rows.filter((row) => row.arm === "single" && row.correct).length
for (const arm of expectedArms) {
  const armRows = rows.filter((row) => row.arm === arm)
  const scores = arm === "single" ? armRows.map(() => 1) : armRows.map(efficiency)
  const score = median(scores)
  const correct = armRows.filter((row) => row.correct).length
  const groupsPerMinute = armRows.map((row) => row.wall_ms > 0 ? row.verified_groups / (row.wall_ms / 60_000) : 0)
  const groupsPerUnit = armRows.map((row) => {
    const units = row.cost > 0 ? row.cost : row.tokens
    return units > 0 ? row.verified_groups / units : 0
  })
  lines.push(
    `| ${arm} | ${correct}/3 | ${(median(armRows.map((row) => row.wall_ms)) / 1_000).toFixed(2)}s | ${(median(armRows.map((row) => row.worker_ms)) / 1_000).toFixed(2)}s | ${(median(armRows.map((row) => row.integration_ms)) / 1_000).toFixed(2)}s | ${median(armRows.map((row) => row.cost)).toFixed(6)} | ${Math.round(median(armRows.map((row) => row.tokens)))} | ${median(groupsPerMinute).toFixed(2)} | ${median(groupsPerUnit).toFixed(6)} | ${score.toFixed(2)}x | ${arm === "single" ? "CONTROL" : decision(score, correct, baselineCorrect)} |`,
  )
}

lines.push("", "## Raw runs", "", "| Arm | Rep | Correct | Wall | Workers | Integration | USD | Tokens | Retry | Timeout | Conflict | Scope | Models |", "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
for (const row of rows) {
  const models = row.supervisor_model ? `${row.supervisor_model} -> ${row.model}` : row.model
  lines.push(`| ${row.arm} | ${row.repetition} | ${row.correct ? "yes" : "no"} | ${(row.wall_ms / 1_000).toFixed(2)}s | ${(row.worker_ms / 1_000).toFixed(2)}s | ${(row.integration_ms / 1_000).toFixed(2)}s | ${row.cost.toFixed(6)} | ${row.tokens} | ${row.retries} | ${row.timeouts} | ${row.conflicts} | ${row.out_of_scope} | ${models} |`)
}

lines.push(
  "",
  "## Limitations",
  "",
  "- Provider and model variance remains material even with rotated order and three repetitions.",
  "- A cost check occurs after each completed run, so the in-flight run can cross the approved USD budget.",
  "- Worktrees isolate files and indexes, not Git refs, caches, ports, services, databases, or provider rate limits.",
  "- The Java fixture is deliberately parallelizable; results do not transfer automatically to dependency-heavy production changes.",
  "- Integration and full validation remain serial and bound maximum speedup.",
)

fs.mkdirSync(path.dirname(reportPath), { recursive: true })
fs.writeFileSync(reportPath, `${lines.join("\n")}\n`)
console.log(reportPath)
