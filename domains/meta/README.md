# Meta Domain

Prompt, skill, and registry maintenance utilities for this artifact repo.

Command: `prompt-checker`.

Skills: `prompt-structure-writer`, `skill-creator`.

Plugins: `skill-registry`.

```mermaid
graph TD
  prompt[prompt-checker] --> writer[prompt-structure-writer]
  creator[skill-creator] --> skills[project skills]
  plugin[skill-registry plugin] --> registry[.atl/skill-registry.md]
  registry -.-> common[common question/output skills]
```
