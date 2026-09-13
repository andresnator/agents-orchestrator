// Validate copied snapshots using the checkout's actual reader and regenerate views.
import { readdir, readFile, writeFile, mkdir } from 'node:fs/promises'
import { join, dirname, resolve } from 'node:path'
import { learningRuntimeContracts as runtime } from '../../../domains/learning/plugins/learning-runtime.ts'

const root = resolve(process.argv[2])
const manifest = JSON.parse(await readFile(join(root, 'manifest.json'), 'utf8'))
let count = 0
for (const variant of Object.keys(manifest.variants)) {
  const project = join(root, variant, 'project')
  const topics = await readdir(join(project, '.ai/learning')).catch(error => {
    if (error.code === 'ENOENT') return []
    throw error
  })
  for (const slug of topics) {
    const state = await runtime.createStateStore(project).read(slug)
    for (const [path, content] of Object.entries(runtime.renderViews(state))) {
      const target = join(project, '.ai/learning', slug, path)
      await mkdir(dirname(target), { recursive: true })
      await writeFile(target, content)
    }
    count++
  }
}
console.log(JSON.stringify({ case: manifest.case_id, validated_snapshots: count, layer: 'fixture-only' }))
