# Assign Models to Agents

Repository agents never hardcode `model:`. Model, provider, and variant assignment is user OpenCode state, configured globally or per project.

## Quick path

1. Install the `meta` domain.
2. Open `/model-configurator` in OpenCode.
3. Choose scope, apply the `default` profile or an agent group, review, and save.

Project config overrides global config. Re-run the installer after a repository profile changes because profiles are copied beside the external TUI plugin.

## Current tiers

| Tier | Agents | Guidance |
|---|---|---|
| Orchestration | `sdlc-orchestrator`, `deep-planner`, `architect`, `orchestraitor`, `orchestralite`, `review-coordinator` | Strongest reasoning; suggested `high` variant |
| Implementation | `sdd-implement`, `jd-fix` | Strong code-writing model |
| Analysis | `sdd-explore`, `refactor-analyzer` | Fast, economical read-heavy model |
| Verification | `sdd-verify`, `lite-verify` | Strong independent model; suggested `high` variant |
| Judge A | `jd-judge-a` | Strong model/provider A; suggested `high` |
| Judge B | `jd-judge-b` | Strong model/provider B, distinct from A; suggested `high` |
| Judge solo | `jd-solo` | Fast balanced reviewer |
| Utility | `english-tutor` | Economical utility model |

The coordinator now writes `change.md` itself, so there is no drafting tier. Distinct providers for judge A and B reduce shared model-specific blind spots.
The learning coordinator `mentor` remains outside this default profile and is assigned separately when the `learning` domain is installed.

## Manual configuration

OpenCode merges installed Markdown agents with `agent.<name>` blocks in `opencode.json`:

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

Model syntax is `provider_id/model_id`. `variant` names a provider or custom model variant; there is no `model#variant` syntax. Removing an agent's model and variant restores inheritance from its caller or OpenCode defaults.

## Model configurator behavior

The external `model-configurator` TUI reads the live server's agent and connected-model catalog. It can edit one agent, a coordinator group, an abstract profile, or a saved concrete preset. Review shows `agent: before -> after` before any write.

Writes are targeted and transactional: JSONC comments and foreign keys are preserved, concurrent edits abort, and invalid or stale selections are rejected. Supported changes hot-apply to the current server; the wizard asks for a restart when they cannot. Other OpenCode processes still need a restart. See [hot reload](hot-reload.md).

Profiles under `profiles/` contain abstract tiers and optional suggested variants, never concrete model ids. Saved presets contain concrete assignments and live in user state at `~/.config/opencode/model-configurator-presets.json`.

## Troubleshooting

- Missing agent: install its domain and reopen the configurator.
- Missing model: authenticate the provider and refresh the live catalog.
- Assignment appears unchanged: check project overrides and restart other OpenCode processes.
- TUI plugin changed in this repository: reinstall so the pinned bundle and copied profiles refresh.
