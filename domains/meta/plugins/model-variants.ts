/**
 * model-variants
 * Exports the provider/model/variant catalog for scripts/configure-models.sh.
 *
 * On OpenCode startup, fetches the provider list via the in-process SDK client
 * and writes a JSON cache to ~/.config/opencode/cache/model-variants.json.
 * The configure-models wizard reads this file to offer real per-model variant
 * menus, which `opencode models` cannot provide.
 *
 * Forked from gentle-ai (MIT), original author Gentleman Programming:
 * https://github.com/Gentleman-Programming/gentle-ai/blob/main/internal/assets/opencode/plugins/model-variants.ts
 * Adapted for agents-orchestrator: cache path moved under ~/.config/opencode/cache,
 * and every model is recorded (empty variant list when a model has none) so the
 * cache can also drive the wizard's model menu.
 */

import type { Plugin } from "@opencode-ai/plugin"
import { writeFile, mkdir, rename, rm } from "fs/promises"
import { randomBytes } from "crypto"
import { homedir } from "os"
import path from "path"

const MODEL_VARIANTS_CACHE_FILE = "model-variants.json"

function isIgnorableFileRace(err: unknown) {
  return typeof err === "object" && err !== null && "code" in err && (err as { code?: string }).code === "ENOENT"
}

async function removeOwnTempFile(tmpPath: string) {
  try {
    await rm(tmpPath, { force: true })
  } catch (err) {
    if (!isIgnorableFileRace(err)) {
      console.error("[model-variants] temp cleanup failed:", err)
    }
  }
}

export const ModelVariantsPlugin: Plugin = async (input) => {
  async function refreshVariantsCache() {
    let tmpPath: string | undefined
    try {
      const result = await input.client.provider.list()
      const data = (result as any).data ?? result
      const providerList: any[] = data?.all ?? data?.providers ?? (Array.isArray(data) ? data : [])

      const providers: Record<string, Record<string, string[]>> = {}
      for (const prov of providerList) {
        for (const [modelId, model] of Object.entries(prov.models ?? {})) {
          const m = model as any
          providers[prov.id] = providers[prov.id] || {}
          providers[prov.id][modelId] = m.variants ? Object.keys(m.variants).sort() : []
        }
      }

      const cacheDir = path.join(homedir(), ".config", "opencode", "cache")
      await mkdir(cacheDir, { recursive: true })

      // Always write through a per-invocation tmp file before renaming, so
      // readers never see partial JSON and concurrent plugin loads do not
      // race over the same tmp path.
      const finalPath = path.join(cacheDir, MODEL_VARIANTS_CACHE_FILE)
      tmpPath = path.join(cacheDir, `${MODEL_VARIANTS_CACHE_FILE}.${randomBytes(3).toString("hex")}.tmp`)
      await writeFile(tmpPath, JSON.stringify({ generatedAt: new Date().toISOString(), providers }, null, 2))
      await rename(tmpPath, finalPath)
      tmpPath = undefined
    } catch (err) {
      console.error("[model-variants] cache refresh failed:", err)
    } finally {
      if (tmpPath) {
        await removeOwnTempFile(tmpPath)
      }
    }
  }

  // Don't await — server isn't ready during plugin init. Fire and forget.
  refreshVariantsCache().catch((err) => {
    console.error("[model-variants] unexpected refresh error:", err)
  })

  return {}
}

export default ModelVariantsPlugin
