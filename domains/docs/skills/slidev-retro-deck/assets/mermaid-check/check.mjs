// Parse every ```mermaid block in a markdown file without a browser.
// Usage: node check.mjs <path/to/slides.md>  (exit 1 if any block fails)
import { readFileSync } from 'node:fs'
import { JSDOM } from 'jsdom'

const dom = new JSDOM('<!DOCTYPE html><body></body>', { pretendToBeVisual: true })
globalThis.window = dom.window
globalThis.document = dom.window.document
// Do not assign globalThis.navigator: jsdom exposes it as getter-only and the
// assignment throws. Mermaid only needs window/document plus this DOMPurify stub.
globalThis.DOMPurify = { sanitize: (x) => x, addHook: () => {} }

const mermaid = (await import('mermaid')).default
mermaid.initialize({ startOnLoad: false })

const src = readFileSync(process.argv[2], 'utf8')
const blocks = [...src.matchAll(/```mermaid[^\n]*\n([\s\S]*?)```/g)].map(m => m[1])
console.log(`found ${blocks.length} mermaid blocks`)

let failed = 0
for (const [i, code] of blocks.entries()) {
  try {
    await mermaid.parse(code)
    console.log(`block ${i + 1}: OK (${code.trim().split('\n')[0]})`)
  } catch (e) {
    failed++
    console.log(`block ${i + 1}: FAIL — ${e.message}`)
  }
}
process.exit(failed ? 1 : 0)
