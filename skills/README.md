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
| `english-tutor` | Explicit English coaching with five-field corrections and private Notion memory boundaries |
| `java-testing` | Canonical Java-specific unit and legacy testing guidance |
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
