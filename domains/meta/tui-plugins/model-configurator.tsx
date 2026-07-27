import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui"
import { resolveProfilesRoot } from "./model-configurator/domain"
import { runModelConfigurator } from "./model-configurator/wizard"

export const MODEL_CONFIGURATOR_PLUGIN_ID = "agents-orchestrator.model-configurator"
export const MODEL_CONFIGURATOR_COMMAND_ID = "agents-orchestrator.model-configurator.open"
export const MODEL_CONFIGURATOR_SLASH_NAME = "model-configurator"
export const MINIMUM_OPENCODE_VERSION = "1.17.15"
export const JSONC_PARSER_VERSION = "3.3.1"

const tui: TuiPlugin = async (api) => {
  // Registration never depends on installed data: agents come from the server and profiles are optional.
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
          void resolveProfilesRoot(import.meta.url)
            .then((profilesRoot) => runModelConfigurator(api, profilesRoot))
            .catch((error) => {
              api.ui.toast({
                variant: "error",
                title: "Model configurator failed",
                message: String(error instanceof Error ? error.message : error),
                duration: 8000,
              })
            })
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
