# Assign Models to Agents

Repository agents never hardcode `model:`. Users assign providers, models, and variants in global or project OpenCode state.

## Quick path

1. Install the `meta` domain.
2. Open `/models-profiles` in OpenCode.
3. Choose a scope, review the diff, and save.

Project config overrides global config. Reinstall after changing repository profiles because the installer copies them into the selected OpenCode target.

## Tier guidance

| Tier | Agents | Guidance |
|---|---|---|
| Primary coordination | `deep-planner`, `architect`, `orchestraitor`, `review-coordinator` | Strong reasoning; suggested `high` variant |
| Implementation | `sdd-implement`, `jd-fix` | Strong code-writing model |
| Analysis | `sdd-explore`, `refactor-analyzer` | Fast economical model |
| Verification | `sdd-verify` | Strong independent model; suggested `high` |
| Judge A | `jd-judge-a` | Strong model or provider A |
| Judge B | `jd-judge-b` | Distinct strong model or provider B |
| Judge solo | `jd-solo` | Fast balanced reviewer |
| Utility | `english-tutor`, `learning-recorder` | Economical utility model |

Assign `mentor` separately when installing the `learning` domain. Assign `learning-recorder` individually with `/models-profiles` when it should use a lightweight model; the repository does not choose that model. Distinct Judge A and B providers reduce shared blind spots.

## Manual configuration

OpenCode merges installed Markdown agents with `agent.<name>` entries in `opencode.json` or `opencode.jsonc`:

```json
{
  "agent": {
    "orchestraitor": {
      "model": "provider/frontier-model",
      "variant": "high"
    },
    "sdd-implement": {
      "model": "provider/code-model"
    },
    "jd-judge-a": {
      "model": "provider-a/reviewer",
      "variant": "high"
    },
    "jd-judge-b": {
      "model": "provider-b/reviewer",
      "variant": "high"
    }
  }
}
```

Model syntax is `provider_id/model_id`; `variant` is a separate key. Removing both restores caller or OpenCode defaults.

## Configurator behavior

The installer registers the exact package version from the npm descriptor. OpenCode resolves it at startup, then `/models-profiles` reads agents and connected models from the live server. It edits one agent, a coordinator group, an abstract profile, or a saved preset, and shows `agent: before -> after` before writing.

Writes preserve JSONC comments and unrelated keys. Concurrent changes, invalid models, and stale selections abort. Supported changes hot-apply to the connected server; other OpenCode processes may need a restart. See [hot reload](hot-reload.md).

Abstract profiles live under repository `profiles/`, contain no concrete model ids, and are copied to `<target>/model-profiles/opencode-models-presets`. Concrete presets are user state at `~/.config/opencode/model-configurator-presets.json`.

Uninstall removes only the manifest-owned npm registration and profile snapshots. It preserves OpenCode's package cache, concrete presets, agent assignments, and foreign `tui.json` entries.

## Troubleshooting

- Missing agent: install its domain and reopen the configurator.
- Missing model: authenticate its provider and refresh the live catalog.
- Assignment unchanged: check project overrides and restart other OpenCode processes.
- Updated plugin or profile missing: run the installer again.
