# Assign Models to Agents

`orchestraitor` never hardcodes `model:`. Assign providers, models, and variants in the global or project OpenCode config.

## Quick path

1. Install the harness (`installers/opencode.sh install`).
2. Open `/models-profiles` in OpenCode.
3. Choose a scope, review the diff, and save.

The project config overrides the global config.

## Tier guidance

| Tier | Agents | Guidance |
|---|---|---|
| Coordination, planning, architecture, review | `orchestraitor` (loads `oc-plan`, `oc-arch`, `oc-review`) | Strong reasoning; suggested `high` variant |
| Delegated workers | built-in `general` (loads `oc-sdd` roles, `oc-refactor` lens mode, `oc-judge`) | Strong code-writing model |

Per-worker models do not exist. The `oc-judge` lenses a and b share the `general` model. For a different provider on the second lens, run it in a separate session or change the `general` model temporarily.

## Manual configuration

Set `agent.<name>` entries in `opencode.json` or `opencode.jsonc`:

```json
{
  "agent": {
    "orchestraitor": {
      "model": "provider/frontier-model",
      "variant": "high"
    },
    "general": {
      "model": "provider/code-model"
    }
  }
}
```

The model syntax is `provider_id/model_id`. Remove both keys to use the defaults again.

## Configurator behavior

`/models-profiles` reads agents and models from the live server. It edits one agent, a coordinator group, or a saved preset, and shows `agent: before -> after` before it writes. Writes keep JSONC comments and unrelated keys. Concurrent changes, invalid models, and stale selections stop the write. See [hot reload](hot-reload.md) for live apply.

Saved presets are user state at `~/.config/opencode/model-configurator-presets.json`. Uninstall removes only the npm registration. It keeps the package cache, presets, assignments, and foreign `tui.json` entries.

## Troubleshooting

- Missing agent: reinstall the harness and open the configurator again.
- Missing model: authenticate its provider and refresh the live catalog.
- Assignment unchanged: examine the project overrides and restart other OpenCode processes.
- Updated plugin missing: run the installer again.
