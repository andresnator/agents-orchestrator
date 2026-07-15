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

The meta domain ships an OpenCode TUI plugin, `model-configurator`, that is a staged assistant over the recipe above. Open it from the command palette ("Configure agent models") or with `/model-configurator`. It walks these stages:

1. **Scope** — global or the current project. Each option shows a short target path (`~/.config/opencode/opencode.json[c]`, `.opencode/opencode.json[c]`) and warns when `OPENCODE_CONFIG`/`OPENCODE_CONFIG_CONTENT` can eclipse it.
2. **Domain hub** — one dialog listing the repo **domains** (each with its agent count, biggest first), the tier **profiles** from `profiles/` (invalid profiles block, uncovered agents warn), and your **saved presets** (see below). Three paths branch from here:
   - **Domain** — opens that domain's agent list (every primary and subagent, with the built-in fuzzy search). Picking an agent offers keep current / inherit / a model from the live catalog, then a variant; you return to the same list with the pending change marked (`● agent`). An **All agents** row makes the same decision once and fans it out to every agent in the domain (keep current clears all of the domain's pending decisions). `esc` or **Done** goes back to the hub, where you can enter another domain — once anything is pending, a **Review N pending change(s)** row jumps straight to Review.
   - **Profile** — continues through Tiers and Overrides below.
   - **Preset** — opens **Apply** / **Delete**; Apply re-validates its assignments against the live catalog (stale entries — unknown agent, gone model, or gone variant — are dropped after a confirm; a fully stale preset warns and returns) and jumps straight to Review, skipping tiers and overrides.
3. **Tiers** — per non-empty tier: keep, inherit, or pick a model from the live catalog of connected providers, then one of that model's variants (the profile's suggested variant is preselected when available). Profile path only.
4. **Overrides** — optional per-agent corrections: use the tier decision, keep current, inherit, or pick another model/variant. **→ Next agent** / **← Prev agent** move to the adjacent agent (wrapping around) without changing the current one, so you can page through agents to tweak just a few. Profile path only.
5. **Review** — a semantic `agent: before -> after` summary as disabled rows grouped by domain. The catalog is refreshed and every selection revalidated (stale picks abort without writing). Choose **Apply**, **Apply and save as preset** (prompts for a name), or **Cancel** (writes nothing).

Behavior notes:

- **Back navigation:** every dialog shows an `esc:` hint. `esc` goes back one level (agent list → domain hub → Scope); on the first dialog (Scope) it closes the configurator. **Cancel** on Review aborts entirely. Backing into the Tiers stage resets any per-agent overrides made afterward (they are rebuilt from the tier decisions), and choosing a profile likewise rebuilds pending decisions from its tiers.
- The agent catalog (`agents.json`, generated at install) records each agent's `name`, `domain`, and `mode`, which is what powers the domain hub and the `(primary)`/`(subagent)` labels.
- **Saved presets** capture the final concrete `agent → model/variant` result so you can re-apply a whole configuration in about two steps. They live user-side in `~/.config/opencode/model-configurator-presets.json` (always the global config root, independent of the chosen scope) and hold concrete model ids — the repo `profiles/*.json` stay abstract. The name prompt always opens empty; saving under an existing name asks Overwrite / Choose another name first. Inherited (model-less) agents are omitted from the preset.
- Profiles (`profiles/<name>.json`) map agents to abstract tiers with an optional suggested variant; they never contain concrete model ids, so they work for any provider set. The installer snapshots `profiles/` and the agent catalog beside the plugin, so re-run `installers/opencode.sh install` after changing profiles or agents in the repo (the plugin, including `presets.ts`, is installed as copies, not symlinks — re-running install is also how you pick up plugin code changes).
- The model/variant catalog comes live from the running OpenCode server (`connected` providers intersected with the full catalog) — no cache file and no external process.
- Choosing `inherit` deletes only that agent's `model`/`variant` keys at the selected scope (pruning an emptied agent entry), restoring default inheritance; `keep` is always a no-op.
- In the variant dialog, **Default (no variant)** writes no `variant` key (the provider default applies); it is distinct from a provider-supplied `none` variant, which is a real value listed by name (e.g. OpenAI's reasoning-off tier). Models without variants skip the dialog entirely.
- Writes are transactional without leaving backup files behind: comments and foreign keys in `opencode.json[c]` are preserved via targeted JSONC edits, a concurrent external edit aborts the write, and on failure the original content is restored from the in-memory snapshot. The only backups on disk are the installer's `tui.json.bak`/`package.json.bak` (a single fixed file each, overwritten on every install/uninstall).
- **Hot apply:** after a successful write the wizard applies the changes live to the OpenCode server it is running in — project scope disposes the project instance, global scope routes the new assignments through `PATCH /global/config` (removals are written locally first and ride that reload) — so sessions on this server resolve the new models on their next message. Removal-only global changes and any hot-apply failure degrade to the previous behavior: the write stands and the toast asks for a restart. Other running OpenCode processes always need a restart. Mechanism and limits: `docs/hot-reload.md`.

Prerequisites: OpenCode >= 1.17.15, and `python3` + `jq` at install time (the installer registers the plugin in `$TARGET/tui.json` and pins the `jsonc-parser` dependency in `$TARGET/package.json`, owning only those exact values).

If the palette entry and `/model-configurator` do not appear despite a clean install, check OpenCode's TUI plugin toggle: a persisted `"plugin_enabled": { "agents-orchestrator.model-configurator": false }` in `~/.local/state/opencode/kv.json` disables it silently. Re-enable it from the TUI plugin list, or set the value to `true` (or delete the key) with no OpenCode session running, then start a fresh session.

If you used the retired shell wizard, existing `agent.<name>.model`/`variant` assignments and `profiles/*.json` keep working unchanged; the old `~/.config/opencode/cache/model-variants.json` cache is orphaned and can be deleted manually.

## Defaults When Unmapped

An agent with no mapping keeps OpenCode's inheritance: primary agents use the global `model`, and subagents inherit the model of the agent that invoked them. Deleting a mapping entry restores that behavior.
