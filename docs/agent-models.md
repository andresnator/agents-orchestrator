# Per-Agent Model, Provider, And Variant Assignment

Repo agents never hardcode `model:` in frontmatter. Every agent file under `domains/*/agents/` stays provider-agnostic so the same artifacts work for any user, provider set, or budget. Model assignment is user state and lives in the user's OpenCode config, exactly like API keys.

## Quick Path

1. Install the `meta` domain, then open `/model-configurator` from OpenCode.
2. Choose global or project scope, select an agent group or profile, and assign models and variants.
3. Review and apply. The current server hot-applies supported changes; the wizard tells you when a restart is still required.

Use the manual configuration below only when the TUI plugin is unavailable or you need to manage the JSON directly.

## How It Works

OpenCode merges agent definitions by name: a Markdown agent installed by this repo and an `agent.<name>` block in `opencode.json` combine into one agent. Global config (`~/.config/opencode/opencode.json`) and project config merge too, with the project taking precedence. That native merge already covers static per-agent assignment — no repo mechanism is required.

Model syntax is `provider_id/model_id`. A per-agent `variant` picks a model variant by name (it applies only when the agent uses its configured `model`). Per-agent `options` are still passed through to the provider for anything a variant does not cover.

## Manual Configuration

Merge a block like this into your `opencode.json` (global for your default policy, project-level to override per repo):

```json
{
  "agent": {
    "orchestraitor": { "model": "anthropic/claude-opus-4-8", "variant": "high" },
    "sdd-explore":   { "model": "anthropic/claude-haiku-4-5" },
    "sdd-implement": { "model": "anthropic/claude-sonnet-4-5", "variant": "high" },
    "sdd-verify":    { "model": "anthropic/claude-sonnet-4-5" },
    "jd-judge-a":    { "model": "openai/gpt-5.1" },
    "jd-judge-b":    { "model": "google/gemini-2.5-pro" },
    "jd-solo":       { "model": "anthropic/claude-haiku-4-5" }
  }
}
```

Putting `jd-judge-a` and `jd-judge-b` on different providers strengthens the blind adversarial review: the judges cannot share model-specific blind spots. `jd-solo` is the single light-mode judge — mapping it to a cheap fast model is the point of the tier (profile tier `judge-solo`).

## Minion Setup

The MinionS pattern (HazyResearch, ICML 2025) pairs a frontier supervisor that decomposes work with cheap workers that execute scoped subtasks in parallel, and reports roughly 5x lower cost at ~98% of frontier quality. The harness already implements the architecture — brief-scoped subagents, parallel waves, compact returns, supervisor-side verification — so the only missing half is the cost asymmetry, and that is pure model assignment. Without a mapping there is none: subagents inherit the invoking agent's model (see "Defaults When Unmapped"), so every worker runs on the supervisor's expensive model.

Recommended classification:

**Minions — cheap/fast tier.** These agents work from a complete brief, return a fixed compact format, and everything they produce is verified by the orchestrator or a downstream gate, so a weak model degrades latency more than outcomes:

- `sdd-explore`, `arch-analyzer`, `refactor-analyzer`, `boundary-inspector` — context reading and compression, the core MinionS worker use case
- `sdd-proposal`, `sdd-spec`, `sdd-tasks` — mechanical drafting from decisions already made in the brief
- `jd-solo` — already documented as the cheap fast tier
- `english-tutor` — utility

**Frontier tier.** Decisions, judgment, and the verification that backstops the minions:

- `orchestraitor`, `deep-planner`, `refactor-planner`, `architect` — supervisors (variant `high`)
- `sdd-verify` — aggregation/verification is the "cloud side" of the pattern; a cheap verifier invalidates the safety net that makes cheap workers acceptable (variant `high`)
- `jd-judge-a` / `jd-judge-b` — variant `high`, distinct providers (rule above)

**Middle tier — do not degrade to minion:**

- `sdd-implement`, `jd-fix` — write real code; medium-high quality
- `sdd-design` — makes design decisions, not mechanical drafting; deliberately split from the other three drafters, which is the one place this classification diverges from `profiles/default.json`'s `drafting` tier

The experimental worktree swarm makes the same policy measurable rather than assumed: keep `sdd-swarm` on the frontier tier, map `sdd-swarm-worker` to the candidate worker tier, and use `sdd-swarm-baseline` only for the single-agent control arm. `scripts/benchmark-sdd-swarm.sh` compares that mapping against a same-model swarm before it is promoted beyond the POC.

Apply it with `/model-configurator` by browsing the agent groups (or a profile plus per-agent overrides), and use **Apply and save as preset** to re-apply the whole mapping in two steps later. Serving the minion tier from a local provider (e.g. Ollama or [LM Studio on another computer in the LAN](lm-studio.md)) additionally gives the paper's privacy property: the heavy context stays on machines you control.

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

The meta domain installs the external OpenCode TUI plugin [`model-configurator`](https://github.com/andresnator/opencode-agent-model-configurator), a staged assistant over the recipe above. Open it from the command palette ("Configure agent models") or with `/model-configurator`. It walks these stages:

1. **Scope** — global or the current project. Each option shows a short target path (`~/.config/opencode/opencode.json[c]`, `.opencode/opencode.json[c]`) and warns when `OPENCODE_CONFIG`/`OPENCODE_CONFIG_CONTENT` can eclipse it.
2. **Agent hub** — one dialog listing every agent the running server knows (built-in, repo, and user agents alike) grouped by **parent**, the tier **profiles** from `profiles/` (invalid ones are skipped with a warning), and your **saved presets** (see below). Three paths branch from here:
   - **Group** — opens that parent's agent list: the primary itself plus the subagents it delegates to (with the built-in fuzzy search). Picking an agent offers keep current / inherit / a model from the live catalog, then a variant; you return to the same list with the pending change marked (`● agent`). An **All agents** row makes the same decision once and fans it out to every agent in the group (keep current clears all of the group's pending decisions). `esc` or **Done** goes back to the hub, where you can enter another group — once anything is pending, a **Review N pending change(s)** row jumps straight to Review.
   - **Profile** — continues through Tiers and Overrides below.
   - **Preset** — opens **Apply** / **Delete**; Apply re-validates its assignments against the live catalog (stale entries — unknown agent, gone model, or gone variant — are dropped after a confirm; a fully stale preset warns and returns) and jumps straight to Review, skipping tiers and overrides.
3. **Tiers** — per non-empty tier: keep, inherit, or pick a model from the live catalog of connected providers, then one of that model's variants (the profile's suggested variant is preselected when available). Profile path only.
4. **Overrides** — optional per-agent corrections: use the tier decision, keep current, inherit, or pick another model/variant. **→ Next agent** / **← Prev agent** move to the adjacent agent (wrapping around) without changing the current one, so you can page through agents to tweak just a few. Profile path only.
5. **Review** — a semantic `agent: before -> after` summary as disabled rows grouped by parent. The catalog is refreshed and every selection revalidated (stale picks abort without writing). Choose **Apply**, **Apply and save as preset** (prompts for a name), or **Cancel** (writes nothing).

Behavior notes:

- **Back navigation:** every dialog shows an `esc:` hint. `esc` goes back one level (agent list → agent hub → Scope); on the first dialog (Scope) it closes the configurator. **Cancel** on Review aborts entirely. Backing into the Tiers stage resets any per-agent overrides made afterward (they are rebuilt from the tier decisions), and choosing a profile likewise rebuilds pending decisions from its tiers.
- **Where the agent list comes from:** live from the running server (`GET /agent`), which already merges OpenCode's built-ins, this repo's agents, and any agent you installed yourself. Nothing is snapshotted at install time and no opt-in metadata is needed, so `build`, `plan`, and third-party agents are configurable exactly like the repo's own. A server too old to answer, or one reporting no agents, stops the wizard with a toast instead of opening a dialog.
- **How groups are derived:** from each primary's `task` permission rules, evaluated the way OpenCode evaluates them (last matching rule wins, `*` and `?` glob, `ask` counts as permitted). A subagent becomes a child only when a rule with a *specific* pattern permits it, so a primary that merely inherits the catch-all `allow` — every built-in — is shown as **Delegates to any subagent** rather than adopting every subagent on the server. A subagent claimed by several primaries appears under each (decisions still dedupe by name), an agent with `mode: "all"` is both a parent and a claimable child, and subagents nobody claims explicitly land in **Other subagents** so everything stays reachable. Custom parents sort before OpenCode's native ones. In Review, each row is filed under the first parent in hub order that claims it.
- **Internal agents:** the ones OpenCode marks `hidden` (`title`, `summary`, `compaction`) are excluded by default; a **Show internal agents** row in the hub reveals them and toggles back.
- **Standalone install:** installing only the meta domain is enough. For installation without this repository, use the standalone plugin's README. Profiles are optional (no `profiles/` directory simply means no Profiles rows), a malformed profile is skipped with a warning instead of blocking the run, and a tier naming agents this server does not have keeps the agents it does have and warns about the rest.
- **Saved presets** capture the final concrete `agent → model/variant` result so you can re-apply a whole configuration in about two steps. They live user-side in `~/.config/opencode/model-configurator-presets.json` (always the global config root, independent of the chosen scope) and hold concrete model ids — the repo `profiles/*.json` stay abstract. The name prompt always opens empty; saving under an existing name asks Overwrite / Choose another name first. Inherited (model-less) agents are omitted from the preset.
- Profiles (`profiles/<name>.json`) map agents to abstract tiers with an optional suggested variant; they never contain concrete model ids, so they work for any provider set. The installer copies them beside the pinned external bundle, so re-run `installers/opencode.sh install` after changing profiles or updating the external descriptor.
- The model/variant catalog comes live from the running OpenCode server (`connected` providers intersected with the full catalog) — no cache file and no external process.
- Choosing `inherit` deletes only that agent's `model`/`variant` keys at the selected scope (pruning an emptied agent entry), restoring default inheritance; `keep` is always a no-op.
- In the variant dialog, **Default (no variant)** writes no `variant` key (the provider default applies); it is distinct from a provider-supplied `none` variant, which is a real value listed by name (e.g. OpenAI's reasoning-off tier). Models without variants skip the dialog entirely.
- Writes are transactional without leaving backup files behind: comments and foreign keys in `opencode.json[c]` are preserved via targeted JSONC edits, a concurrent external edit aborts the write, and on failure the original content is restored from the in-memory snapshot. The installer may keep one fixed `tui.json.bak` while managing the plugin entry.
- **Hot apply:** after a successful write the wizard applies the changes live to the OpenCode server it is running in — project scope disposes the project instance, global scope routes the new assignments through `PATCH /global/config` (removals are written locally first and ride that reload) — so sessions on this server resolve the new models on their next message. Removal-only global changes and any hot-apply failure degrade to the previous behavior: the write stands and the toast asks for a restart. Other running OpenCode processes always need a restart. Mechanism and limits: `docs/hot-reload.md`.

Prerequisites: OpenCode >= 1.17.15, plus `curl`, `jq`, `python3`, and `shasum` or `sha256sum` at install time. The installer downloads and verifies the pinned self-contained bundle, copies the profiles, and owns only the exact plugin entry it adds to `$TARGET/tui.json`.

If the palette entry and `/model-configurator` do not appear despite a clean install, check OpenCode's TUI plugin toggle: a persisted `"plugin_enabled": { "andresnator.agent-model-configurator": false }` in `~/.local/state/opencode/kv.json` disables it silently. Re-enable it from the TUI plugin list, or set the value to `true` (or delete the key) with no OpenCode session running, then start a fresh session.

If you used the retired shell wizard, existing `agent.<name>.model`/`variant` assignments and `profiles/*.json` keep working unchanged; the old `~/.config/opencode/cache/model-variants.json` cache is orphaned and can be deleted manually.

## Defaults When Unmapped

An agent with no mapping keeps OpenCode's inheritance: primary agents use the global `model`, and subagents inherit the model of the agent that invoked them. Deleting a mapping entry restores that behavior.
