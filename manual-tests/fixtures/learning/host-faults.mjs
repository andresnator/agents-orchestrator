// Host API/helper injection evidence only; this is not a live OpenCode run.
import { copyFile, readFile, writeFile } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { learningRuntimeContracts as runtime } from '../../../domains/learning/plugins/learning-runtime.ts'

const variant = resolve(process.argv[2])
const manifest = JSON.parse(await readFile(join(variant, '..', 'manifest.json'), 'utf8'))
if (manifest.case_id !== 'MT-LEARNING-RUNTIME' || !['missing_api', 'missing_helper'].includes(variant.split('/').at(-1))) {
  throw new Error('Use a prepared RUNTIME missing_api or missing_helper variant')
}
const evidence = { layer: 'scripted-host-injection', variant, created: 0 }
if (variant.endsWith('/missing_api')) {
  const client = { session: { create: async () => { evidence.created++; return { data: { id: 'unexpected' } } } } }
  const jobs = runtime.createJobs(client)
  try {
    await jobs.launch({ agent: 'mentor', sessionID: 'synthetic-parent', messageID: 'synthetic-message', abort: new AbortController().signal },
      { worker: 'learning-researcher', scope: 'session:synthetic', prompt: 'Synthetic research' })
    throw new Error('Expected rejection')
  } catch (error) {
    if (!String(error).includes('sequential_session_api_unavailable') || evidence.created !== 0) throw error
    evidence.error = String(error)
  }
} else {
  // Copy away from source node_modules; never remove or edit installed/global packages.
  const copied = join(variant, 'runtime-without-helper.ts')
  await copyFile(fileURLToPath(new URL('../../../domains/learning/plugins/learning-runtime.ts', import.meta.url)), copied)
  process.env.OPENCODE_CONFIG_DIR = join(variant, 'absent-helper')
  process.env.XDG_CONFIG_HOME = join(variant, 'xdg/config')
  const { LearningRuntimePlugin } = await import(pathToFileURL(copied).href)
  try {
    await LearningRuntimePlugin({ client: {}, directory: join(variant, 'project') })
    throw new Error('Expected rejection; helper may be resolvable in an ancestor directory')
  } catch (error) {
    if (!String(error).includes('learning_tool_helper_unavailable')) throw error
    evidence.error = String(error)
  }
}
evidence.status = 'PASS'
await writeFile(join(variant, 'evidence/host-fault.json'), JSON.stringify(evidence, null, 2) + '\n')
console.log(JSON.stringify(evidence))
