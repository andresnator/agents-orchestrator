import assert from "node:assert/strict"
import fs from "node:fs/promises"
import os from "node:os"
import path from "node:path"
import { SkillRegistryPlugin, skillRegistryContracts } from "../domains/meta/plugins/skill-registry.ts"

const { discoverSkills, generateRegistry, ensureInfoExclude, migrateLegacyAtl } = skillRegistryContracts

// Guard: only run against the throwaway HOME/worktree that test-skill-registry.sh
// provisions, never against real user state.
const testRoot = process.env.SKILL_REGISTRY_TEST_ROOT ?? ""
if (!testRoot || !os.homedir().startsWith(testRoot)) {
  console.error("FAIL: run via scripts/test-skill-registry.sh; an isolated HOME under SKILL_REGISTRY_TEST_ROOT is required")
  process.exit(1)
}

let passed = 0

function pass(name: string): void {
  passed += 1
  console.log(`ok - ${name}`)
}

async function writeSkill(dir: string, name: string, description: string, version = "1.0.0"): Promise<void> {
  await fs.mkdir(dir, { recursive: true })
  await fs.writeFile(
    path.join(dir, "SKILL.md"),
    `---\nname: ${name}\ndescription: "${description}"\nlicense: MIT\nmetadata:\n  author: test\n  version: "${version}"\n  status: testing\n---\n\n# ${name}\n`,
    "utf8",
  )
}

async function exists(file: string): Promise<boolean> {
  try {
    await fs.stat(file)
    return true
  } catch {
    return false
  }
}

async function waitFor(cond: () => Promise<boolean> | boolean, what: string): Promise<void> {
  const deadline = Date.now() + 5000
  while (Date.now() < deadline) {
    if (await cond()) return
    await new Promise((resolve) => setTimeout(resolve, 25))
  }
  throw new Error(`timeout waiting for ${what}`)
}

const userSkillsDir = path.join(os.homedir(), ".config/opencode/skills")

async function shouldPreferProjectSkillsOverUserSkills(): Promise<void> {
  const worktree = path.join(testRoot, "wt-precedence")
  await writeSkill(path.join(userSkillsDir, "shared-skill"), "shared-skill", "Trigger: user copy.")
  await writeSkill(path.join(userSkillsDir, "user-only"), "user-only", "Trigger: user only.")
  await writeSkill(path.join(worktree, ".opencode/skills/shared-skill"), "shared-skill", "Trigger: project copy.")

  const skills = await discoverSkills(worktree)
  const shared = skills.filter((skill) => skill.name === "shared-skill")
  assert.equal(shared.length, 1)
  assert.equal(shared[0].project, true)
  assert.ok(shared[0].path.startsWith(worktree + path.sep))
  assert.equal(shared[0].description, "Trigger: project copy.")
  const userOnly = skills.find((skill) => skill.name === "user-only")
  assert.ok(userOnly)
  assert.equal(userOnly.project, false)
  pass("shouldPreferProjectSkillsOverUserSkills")
}

async function shouldTerminateAndDedupeSymlinkCycles(): Promise<void> {
  const worktree = path.join(testRoot, "wt-cycles")
  const skillsDir = path.join(worktree, "skills")
  await writeSkill(path.join(skillsDir, "looped"), "looped", "Trigger: cycle fixture.")
  // Cycle back to the scanned root plus a sibling alias to the same skill dir.
  await fs.symlink("../../skills", path.join(skillsDir, "looped", "back"))
  await fs.symlink("looped", path.join(skillsDir, "alias"))

  const skills = await discoverSkills(worktree)
  assert.equal(skills.filter((skill) => skill.name === "looped").length, 1)
  pass("shouldTerminateAndDedupeSymlinkCycles")
}

async function shouldSkipRewriteWhenHashUnchanged(): Promise<void> {
  const worktree = path.join(testRoot, "wt-hash")
  await writeSkill(path.join(worktree, ".opencode/skills/hash-probe"), "hash-probe", "Trigger: hash fixture.")
  const registryFile = path.join(worktree, ".ai/atl/skill-registry.md")

  await generateRegistry(worktree)
  assert.match(await fs.readFile(registryFile, "utf8"), /hash-probe/)

  await fs.writeFile(registryFile, "SENTINEL", "utf8")
  await generateRegistry(worktree)
  assert.equal(await fs.readFile(registryFile, "utf8"), "SENTINEL")

  await writeSkill(path.join(worktree, ".opencode/skills/hash-probe"), "hash-probe", "Trigger: hash fixture.", "1.0.1")
  await generateRegistry(worktree)
  assert.match(await fs.readFile(registryFile, "utf8"), /hash-probe/)
  pass("shouldSkipRewriteWhenHashUnchanged")
}

async function shouldMigrateLegacyAtlWithoutOverwrite(): Promise<void> {
  const migrated = path.join(testRoot, "wt-migrate")
  await fs.mkdir(path.join(migrated, ".atl"), { recursive: true })
  await fs.writeFile(path.join(migrated, ".atl/marker.txt"), "legacy\n", "utf8")
  await migrateLegacyAtl(migrated)
  assert.equal(await fs.readFile(path.join(migrated, ".ai/atl/marker.txt"), "utf8"), "legacy\n")
  assert.equal(await exists(path.join(migrated, ".atl")), false)

  const kept = path.join(testRoot, "wt-migrate-existing")
  await fs.mkdir(path.join(kept, ".atl"), { recursive: true })
  await fs.writeFile(path.join(kept, ".atl/legacy.txt"), "legacy\n", "utf8")
  await fs.mkdir(path.join(kept, ".ai/atl"), { recursive: true })
  await fs.writeFile(path.join(kept, ".ai/atl/existing.txt"), "existing\n", "utf8")
  await migrateLegacyAtl(kept)
  assert.equal(await fs.readFile(path.join(kept, ".ai/atl/existing.txt"), "utf8"), "existing\n")
  assert.equal(await exists(path.join(kept, ".ai/atl/legacy.txt")), false)
  assert.equal(await exists(path.join(kept, ".atl/legacy.txt")), true)
  pass("shouldMigrateLegacyAtlWithoutOverwrite")
}

async function shouldRetryGenerationAfterFailure(): Promise<void> {
  const worktree = path.join(testRoot, "wt-retry")
  await fs.mkdir(worktree, { recursive: true })
  // A regular file where the .ai directory belongs makes generation fail.
  await fs.writeFile(path.join(worktree, ".ai"), "blocker", "utf8")

  const errors: string[] = []
  const originalError = console.error
  console.error = (message: unknown) => {
    errors.push(String(message))
  }
  try {
    const hooks = await SkillRegistryPlugin({ worktree, directory: worktree } as never)
    await waitFor(() => errors.length > 0, "initial generation failure")
    assert.match(errors[0], /\[skill-registry\]/)

    await fs.rm(path.join(worktree, ".ai"))
    await hooks.event({ event: { type: "test" } } as never)
    await waitFor(() => exists(path.join(worktree, ".ai/atl/skill-registry.md")), "registry after retry")
  } finally {
    console.error = originalError
  }
  pass("shouldRetryGenerationAfterFailure")
}

async function shouldOwnExactGitInfoExcludeLine(): Promise<void> {
  const worktree = path.join(testRoot, "wt-exclude")
  await writeSkill(path.join(worktree, ".opencode/skills/exclude-probe"), "exclude-probe", "Trigger: exclude fixture.")
  const excludeFile = path.join(worktree, ".git/info/exclude")
  await fs.mkdir(path.dirname(excludeFile), { recursive: true })
  await fs.writeFile(excludeFile, "node_modules", "utf8")

  await generateRegistry(worktree)
  assert.equal(await fs.readFile(excludeFile, "utf8"), "node_modules\n.ai/\n")

  await ensureInfoExclude(worktree)
  assert.equal(await fs.readFile(excludeFile, "utf8"), "node_modules\n.ai/\n")

  const preOwned = path.join(testRoot, "wt-exclude-preowned")
  const preOwnedFile = path.join(preOwned, ".git/info/exclude")
  await fs.mkdir(path.dirname(preOwnedFile), { recursive: true })
  await fs.writeFile(preOwnedFile, ".ai/\n", "utf8")
  await ensureInfoExclude(preOwned)
  assert.equal(await fs.readFile(preOwnedFile, "utf8"), ".ai/\n")

  // Non-git worktrees must be a silent no-op.
  await ensureInfoExclude(path.join(testRoot, "wt-not-git"))
  pass("shouldOwnExactGitInfoExcludeLine")
}

await shouldPreferProjectSkillsOverUserSkills()
await shouldTerminateAndDedupeSymlinkCycles()
await shouldSkipRewriteWhenHashUnchanged()
await shouldMigrateLegacyAtlWithoutOverwrite()
await shouldRetryGenerationAfterFailure()
await shouldOwnExactGitInfoExcludeLine()

console.log(`PASS: ${passed} skill-registry plugin contract group(s)`)
