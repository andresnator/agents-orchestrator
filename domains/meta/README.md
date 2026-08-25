# Meta Domain

Prompt, skill, registry, and agent-model configuration utilities for this artifact repository.

## Quick path

1. Install the `meta` domain.
2. Use `/absorb`, `/prompt-checker`, or `/model-configurator`.
3. Reinstall after changing a pinned plugin or model profile.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/absorb` | Compare an external AI harness | Evidence-backed adoption report |
| `/prompt-checker` | Improve prompt text | Evaluated and revised prompt |
| `/model-configurator` | Assign agent models and variants | Targeted OpenCode configuration |
| OpenCode startup | Refresh the skill registry | `.ai/atl/skill-registry.md` |

External plugin descriptors pin release artifacts by commit and SHA-256. This repository owns those locks and abstract `profiles/`; each external repository owns its plugin implementation and tests. See [agent models](../../docs/agent-models.md) and [Graphify](../../docs/graphify.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/absorb` | Compares external AI harness practices |
| Command | `/prompt-checker` | Evaluates and refines prompts |
| Skill | `absorb` | Extracts reusable external harness practices |
| Skill | `prompt-structure-writer` | Turns ideas into executable prompts |
| Skill | `skill-creator` | Creates Agent Skills-compliant skills |
| Skill | `skill-registry` | Generates the project skill registry |
| External server plugin | `skill-registry` | Refreshes the runtime skill index |
| External TUI plugin | `model-configurator` | Assigns agent models and variants |
