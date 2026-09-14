// Validate copied snapshots using the checkout's actual reader and regenerate views.
import assert from 'node:assert/strict'
import { readdir, readFile, writeFile, mkdir } from 'node:fs/promises'
import { join, dirname, resolve } from 'node:path'
import { learningRuntimeContracts as runtime } from '../../../domains/learning/plugins/learning-runtime.ts'

const root = resolve(process.argv[2])
const manifest = JSON.parse(await readFile(join(root, 'manifest.json'), 'utf8'))

const TOPIC_PROFILES = {
  cache: {
    slug: 'http-cache-validation',
    title: /HTTP cache validation/i,
    goal: /cached response|revalidated|refetched/i,
    concept: /freshness|validation/i,
    module: /freshness|validation/i,
    win: /freshness|validation/i,
  },
  pizza: {
    slug: 'pizza',
    title: /pizza dough fermentation/i,
    goal: /fermentation.*pizza dough|pizza dough.*fermentation/i,
    concept: /fermentation.*dough|dough.*structure/i,
    module: /fermentation.*pizza dough|pizza dough.*fermentation/i,
    win: /fermentation.*pizza dough|pizza dough.*decision/i,
  },
  language: {
    slug: 'airport',
    title: /airport check-in english/i,
    goal: /airport check-in.*english|english.*airport check-in/i,
    concept: /airport check-in.*communication|check-in.*communication/i,
    module: /check in for a flight|airport check-in/i,
    win: /airport check-in.*exchange|check-in.*exchange/i,
  },
  plugin: {
    slug: 'plugin-security',
    title: /plugin security and integration/i,
    goal: /plugin.*activation|local and remote integration/i,
    concept: /plugin.*safe activation|safe activation/i,
    module: /plugin theory/i,
    win: /plugin.*safe activation/i,
  },
}

function assertTopicProfile(kind, state) {
  const profile = kind === 'pizza' ? TOPIC_PROFILES.pizza : kind.startsWith('language') ? TOPIC_PROFILES.language : kind === 'flexible' ? TOPIC_PROFILES.plugin : TOPIC_PROFILES.cache
  assert.equal(state.topic.slug, profile.slug)
  assert.match(state.topic.title, profile.title)
  assert.match(state.topic.goal, profile.goal)
  assert.match(state.concepts[0].title, profile.concept)
  assert.match(state.modules[0].title, profile.module)
  assert.match(state.modules[0].win, profile.win)
  if (kind.startsWith('language')) {
    assert.equal(state.topic.target_language, 'English')
    assert.equal(state.topic.native_language, 'Spanish')
    assert.equal(state.topic.production_required, true)
    assert.ok(state.language_units.length > 0)
    assert.ok(state.language_units.every((unit) => /check[- ]in/i.test(unit.situation) && /check[- ]in/i.test(unit.target_text) && /facturar/i.test(unit.native_text)))
  }
  // Legacy compatibility deliberately carries a historical language unit in
  // the cache topic; its curriculum profile remains the cache profile.
  if (!kind.startsWith('language') && !kind.startsWith('legacy') && kind !== 'pizza') {
    assert.equal(state.topic.target_language, undefined)
    assert.equal(state.topic.native_language, undefined)
  }
}

let count = 0
for (const variant of Object.keys(manifest.variants)) {
  const project = join(root, variant, 'project')
  const topics = await readdir(join(project, '.ai/learning')).catch(error => {
    if (error.code === 'ENOENT') return []
    throw error
  })
  for (const slug of topics) {
    const state = await runtime.createStateStore(project).read(slug)
    assertTopicProfile(manifest.variants[variant], state)
    for (const [path, content] of Object.entries(runtime.renderViews(state))) {
      const target = join(project, '.ai/learning', slug, path)
      await mkdir(dirname(target), { recursive: true })
      await writeFile(target, content)
    }
    count++
  }
}
console.log(JSON.stringify({ case: manifest.case_id, validated_snapshots: count, layer: 'fixture-only' }))
