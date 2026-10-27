# Assign Models to Agents

The repository's only agent, `orchestraitor`, never hardcodes `model:`. Users assign providers, models, and variants in global or project OpenCode state.

## Quick path

1. Install the `meta` domain.
2. Open `/models-profiles` in OpenCode.
3. Choose a scope, review the diff, and save.

Project config overrides global config. The tier table below is manual guidance; the repository does not install it as a selectable profile.

## Tier guidance

| Tier | Agents | Guidance |
|---|---|---|
| Coordination, planning, architecture, review | `orchestraitor` (loads `oc-plan-*`, `oc-arch`, `oc-review`) | Strong reasoning; suggested `high` variant |
| Delegated workers | built-in `general` (loads `oc-sdd-*`, `oc-refactor-lens`, `oc-judge`, `oc-judge-fix`) | Strong code-writing model |

Former worker agents are now skills, so per-worker models no longer exist; `general` serves every delegated brief. `oc-judge` lenses a and b now share the `general` model; because distinct providers reduce shared blind spots, run the second lens in a separate session (or temporarily change the `general` model) when you want a different provider.

## Manual configuration

OpenCode merges installed Markdown agents with `agent.<name>` entries in `opencode.json` or `opencode.jsonc`:

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

Model syntax is `provider_id/model_id`; `variant` is a separate key. Removing both restores caller or OpenCode defaults.

## Configurator behavior

The installer registers the exact package version from the npm descriptor. OpenCode resolves it at startup, then `/models-profiles` reads agents and connected models from the live server. It edits one agent, a coordinator group, or a saved preset, and shows `agent: before -> after` before writing. Because no profile directory is supplied, the configurator does not show a Profiles section.

Writes preserve JSONC comments and unrelated keys. Concurrent changes, invalid models, and stale selections abort. Supported changes hot-apply to the connected server; other OpenCode processes may need a restart. See [hot reload](hot-reload.md).

Saved presets are user state at `~/.config/opencode/model-configurator-presets.json`; the repository does not ship or copy model profiles.

Uninstall removes only the manifest-owned npm registration. It preserves OpenCode's package cache, saved presets, agent assignments, and foreign `tui.json` entries.

## Troubleshooting

- Missing agent: install its domain and reopen the configurator.
- Missing model: authenticate its provider and refresh the live catalog.
- Assignment unchanged: check project overrides and restart other OpenCode processes.
- Updated plugin missing: run the installer again.
