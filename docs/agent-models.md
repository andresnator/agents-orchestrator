# Per-Agent Model, Provider, And Variant Assignment

Repo agents never hardcode `model:` in frontmatter. Every agent file under `domains/*/agents/` stays provider-agnostic so the same artifacts work for any user, provider set, or budget. Model assignment is user state and lives in the user's OpenCode config, exactly like API keys.

## How It Works

OpenCode merges agent definitions by name: a Markdown agent installed by this repo and an `agent.<name>` block in `opencode.json` combine into one agent. Global config (`~/.config/opencode/opencode.json`) and project config merge too, with the project taking precedence. That native merge already covers static per-agent assignment — no repo mechanism is required.

Model syntax is `provider_id/model_id`. A per-agent `variant` picks a model variant by name (it applies only when the agent uses its configured `model`). Per-agent `options` are still passed through to the provider for anything a variant does not cover.

## Recipe

Merge a block like this into your `opencode.json` (global for your default policy, project-level to override per repo):

```json
{
  "agent": {
    "orchestraitor": { "model": "anthropic/claude-opus-4-8", "variant": "high" },
    "sdd-explore":   { "model": "anthropic/claude-haiku-4-5" },
    "sdd-implement": { "model": "anthropic/claude-sonnet-4-5", "variant": "high" },
    "sdd-verify":    { "model": "anthropic/claude-sonnet-4-5" },
    "jd-judge-a":    { "model": "openai/gpt-5.1" },
    "jd-judge-b":    { "model": "google/gemini-2.5-pro" }
  }
}
```

Putting `jd-judge-a` and `jd-judge-b` on different providers strengthens the blind adversarial review: the judges cannot share model-specific blind spots.

## Variants

OpenCode variants are partial option overrides declared per model under the provider block:

```json
{
  "provider": {
    "anthropic": {
      "models": {
        "claude-sonnet-4-5": {
          "variants": {
            "thinking": { "reasoningEffort": "high" }
          }
        }
      }
    }
  }
}
```

To pin a variant on a specific agent, set the agent's `variant` key to the variant name, as `sdd-implement` does above (per the config schema it is the agent's default variant and applies only when the agent uses its configured `model`). Provider built-in variants (Anthropic `high`/`max`, OpenAI `none` through `xhigh`, Google `low`/`high`) and custom variants declared under the provider block are both referenced by name. There is still no `model#variant` syntax in the `model` field; interactive selection is the `variant_cycle` keybind.

## The Model Configurator (TUI)

The meta domain ships an OpenCode TUI plugin, `model-configurator`, that is a staged assistant over the recipe above. Open it from the command palette ("Configure agent models") or with `/model-configurator`. It walks six stages:

1. **Scope** — global (`~/.config/opencode/opencode.json[c]`) or the current project (`./.opencode/opencode.json[c]`), showing the exact target file and warning when `OPENCODE_CONFIG`/`OPENCODE_CONFIG_CONTENT` can eclipse it.
2. **Profile** — a tier profile from `profiles/` (default `default`); invalid profiles block, uncovered agents warn.
3. **Tiers** — per non-empty tier: keep, inherit, or pick a model from the live catalog of connected providers, then one of that model's variants (the profile's suggested variant is preselected when available).
4. **Overrides** — optional per-agent corrections: use the tier decision, keep current, inherit, or pick another model/variant.
5. **Review** — a semantic `agent: before -> after` summary; if `jd-judge-a` and `jd-judge-b` resolve to the same provider it warns first (different providers strengthen the blind adversarial review).
6. **Confirm/apply** — the catalog is refreshed and every selection revalidated; stale picks abort without writing. Cancel writes nothing.

Behavior notes:

- Profiles (`profiles/<name>.json`) map agents to abstract tiers with an optional suggested variant; they never contain concrete model ids, so they work for any provider set. The installer snapshots `profiles/` and the agent catalog beside the plugin, so re-run `installers/opencode.sh install` after changing profiles or agents in the repo.
- The model/variant catalog comes live from the running OpenCode server (`connected` providers intersected with the full catalog) — no cache file and no external process.
- Choosing `inherit` deletes only that agent's `model`/`variant` keys at the selected scope (pruning an emptied agent entry), restoring default inheritance; `keep` is always a no-op.
- Writes are transactional: comments and foreign keys in `opencode.json[c]` are preserved via targeted JSONC edits, a concurrent external edit aborts the write, and a timestamped backup is created next to the file. The success toast names the file and backup; restart affected OpenCode sessions to apply.

Prerequisites: OpenCode >= 1.17.15, and `python3` + `jq` at install time (the installer registers the plugin in `$TARGET/tui.json` and pins the `jsonc-parser` dependency in `$TARGET/package.json`, owning only those exact values).

If the palette entry and `/model-configurator` do not appear despite a clean install, check OpenCode's TUI plugin toggle: a persisted `"plugin_enabled": { "agents-orchestrator.model-configurator": false }` in `~/.local/state/opencode/kv.json` disables it silently. Re-enable it from the TUI plugin list, or set the value to `true` (or delete the key) with no OpenCode session running, then start a fresh session.

If you used the retired shell wizard, existing `agent.<name>.model`/`variant` assignments and `profiles/*.json` keep working unchanged; the old `~/.config/opencode/cache/model-variants.json` cache is orphaned and can be deleted manually.

## Defaults When Unmapped

An agent with no mapping keeps OpenCode's inheritance: primary agents use the global `model`, and subagents inherit the model of the agent that invoked them. Deleting a mapping entry restores that behavior.
