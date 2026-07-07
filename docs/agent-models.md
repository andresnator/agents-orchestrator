# Per-Agent Model, Provider, And Variant Assignment

Repo agents never hardcode `model:` in frontmatter. Every agent file under `domains/*/agents/` stays provider-agnostic so the same artifacts work for any user, provider set, or budget. Model assignment is user state and lives in the user's OpenCode config, exactly like API keys.

## How It Works

OpenCode merges agent definitions by name: a Markdown agent installed by this repo and an `agent.<name>` block in `opencode.json` combine into one agent. Global config (`~/.config/opencode/opencode.json`) and project config merge too, with the project taking precedence. That native merge already covers static per-agent assignment — no repo mechanism is required.

Model syntax is `provider_id/model_id`. Per-agent `options` are passed through to the provider (for example `reasoningEffort`).

## Recipe

Merge a block like this into your `opencode.json` (global for your default policy, project-level to override per repo):

```json
{
  "agent": {
    "orchestraitor": { "model": "anthropic/claude-opus-4-8" },
    "sdd-explore":   { "model": "anthropic/claude-haiku-4-5" },
    "sdd-implement": { "model": "anthropic/claude-sonnet-4-5", "options": { "reasoningEffort": "high" } },
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

There is no syntax to reference a variant from an agent's `model` field (no `model#variant` and no `variant:` agent key); native variant selection is the interactive `variant_cycle` keybind. To pin variant behavior on a specific agent, copy the variant's options into that agent's `options` block, as `sdd-implement` does above. Provider built-in variants (Anthropic `high`/`max`, OpenAI `none` through `xhigh`, Google `low`/`high`) are pinned the same way via `options`.

## Defaults When Unmapped

An agent with no mapping keeps OpenCode's inheritance: primary agents use the global `model`, and subagents inherit the model of the agent that invoked them. Deleting a mapping entry restores that behavior.

## Why Not A Plugin

A plugin for this was designed and rejected: static assignment is fully covered by native config merging, and this repo adds plugins only for real runtime behavior. The reference implementation (`sdd-engram-plugin`) was audited in `.ai/absorb/2026-07-07-external-practices.md`; its runtime profile editing, on-disk `opencode.json` rewriting, and auto-generated fallback agents were rejected there. A plugin (via the `config` hook of `@opencode-ai/plugin`, following the `domains/meta/plugins/skill-registry.ts` pattern) becomes justified only if a genuinely dynamic need appears: model selection by environment or branch, fail-soft validation of mappings, or automatic per-agent variant resolution.
