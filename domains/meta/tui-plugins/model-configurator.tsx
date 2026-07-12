import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui"
import { resolveRuntimeDataRoot } from "./model-configurator/domain"
import { runModelConfigurator } from "./model-configurator/wizard"

export const MODEL_CONFIGURATOR_PLUGIN_ID = "agents-orchestrator.model-configurator"
export const MODEL_CONFIGURATOR_COMMAND_ID = "agents-orchestrator.model-configurator.open"
export const MODEL_CONFIGURATOR_SLASH_NAME = "model-configurator"
export const MINIMUM_OPENCODE_VERSION = "1.17.15"
export const JSONC_PARSER_VERSION = "3.3.1"

const tui: TuiPlugin = async (api) => {
  const runtimeDataRoot = await resolveRuntimeDataRoot(import.meta.url)
  api.keymap.registerLayer({
    commands: [
      {
        name: MODEL_CONFIGURATOR_COMMAND_ID,
        title: "Configure agent models",
        desc: "Assign OpenCode models and variants by tier or agent",
        category: "Agents Orchestrator",
        namespace: "palette",
        slashName: MODEL_CONFIGURATOR_SLASH_NAME,
        run() {
          void runModelConfigurator(api, runtimeDataRoot)
        },
      },
    ],
  })
}

const plugin: TuiPluginModule & { id: string } = {
  id: MODEL_CONFIGURATOR_PLUGIN_ID,
  tui,
}

export default plugin
