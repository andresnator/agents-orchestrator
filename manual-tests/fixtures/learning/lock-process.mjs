// Disposable process for lock races and crash checkpoints; never used by the plugin.
import fs from 'node:fs/promises'
import { syncBuiltinESMExports } from 'node:module'
import { learningRuntimeContracts } from '../../../domains/learning/plugins/learning-runtime.ts'

const [directory, slug, checkpointJSON = '{}'] = process.argv.slice(2)
const checkpoint = JSON.parse(checkpointJSON)
let matches = 0
async function stopAt(operation, when, path) {
  const kind = String(path).includes('.reclaim-') ? 'claim' : 'lock'
  if (!String(path).includes('.state.lock') || operation !== checkpoint.operation || when !== checkpoint.when || kind !== checkpoint.kind) return
  if (checkpoint.temporary === false && String(path).endsWith('.tmp')) return
  if (++matches !== (checkpoint.occurrence ?? 1)) return
  process.send?.({ checkpoint: { operation, when, kind, path: String(path) } })
  await new Promise(resolve => process.once('message', resolve))
}
for (const operation of ['open', 'link', 'unlink']) {
  const original = fs[operation]
  fs[operation] = async (...args) => {
    const path = operation === 'link' ? args[1] : args[0]
    await stopAt(operation, 'before', path)
    const result = await original(...args)
    if (operation === 'open' && String(path).includes('.state.lock')) {
      for (const method of ['writeFile', 'sync']) {
        const action = result[method].bind(result)
        result[method] = async (...input) => {
          await stopAt(method, 'before', path)
          const value = await action(...input)
          await stopAt(method, 'after', path)
          return value
        }
      }
    }
    await stopAt(operation, 'after', path)
    return result
  }
}
syncBuiltinESMExports()
try {
  const result = await learningRuntimeContracts.createStateStore(directory).recover(slug)
  process.send?.({ result })
} catch (error) {
  process.send?.({ error: error.message })
} finally {
  process.disconnect?.()
}
