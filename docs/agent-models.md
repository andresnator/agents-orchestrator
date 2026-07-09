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

## Interactive Wizard And Profiles

`scripts/configure-models.sh` is an interactive wizard over the recipe above. It discovers the harness agents from `domains/*/agents/`, loads a tier profile from `profiles/`, asks model + variant per tier (with per-agent overrides), and merges the resulting `agent` block into the target config, preserving every unrelated key and any non-harness agent entries.

```bash
scripts/configure-models.sh                 # wizard against ~/.config/opencode
scripts/configure-models.sh --project       # wizard against ./.opencode (gitignored user state)
scripts/configure-models.sh --dry-run       # print merged JSON + diff, write nothing
scripts/configure-models.sh show            # print current mappings, read-only
```

Behavior notes:

- Profiles (`profiles/<name>.json`, `--profile NAME`) map agents to abstract tiers with an optional suggested variant; they never contain concrete model ids, so they work for any provider set.
- The model/variant catalog is read from `~/.config/opencode/cache/model-variants.json`, written on OpenCode startup by the meta `model-variants` plugin (start a session once to generate or refresh it). Without the cache the wizard falls back to `opencode models`, which lists models but no variants.
- Choosing `inherit` deletes that agent's `model`/`variant` mapping, restoring default inheritance; `skip` keeps whatever is there.
- If `jd-judge-a` and `jd-judge-b` resolve to the same provider, the wizard warns and offers to re-pick judge-b.
- An existing `opencode.jsonc` is detected and written back under its own name; JSONC comments are not supported (the script refuses rather than destroying them). A timestamped backup is created before every write.

## Defaults When Unmapped

An agent with no mapping keeps OpenCode's inheritance: primary agents use the global `model`, and subagents inherit the model of the agent that invoked them. Deleting a mapping entry restores that behavior.

## Why Not A Plugin

A plugin for this was designed and rejected: static assignment is fully covered by native config merging, and this repo adds plugins only for real runtime behavior. The reference implementation (`sdd-engram-plugin`) was audited in `.ai/absorb/2026-07-07-external-practices.md`; its runtime profile editing, on-disk `opencode.json` rewriting, and auto-generated fallback agents were rejected there. A plugin (via the `config` hook of `@opencode-ai/plugin`, following the `domains/meta/plugins/skill-registry.ts` pattern) becomes justified only if a genuinely dynamic need appears: model selection by environment or branch, fail-soft validation of mappings, or automatic per-agent variant resolution.

The meta `model-variants` plugin (forked from gentle-ai, MIT) does not contradict this: it assigns nothing and rewrites no config. It only exports the provider/model/variant catalog — data available solely to the running OpenCode server — to `~/.config/opencode/cache/model-variants.json` for the wizard to read.
