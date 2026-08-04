import assert from "node:assert/strict"
import { execFileSync } from "node:child_process"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { sddSwarmContracts } from "../domains/sdd/plugins/sdd-swarm.ts"

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const FIXTURE_TASKS = path.join(
  ROOT,
  "scripts/fixtures/sdd-swarm/java-checkout/state-seeds/swarm-change/ai/orchestrator/changes/parallel-checkout/tasks.md",
)

function shouldBuildFourWorkerWaveWhenGroupsAreIndependent(): void {
  // Given
  const markdown = fs.readFileSync(FIXTURE_TASKS, "utf8")

  // When
  const plan = sddSwarmContracts.parseTasks(markdown, "fixture/tasks.md")

  // Then
  assert.deepEqual(plan.waves, [["1", "2", "3", "4"], ["5"], ["6"]])
  assert.equal(plan.groups.find((group) => group.id === "6")?.touches_hotspot, true)
}

function shouldSerializeLegacyGroupsWhenDependenciesAreMissing(): void {
  // Given
  const markdown = `# Tasks: Legacy
Shared hotspots: none
## 1. First
Files: src/first/
- [ ] 1.1 First task
## 2. Second
Files: src/second/
- [ ] 2.1 Second task
`

  // When
  const plan = sddSwarmContracts.parseTasks(markdown)

  // Then
  assert.deepEqual(plan.waves, [["1"], ["2"]])
  assert.match(plan.warnings.join("\n"), /serialized in document order/)
}

function shouldSerializeOverlappingScopesWhenDependenciesAreExplicit(): void {
  // Given
  const markdown = `# Tasks: Overlap
Shared hotspots: none
## 1. First
Files: src/shared/
Depends on: none
- [ ] 1.1 First task
## 2. Second
Files: src/shared/Thing.java
Depends on: none
- [ ] 2.1 Second task
`

  // When
  const plan = sddSwarmContracts.parseTasks(markdown)

  // Then
  assert.deepEqual(plan.waves, [["1"], ["2"]])
}

function shouldSerializeIntrinsicHotspotsWithoutPromptInference(): void {
  // Given
  const markdown = `# Tasks: Intrinsic hotspots
Shared hotspots: none
## 1. Manifest
Files: pom.xml
Depends on: none
- [ ] 1.1 Change dependencies
## 2. Source
Files: src/main/java/com/example/feature/
Depends on: none
- [ ] 2.1 Add feature
`

  // When
  const plan = sddSwarmContracts.parseTasks(markdown)

  // Then
  assert.deepEqual(plan.waves, [["1"], ["2"]])
  assert.match(plan.warnings.join("\n"), /manifest, registry, fixture, or generated-code hotspot/)
}

function shouldDenyNestedSwarmToolsInWorkerContract(): void {
  // Given
  const worker = fs.readFileSync(path.join(ROOT, "domains/sdd/agents/sdd-swarm-worker.md"), "utf8")

  // When / Then
  assert.match(worker, /^  task: deny$/m)
  assert.match(worker, /^  sdd_swarm: deny$/m)
  assert.match(worker, /^    "git push\*": deny$/m)
}

function shouldUseSddSwarmNamespaceWhenNamingRuntimeBranches(): void {
  // Given
  const runId = "20260804t120000-a1b2c3"

  // When
  const prefix = sddSwarmContracts.runBranchPrefix(runId)

  // Then
  assert.equal(prefix, "sdd-swarm/20260804t120000-a1b2c3")
}

function shouldParseReceiptWhenEvidenceMatchesContract(): void {
  // Given
  const receipt = `wave: "1"
tasks_done: ["1.1"]
assertions:
  - "1.1 -> src/main/App.java:12"
files_changed: ["src/main/App.java"]
out_of_scope: []
validation: "pass"
commit: "abcdef1"
blockers: []`

  // When
  const parsed = sddSwarmContracts.parseReceipt(receipt)

  // Then
  assert.deepEqual(parsed, {
    wave: "1",
    tasksDone: ["1.1"],
    assertions: [{ task: "1.1", file: "src/main/App.java", line: 12 }],
    filesChanged: ["src/main/App.java"],
    outOfScope: [],
    validation: "pass",
    commit: "abcdef1",
    blockers: [],
  })
}

function shouldReturnZeroEfficiencyWhenMeasurementIsIncomplete(): void {
  // Given
  const missingCost = 0

  // When
  const score = sddSwarmContracts.efficiencyScore(100, 50, 10, missingCost)

  // Then
  assert.equal(score, 0)
  assert.equal(sddSwarmContracts.efficiencyScore(100, 50, 10, 10), Math.sqrt(2))
}

function shouldMatchFilesInsideDirectoryAndGlobScopes(): void {
  // Given
  const directoryScopes = ["src/main/java/", "src/test/**/*.java"]

  // When / Then
  assert.equal(sddSwarmContracts.pathInScopes("src/main/java/com/example/App.java", directoryScopes), true)
  assert.equal(sddSwarmContracts.pathInScopes("README.md", directoryScopes), false)
}

async function shouldAbortCherryPickWhenIntegrationConflicts(): Promise<void> {
  // Given
  const repository = fs.mkdtempSync(path.join(os.tmpdir(), "sdd-swarm-conflict."))
  const git = (...args: string[]) => execFileSync("git", args, { cwd: repository, encoding: "utf8" }).trim()
  try {
    git("init", "-q", "-b", "main")
    git("config", "user.name", "sdd-swarm-contracts")
    git("config", "user.email", "sdd-swarm-contracts@example.invalid")
    fs.writeFileSync(path.join(repository, "shared.txt"), "base\n")
    git("add", "shared.txt")
    git("commit", "-qm", "baseline")
    git("switch", "-qc", "worker")
    fs.writeFileSync(path.join(repository, "shared.txt"), "worker\n")
    git("commit", "-qam", "worker change")
    const workerCommit = git("rev-parse", "HEAD")
    git("switch", "-q", "main")
    fs.writeFileSync(path.join(repository, "shared.txt"), "integration\n")
    git("commit", "-qam", "integration change")

    // When / Then
    await assert.rejects(
      sddSwarmContracts.cherryPickCommit(repository, repository, workerCommit, "contract group"),
      /cherry-pick conflict for contract group/,
    )
    assert.equal(git("status", "--porcelain"), "")
  } finally {
    fs.rmSync(repository, { recursive: true, force: true })
  }
}

shouldBuildFourWorkerWaveWhenGroupsAreIndependent()
shouldSerializeLegacyGroupsWhenDependenciesAreMissing()
shouldSerializeOverlappingScopesWhenDependenciesAreExplicit()
shouldSerializeIntrinsicHotspotsWithoutPromptInference()
shouldDenyNestedSwarmToolsInWorkerContract()
shouldUseSddSwarmNamespaceWhenNamingRuntimeBranches()
shouldParseReceiptWhenEvidenceMatchesContract()
shouldReturnZeroEfficiencyWhenMeasurementIsIncomplete()
shouldMatchFilesInsideDirectoryAndGlobScopes()
await shouldAbortCherryPickWhenIntegrationConflicts()

console.log("PASS: sdd-swarm TypeScript contracts")
