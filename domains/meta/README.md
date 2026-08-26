# Meta Domain

Prompt, skill, registry, and agent-model configuration utilities for this artifact repository.

## Quick path

1. Install the `meta` domain.
2. Use `/absorb` or `/models-profiles`.
3. Reinstall after changing a pinned plugin or model profile.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/absorb` | Compare an external AI harness | Evidence-backed adoption report |
| `/models-profiles` | Assign agent models and variants | Targeted OpenCode configuration |
| OpenCode startup | Refresh the skill registry | `.ai/atl/skill-registry.md` |

External plugin descriptors pin either GitHub bundles by commit and SHA-256 or npm TUI packages by exact version. This repository owns those locks and abstract `profiles/`; each external repository owns its plugin implementation and tests. See [agent models](../../docs/agent-models.md) and [Graphify](../../docs/graphify.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/absorb` | Compares external AI harness practices |
| Skill | `absorb` | Extracts reusable external harness practices |
| Skill | `prompt-structure-writer` | Turns ideas into executable prompts |
| Skill | `skill-creator` | Creates Agent Skills-compliant skills |
| Skill | `skill-registry` | Generates the project skill registry |
| External server plugin | `skill-registry` | Refreshes the runtime skill index |
| External npm TUI plugin | `opencode-models-presets` | Assigns agent models and variants |
