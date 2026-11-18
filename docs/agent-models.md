# Assign Models to Agents

No agent hardcodes `model:`. Assign providers, models, and variants in the global or project OpenCode config.

## Quick path

1. Install the harness (`installers/opencode.sh install`).
2. Open `/models-profiles` in OpenCode.
3. Choose a scope, review the diff, and save.

The project config overrides the global config.

## Tier guidance

| Agent | Work | Guidance |
|---|---|---|
| `orchestraitor` | Routes, plans, coordinates, and decides | The strongest model that you have; suggested `high` variant |
| `worker` | Implements one brief: edits files and runs checks | A mid code model |
| `scout` | Read-only: explores, verifies, and judges | A small, cheap model |

The two `dual` review judges share the `scout` model. Factory tasks use the `worker` model. If `worker` or `scout` is not installed, the built-in `general` agent does the work with its own model.

## Manual configuration

Set `agent.<name>` entries in `opencode.json` or `opencode.jsonc`:

```json
{
  "agent": {
    "orchestraitor": {
      "model": "provider/frontier-model",
      "variant": "high"
    },
    "worker": {
      "model": "provider/code-model"
    },
    "scout": {
      "model": "provider/small-model"
    }
  }
}
```

The model syntax is `provider_id/model_id`. Remove both keys to use the defaults again.

## Configurator behavior

`/models-profiles` reads agents and models from the live server. It edits one agent, a coordinator group, or a saved preset, and shows `agent: before -> after` before it writes. Writes keep JSONC comments and unrelated keys. Concurrent changes, invalid models, and stale selections stop the write. See [hot reload](hot-reload.md) for live apply.

Saved presets are user state at `~/.config/opencode/model-configurator-presets.json`. Uninstall removes only the npm registration. It keeps the package cache, presets, assignments, and foreign `cli.json` entries.

## Troubleshooting

- Missing agent: reinstall the harness and open the configurator again.
- Missing model: authenticate its provider and refresh the live catalog.
- Assignment unchanged: examine the project overrides and restart other OpenCode processes.
- Updated plugin missing: run the installer again.
