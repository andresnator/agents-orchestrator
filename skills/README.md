# Skills

Skills are reusable instruction contracts. They teach an agent how to perform a capability consistently.

## Quick path

1. Create one directory per skill.
2. Put the runtime contract in `SKILL.md`.
3. Keep the body concise; move long examples to `references/` or `assets/`.

## Current skills

| Skill | Purpose |
|---|---|
| `adr` | Generate Architecture Decision Records |
| `buildable-issue` | Create agent-ready GitHub issues that are ready to build |
| `design-patterns-pragmatic` | Choose and apply design patterns only when they solve real design forces |
| `english-tutor` | Explicit English coaching with five-field corrections and private Notion memory boundaries |
| `java-api-design` | Design Java APIs with clear visibility, mutability, module, and compatibility boundaries |
| `java-clean-code` | Improve Java readability, naming, structure, and maintainability |
| `java-exception-robustness` | Design Java exception handling, resource cleanup, and failure boundaries |
| `java-immutability-modeling` | Model Java data safely with records, value objects, defensive copies, and immutable state |
| `java-secure-coding` | Review Java code against secure-coding concerns and Oracle guidance themes |
| `java-solid-design` | Evaluate Java OO design with SOLID, composition, interfaces, and dependency direction |
| `java-testing` | Canonical Java-specific unit and legacy testing guidance |
| `programming-practices-core` | Review language-agnostic programming practices such as Clean Code, DRY, KISS, YAGNI, cohesion, and coupling |
| `prd` | Create full Product Requirements Documents |
| `prd-light` | Create lightweight PRDs |
| `prompt-evaluator` | Evaluate and refine prompts |
| `refactor` | Cross-language refactoring guidance |
| `refactor-java` | Java-specific refactoring guidance |
| `rfc` | Create RFC documents |
| `service-boundary-analysis` | Inspect backend service inputs and outputs with evidence and confidence |
| `spike` | Create Jira spike tickets |
| `summarize` | Summarize long-form reading material |
| `tcr` | Apply Test && Commit || Revert workflow |
| `whisper-extract` | Transcribe and summarize audio/video |
| `write-ac` | Write acceptance criteria |

## Rule

A skill explains how to do something. An agent decides when and whether to use it.
Skill frontmatter `metadata.version` must use strict SemVer (`MAJOR.MINOR.PATCH`, for example `1.0.0`).
