# Meta Domain

Prompt, skill-authoring, registry, and agent-model configuration utilities for this artifact repository.

## Quick path

1. Install the `meta` domain.
2. Use `/absorb` or `/models-profiles`.
3. Reinstall after changing a pinned plugin.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/absorb` | Compare an external AI harness | Evidence-backed adoption report |
| `/models-profiles` | Assign agent models and variants | Targeted OpenCode configuration |
| OpenCode startup | Generate the resolved skill snapshot | `.ai/atl/skill-registry.md` |

External plugin descriptors pin either GitHub bundles by commit and SHA-256 or npm packages by exact version and runtime target. This repository owns those locks; each external repository owns its plugin implementation and tests. See [agent models](../../docs/agent-models.md) and [Graphify](../../docs/graphify.md).

`opencode-skill-registry` is the sole owner of `.ai/atl/skill-registry.md`. The file is an automatic snapshot of OpenCode's resolved `/skill` catalog and refreshes when OpenCode restarts; there is no manual generator in this repository.

After changing this domain, run the affected [Meta manual tests](manual-tests.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Command | `/absorb` | Compares external AI harness practices |
| Skill | `absorb` | Extracts reusable external harness practices |
| Skill | `prompt-structure-writer` | Turns ideas into executable prompts |
| Skill | `skill-creator` | Creates Agent Skills-compliant skills |
| External npm server plugin | `opencode-skill-registry` | Generates the resolved skill snapshot |
| External npm TUI plugin | `opencode-models-presets` | Assigns agent models and variants |
