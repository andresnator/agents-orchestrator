import assert from 'node:assert/strict'
import { execFile, spawn } from 'node:child_process'
import { once } from 'node:events'
import { cp, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'
import { test } from 'node:test'
import { learningRuntimeContracts as runtime } from '../../../domains/learning/plugins/learning-runtime.ts'

const FIXTURES = dirname(fileURLToPath(import.meta.url))
const run = promisify(execFile)
const DATE = '2026-09-14'
const PIPE_TIMEOUT_MS = 2000
const CONTEXT = { agent: 'mentor', sessionID: 'synthetic-parent', messageID: 'synthetic-assistant', abort: new AbortController().signal }
const PRACTICAL_GOAL = 'Implement a plugin and incorporate it in a local and remote integration project.'
const PRACTICAL_WINS = ['Implement, activate, diagnose and disable a real plugin.', 'Incorporate a personal plugin in the integration project.']

test('shouldReleaseCapturedPipesWhileLiveLockStillBlocksRecovery', async (t) => {
  // Given
  const root = await prepare(t, 'STATE-RECOVERY')
  const variant = join(root, 'live_lock')
  const project = join(variant, 'project')
  const statePath = join(project, '.ai/learning/http-cache-validation/.state.json')
  const before = await readFile(statePath, 'utf8')
  const child = spawn('python3', [join(FIXTURES, 'fault.py'), variant, 'live-lock'], { stdio: ['pipe', 'pipe', 'pipe'] })
  const closed = once(child, 'close')
  child.stdin.end()
  let owner
  t.after(async () => {
    if (owner) process.kill(owner.pid, 'SIGTERM')
    await closed
  })

  // When: helper exit alone does not imply EOF on its captured descriptors.
  const [code] = await once(child, 'exit')
  assert.equal(code, 0)
  owner = JSON.parse(await readFile(join(variant, 'evidence/lock-owner.json'), 'utf8'))
  let timer
  try {
    await Promise.race([closed, new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('live-lock child retained captured pipes')), PIPE_TIMEOUT_MS)
    })])
  } finally {
    clearTimeout(timer)
  }

  // Then: the holder is still alive and prevents writes until explicitly stopped.
  const store = runtime.createStateStore(project)
  await assert.rejects(store.recover('http-cache-validation'), /topic_busy/)
  assert.equal(await readFile(statePath, 'utf8'), before)
})

test('shouldStartPriorKnowledgeOnPluginTheoryWithoutInventingClassOrPractice', async (t) => {
  // Given
  const root = await prepare(t, 'FLEXIBLE-PATH')
  const initial = await runtime.createStateStore(join(root, 'prior/project')).read('plugin-security')
  assert.equal(initial.modules.length, 1)
  assert.equal(initial.modules[0].phase, 'mission')
  assert.match(initial.topic.goal, /^Explain .*plugin/i)
  assert.match(initial.modules[0].win, /^Explain .*plugin/i)
  const subject = { topic_slug: initial.topic.slug, module_id: 'M-0001' }
  const choice = answeredChoice(initial, 'readiness', subject, 'skip')

  // When: consent is synthetic contract input, not live native UI evidence.
  const { state } = runtime.applyLearningEvent(initial, initial.topic.slug, {
    type: 'skip_practice', event_id: 'SKIP-PRIOR', date: DATE, module_id: 'M-0001', interaction_id: choice.id,
  }, choice)

  // Then
  assert.deepEqual(state.modules, [{ ...initial.modules[0], phase: 'consolidation', practice_skipped: true }])
  assert.deepEqual({ taught: state.concepts[0].taught, taught_ids: state.modules[0].taught_concept_ids,
    class_evidence: state.modules[0].class_evidence, attempt: state.modules[0].attempt,
    consolidation: state.modules[0].consolidation, artifacts: state.artifacts, evidence: state.verified_evidence },
  { taught: false, taught_ids: [], class_evidence: undefined, attempt: undefined, consolidation: undefined, artifacts: {}, evidence: undefined })
})

test('shouldRetirePracticalRequirementsAndPreserveThemInScopeHistory', async (t) => {
  // Given
  const root = await prepare(t, 'FLEXIBLE-PATH')
  const project = join(root, 'base/project')
  const initial = await runtime.createStateStore(project).read('plugin-security')
  assert.deepEqual({ goal: initial.topic.goal, wins: initial.modules.map(module => module.win) },
    { goal: PRACTICAL_GOAL, wins: PRACTICAL_WINS })
  const proposal = {
    goal: 'Explain plugins theoretically and coordinate local and remote work.',
    modules: [
      { id: 'M-0001', title: 'Plugin theory', win: 'Explain the plugin contract and safe activation decisions.' },
      { id: 'M-0002', title: 'Integration', win: 'Coordinate local and remote work without a plugin implementation.' },
    ],
    reason: 'Synthetic scope reduction for fixture validation.',
    retired_requirements: PRACTICAL_WINS,
  }
  const before = { goal: initial.topic.goal, modules: initial.modules.map(({ id, title, win }) => ({ id, title, win })) }
  const choice = answeredChoice(initial, 'scope_revision', {
    topic_slug: initial.topic.slug, before, after: { goal: proposal.goal, modules: proposal.modules },
    reason: proposal.reason, retired_requirements: proposal.retired_requirements,
  }, 'apply')

  // When: exercise the contract with synthetic consent, then load the persisted result.
  const event = { ...proposal, type: 'revise_scope', event_id: 'SCOPE-FIXTURE', date: DATE, interaction_id: choice.id }
  const { state } = runtime.applyLearningEvent(initial, initial.topic.slug, event, choice)
  await writeFile(join(project, '.ai/learning/plugin-security/.state.json'), JSON.stringify(state))
  const resumed = await runtime.createStateStore(project).read('plugin-security')

  // Then
  assert.deepEqual(resumed.scope_revisions, [{ ...proposal,
    before: { ...before, modules: initial.modules.map(({ id, title, win, consolidation }) => ({ id, title, win, ...(consolidation ? { consolidation } : {}) })) },
    revision: initial.revision + 1, event_id: event.event_id, date: DATE, interaction_id: choice.id }])
  assert.deepEqual(resumed.modules.map(({ id, title, win }) => ({ id, title, win })), proposal.modules)
  assert.deepEqual(resumed.modules[0].consolidation, initial.modules[0].consolidation)
  assert.equal(resumed.modules[0].attempt, undefined)
  const views = runtime.renderViews(resumed)
  for (const requirement of PRACTICAL_WINS) assert.ok(views['mission.md'].includes(requirement))
})

test('shouldRejectCachePriorEvenWhenItsManifestClaimsMission', async (t) => {
  // Given: recreate the old mismatch, including its self-consistent kind label.
  const root = await prepare(t, 'FLEXIBLE-PATH')
  const cache = await prepare(t, 'MODULE-DELIVERY')
  const manifest = JSON.parse(await readFile(join(root, 'manifest.json'), 'utf8'))
  manifest.variants.prior = 'mission'
  await writeFile(join(root, 'manifest.json'), JSON.stringify(manifest))
  await rm(join(root, 'prior/project'), { recursive: true })
  await cp(join(cache, 'base/project'), join(root, 'prior/project'), { recursive: true })

  // When / Then
  await assert.rejects(run('node', [join(FIXTURES, 'validate.mjs'), root]), /FLEXIBLE-PATH prior requires plugin-mission/)
})

test('shouldRejectTheoryOnlyGoalOrWinsInFlexibleStartingState', async (t) => {
  // Given
  const root = await prepare(t, 'FLEXIBLE-PATH')
  const path = join(root, 'base/project/.ai/learning/plugin-security/.state.json')
  const initial = JSON.parse(await readFile(path, 'utf8'))

  // When / Then: each required practical boundary is independently checked.
  for (const field of ['goal', 'current-win', 'downstream-win']) {
    const changed = structuredClone(initial)
    if (field === 'goal') changed.topic.goal = 'Explain safe plugin activation decisions and local and remote integration.'
    if (field === 'current-win') changed.modules[0].win = 'Explain plugin contracts and safe activation decisions.'
    if (field === 'downstream-win') changed.modules[1].win = 'Explain how the plugin decision affects local and remote integration.'
    await writeFile(path, JSON.stringify(changed))
    await assert.rejects(run('node', [join(FIXTURES, 'validate.mjs'), root]), /practical/)
  }
})

async function prepare(t, id) {
  const scratch = await mkdtemp(join(tmpdir(), 'learning-fixture-regression-'))
  t.after(() => rm(scratch, { recursive: true, force: true }))
  const root = join(scratch, id)
  await run('python3', [join(FIXTURES, 'prepare.py'), id, root, '--date', DATE])
  return root
}

function answeredChoice(state, purpose, subject, selected) {
  const options = purpose === 'readiness' ? ['ready', 'skip'] : ['apply', 'revise', 'cancel']
  const choice = runtime.createInteractions().stage(CONTEXT, {
    purpose, revision: state.revision, subject_json: JSON.stringify(subject), question: 'Synthetic fixture choice?',
    options: options.map(id => ({ id, label: id, description: 'Synthetic selection' })),
  })
  return { ...choice, status: 'answered', requestID: 'synthetic-request', selected: [selected] }
}
