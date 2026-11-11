# Meta Domain

Utilities for prompts, skill authoring, the skill registry, and agent-model configuration.

## Quick path

1. Install the `meta` domain.
2. Use `/ask-me` or `/models-profiles`, or ask the agent to absorb an external harness.
3. Reinstall after you change a pinned plugin.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/ask-me` | Find the skill for a use case | Ranked `oc-*` recommendations |
| `oc-absorb` skill | Compare an external AI harness | Evidence-backed adoption report |
| `/models-profiles` | Assign agent models and variants | Targeted OpenCode configuration |
| OpenCode startup | Generate the resolved skill snapshot | `.ai/atl/skill-registry.md` |

Plugin descriptors pin exact versions; external repositories own the code. Only `opencode-skill-registry` writes `.ai/atl/skill-registry.md`, on each OpenCode restart. See [agent models](../../docs/agent-models.md).

## Components

Unmarked rows are skills.

| Name | Purpose |
|---|---|
| `/ask-me` | Recommends `oc-*` skills |
| `oc-absorb` | Extracts external harness practices |
| `oc-prompt` | Turns ideas into executable prompts |
| `oc-skill-creator` | Creates Agent Skills-compliant skills |
| `opencode-skill-registry` (external npm server plugin) | Generates the resolved skill snapshot |
| `opencode-models-presets` (external npm TUI plugin) | Assigns agent models and variants |
