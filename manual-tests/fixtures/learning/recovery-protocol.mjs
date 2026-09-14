// Native host protocol with an executor-fed provider; no real model or learner score.
import assert from 'node:assert/strict'
import { spawn, execFile } from 'node:child_process'
import { once } from 'node:events'
import { createWriteStream } from 'node:fs'
import { readFile, writeFile, mkdir, rename } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { promisify } from 'node:util'

const fixtures = dirname(fileURLToPath(import.meta.url))
const source = resolve(fixtures, '../../..')
const root = resolve(process.argv[2])
const run = promisify(execFile)
const date = new Date().toISOString().slice(0, 10)
await run('python3', [join(fixtures, 'prepare.py'), 'LANGUAGE-PRACTICE', root, '--date', date])
const variant = join(root, 'one')
const project = join(variant, 'project')
const evidence = join(variant, 'evidence')
const providerRoot = join(variant, 'provider')
const configRoot = join(variant, 'config')
const env = { ...process.env, OPENCODE_CONFIG_DIR: configRoot, OPENCODE_DISABLE_PROJECT_CONFIG: 'true', OPENCODE_DISABLE_EXTERNAL_SKILLS: 'true', OPENCODE_DISABLE_CLAUDE_CODE: 'true', TMPDIR: join(variant, 'tmp') }
for (const name of ['CONFIG', 'DATA', 'STATE', 'CACHE']) env[`XDG_${name}_HOME`] = join(variant, `xdg/${name.toLowerCase()}`)
const processes = []
const observations = { layer: 'scripted-protocol', model: 'fixture/scripted', checks: [], sessions: [], processes }
const log = async (name, value) => writeFile(join(evidence, name + '.json'), JSON.stringify(value, null, 2) + '\n')
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
async function until(fn, label, timeout = 30000) {
  const deadline = Date.now() + timeout
  let last
  while (Date.now() < deadline) {
    try { const result = await fn(); if (result) return result } catch (error) { last = error }
    await sleep(50)
  }
  throw new Error(`timeout ${label}: ${last ?? ''}`)
}
function launch(command, args, name, options = {}) {
  const child = spawn(command, args, { cwd: project, env, ...options })
  const output = createWriteStream(join(evidence, name + '.log'))
  child.stdout.pipe(output); child.stderr.pipe(output)
  child.once('close', () => output.end())
  processes.push({ name, pid: child.pid })
  return child
}
async function stop(child, signal = 'SIGTERM') {
  if (!child || child.exitCode !== null || child.signalCode !== null) return
  const exited = once(child, 'exit')
  child.kill(signal)
  await Promise.race([exited, sleep(2000)])
  if (child.exitCode === null && child.signalCode === null) { child.kill('SIGKILL'); await exited }
}
let provider, host, base, session, current, number = 0, eventNumber = 0, hostNumber = 0
async function api(path, method = 'GET', body) {
  const response = await fetch(base + path, { method, headers: { 'content-type': 'application/json' }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) })
  const text = await response.text()
  let data
  try { data = JSON.parse(text) } catch { data = text }
  return { status: response.status, data }
}
async function startHost() {
  const name = `host-${++hostNumber}`
  host = launch('opencode', ['serve', '--hostname', '127.0.0.1', '--port', '0'], name)
  base = await until(async () => (await readFile(join(evidence, name + '.log'), 'utf8')).match(/http:\/\/127\.0\.0\.1:\d+/)?.[0], 'host address')
  await until(async () => (await api('/global/health')).data?.healthy, 'host health')
  await log(name + '-address', { base, pid: host.pid })
}
async function next() {
  const expected = ++number
  current = await until(async () => JSON.parse(await readFile(join(providerRoot, `request-${String(expected).padStart(4, '0')}.json`), 'utf8')), `provider ${expected}`)
  return current
}
async function respond(message) {
  const stem = join(providerRoot, `response-${String(number).padStart(4, '0')}`)
  await writeFile(stem + '.tmp', JSON.stringify({ message }))
  await rename(stem + '.tmp', stem + '.json')
}
async function sendTool(name, args) {
  await respond({ role: 'assistant', tool_calls: [{ id: `recovery-${number}`, type: 'function', function: { name, arguments: JSON.stringify(args) } }] })
}
async function output() {
  const message = current.messages.findLast(message => message.role === 'tool')
  assert.ok(message, 'host returned tool output')
  try { return JSON.parse(message.content) } catch {
    const saved = message.content.match(/Full output saved to: (.+)/)?.[1]
    if (!saved) return message.content
    assert.ok(saved.startsWith(join(variant, 'xdg/data/opencode/tool-output/')))
    return JSON.parse(await readFile(saved, 'utf8'))
  }
}
async function tool(name, args) { await sendTool(name, args); await next(); return output() }
async function terminal() {
  await respond({ role: 'assistant', content: 'Scripted protocol checkpoint.' })
  await until(async () => !(await api('/session/status')).data?.[session] || (await api('/session/status')).data?.[session]?.type === 'idle', 'parent idle')
}
async function newSession() {
  const created = await api('/session', 'POST', { title: 'Learning recovery scripted protocol' })
  assert.equal(created.status, 200)
  session = created.data.id
  observations.sessions.push(session)
}
async function prompt(text) {
  const result = await api(`/session/${session}/prompt_async`, 'POST', { agent: 'mentor', model: { providerID: 'fixture', modelID: 'scripted' }, parts: [{ type: 'text', text }] })
  assert.equal(result.status, 204)
  await next()
}
async function choice(purpose, revision, subject, ids, selected) {
  const staged = await tool('learning_choice', { purpose, revision, subject_json: JSON.stringify(subject), question: 'Apply this explicit recovery decision?', options: ids.map(id => ({ id, label: id, description: id })), multiple: false })
  assert.ok(staged.next_args, JSON.stringify(staged))
  await sendTool('question', staged.next_args)
  const pending = await until(async () => (await api('/question')).data?.find(item => item.sessionID === session), 'native question')
  assert.deepEqual(pending.questions, staged.next_args.questions)
  await log(`native-${number}`, pending)
  assert.equal((await api(`/question/${pending.id}/reply`, 'POST', { answers: [[selected]] })).status, 200)
  await next()
  const result = await tool('learning_choice_result', { id: staged.id })
  assert.equal(result.status, 'answered')
  assert.deepEqual(result.selected, [selected])
  return staged.id
}
let revision = 7
async function commit(body, allowError = false) {
  const event = { date, event_id: `RECOVERY-${++eventNumber}`, ...body }
  const result = await tool('learning_commit', { topic_slug: 'airport', expected_revision: revision, event })
  if (!allowError) { assert.equal(typeof result.revision, 'number', JSON.stringify(result)); revision = result.revision }
  return { event, result }
}
async function production(value) {
  const state = await tool('learning_state_read', { topic_slug: 'airport' })
  const proposal = { goal: state.topic.goal, modules: [], production_required: value, reason: 'Explicit scripted learner requirement change', retired_requirements: value ? [] : ['Production'] }
  const reference = await tool('learning_event_reference', { event_type: 'revise_scope', topic_slug: 'airport', proposal_json: JSON.stringify(proposal) })
  const interaction_id = await choice('scope_revision', revision, reference.resolved.consent_subject, ['apply', 'revise', 'cancel'], 'apply')
  await commit({ type: 'revise_scope', ...proposal, interaction_id })
}
async function check(name, details) { observations.checks.push({ name, status: 'PASS', ...details }); await log('checks', observations); console.log(`PASS ${name}`) }

try {
  const installation = await run('bash', [join(source, 'installers/opencode.sh'), 'install', '--domain', 'learning', '--target', configRoot, '--no-install-brew-tools'], { cwd: source })
  await writeFile(join(evidence, 'install.log'), installation.stdout + installation.stderr)
  await log('versions', { node: process.version, opencode: (await run('opencode', ['--version'])).stdout.trim(), source, head: (await run('git', ['rev-parse', 'HEAD'], { cwd: source })).stdout.trim(), date })
  provider = launch('python3', [join(fixtures, 'provider.py'), providerRoot], 'provider')
  const endpoint = await until(async () => JSON.parse(await readFile(join(providerRoot, 'endpoint.json'), 'utf8')), 'provider endpoint')
  const config = { model: 'fixture/scripted', small_model: 'fixture/scripted', enabled_providers: ['fixture'], provider: { fixture: { npm: '@ai-sdk/openai-compatible', name: 'Recovery protocol fixture', options: { baseURL: endpoint.baseURL, apiKey: 'fixture' }, models: { scripted: { name: 'Scripted', limit: { context: 128000, output: 16000 } } } } }, agent: Object.fromEntries(['mentor', 'english-tutor', 'learning-researcher', 'learning-writer', 'learning-summarizer'].map(name => [name, { model: 'fixture/scripted' }])) }
  await writeFile(join(configRoot, 'opencode.json'), JSON.stringify(config, null, 2))
  await startHost()
  await log('host-api-schema', (await api('/doc')).data)
  await newSession()
  const excerpts = Array.from({ length: 201 }, (_, index) => `Observed learner explanation ${index}: preserve meaning.`)
  await prompt('Explicit scripted learner inputs for protocol validation.\n' + excerpts.join('\n'))
  const skipped = await choice('readiness', revision, { topic_slug: 'airport', module_id: 'M-0001' }, ['ready', 'skip'], 'skip')
  await commit({ type: 'skip_practice', module_id: 'M-0001', interaction_id: skipped })
  let refs = []
  for (let offset = 0; offset < excerpts.length; offset += 50) {
    const located = await tool('learning_evidence', { excerpts: excerpts.slice(offset, offset + 50) })
    assert.ok(located.evidence_refs, JSON.stringify(located))
    refs.push(...located.evidence_refs)
    await commit({ type: 'record_consolidation', module_id: 'M-0001', evidence_refs: located.evidence_refs, learner_evidence: 'Scripted assessment; protocol only', blocking_gaps: [] })
  }
  assert.equal(refs.length, 201)
  const excessive = await commit({ type: 'record_consolidation', module_id: 'M-0001', evidence_refs: refs, learner_evidence: 'Excessive operation', blocking_gaps: [] }, true)
  assert.match(String(excessive.result), /invalid_evidence_refs/)
  await check('201 accumulated references; excessive single operation rejected')
  const ready = await choice('readiness', revision, { topic_slug: 'airport', module_id: 'M-0001' }, ['ready', 'skip'], 'ready')
  const { event: reopening } = await commit({ type: 'start_practice', module_id: 'M-0001', interaction_id: ready })
  const duplicate = await tool('learning_commit', { topic_slug: 'airport', expected_revision: revision - 1, event: reopening })
  assert.equal(duplicate.duplicate, true)
  const reopened = await tool('learning_state_read', { topic_slug: 'airport' })
  assert.equal(reopened.modules[0].practice_history[0].practice_skipped, true)
  assert.equal(reopened.modules[0].consolidation, undefined)
  await commit({ type: 'record_attempt', module_id: 'M-0001', outcome: 'done', evidence_refs: [refs[0]], evidence: 'Scripted completed attempt' })
  assert.match(String((await commit({ type: 'close_module', module_id: 'M-0001' }, true)).result), /module_close_requirements_not_met/)
  await commit({ type: 'record_consolidation', module_id: 'M-0001', evidence_refs: [refs[0]], learner_evidence: 'Scripted fresh assessment', blocking_gaps: [] })
  await check('native reopening archives history and requires new consolidation')

  // Crash the owned host after acceptance, preserving a genuinely pending job.
  await sendTool('learning_job_start', { worker: 'learning-researcher', scope: 'airport', revision, prompt: 'Scripted delayed research for missing-session recovery.' })
  await next()
  const statePath = join(project, '.ai/learning/airport/.state.json')
  const pending = await until(async () => (JSON.parse(await readFile(statePath, 'utf8'))).jobs.find(job => ['starting', 'running'].includes(job.status)), 'persisted accepted job')
  await log('accepted-worker', pending)
  await log('accepted-worker-messages', (await api(`/session/${pending.id}/message`)).data)
  await log('parent-before-restart', (await api(`/session/${session}/message`)).data)
  await stop(host, 'SIGKILL')
  await respond({ role: 'assistant', content: 'Orphaned scripted provider response after owned host interruption.' })
  await startHost()
  assert.equal((await api(`/session/${pending.id}`, 'DELETE')).status, 200)
  const missing = await api(`/session/${pending.id}`)
  await log('missing-session-response', missing)
  assert.equal(missing.status, 404)
  assert.equal(missing.data.name, 'NotFoundError')
  await newSession()
  await prompt('Recover the missing worker and explicitly retry once; reuse stored evidence.')
  const failed = await tool('learning_job_result', { id: pending.id, action: 'inspect', topic_slug: 'airport' })
  assert.equal(failed.status, 'failed')
  assert.equal(failed.error, 'worker_session_missing')
  assert.equal(failed.parentID, pending.parent_id)
  await sendTool('learning_job_start', { worker: 'learning-researcher', scope: 'airport', revision, prompt: 'Explicit single retry using current revision.' })
  await next()
  await respond({ role: 'assistant', content: 'Replacement completed by scripted provider.' })
  await next()
  const replacement = await output()
  assert.equal(replacement.status, 'completed', JSON.stringify(replacement))
  assert.notEqual(replacement.id, pending.id)
  assert.equal(replacement.revision, revision)
  await log('replacement-worker-messages', (await api(`/session/${replacement.id}/message`)).data)
  await check('host 404 resolves missing job; explicit retry creates one replacement')
  await commit({ type: 'record_consolidation', module_id: 'M-0001', evidence_refs: [refs[0], refs[200]], learner_evidence: 'Reused across host restart and parent session', blocking_gaps: [] })
  const reused = await tool('learning_state_read', { topic_slug: 'airport' })
  assert.deepEqual(reused.verified_evidence, refs)
  await check('all 201 references survive host restart and are reusable by new parent')
  await commit({ type: 'close_module', module_id: 'M-0001' })
  await commit({ type: 'record_language_attempt', unit_id: 'L-0001', outcome: 'input-only', evidence: 'Scripted gist-only outcome' })
  await production(false)
  const retired = await tool('learning_state_read', { topic_slug: 'airport' })
  assert.equal(retired.modules[0].phase, 'closed')
  assert.equal(retired.language_units[0].status, 'input-only')
  await production(true)
  const blocked = await commit({ type: 'complete_topic', evidence_refs: [refs[0]] }, true)
  assert.match(String(blocked.result), /language_production_criteria_pending/)
  await check('native production retirement and reactivation preserve closed/input-only results')
  await terminal()
  // The helper owns both exited PIDs. The live host exercises shared recovery.
  await run('python3', [join(fixtures, 'fault.py'), variant, 'legacy-claim'])
  await prompt('Recover an abandoned legacy lock claim without changing progress.')
  const recovered = await tool('learning_recover', { topic_slug: 'airport' })
  assert.equal(recovered.revision, revision)
  await check('live host recovers abandoned legacy lock claim')
  await log('final-state', await tool('learning_state_read', { topic_slug: 'airport' }))
  await terminal()
  await log('parent-final', (await api(`/session/${session}/message`)).data)
  await log('checks', observations)
} catch (error) {
  observations.error = error.stack
  await log('checks', observations)
  throw error
} finally {
  await stop(host)
  await stop(provider)
  await log('processes-stopped', processes)
}
