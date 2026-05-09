---
name: <skill-name>
description: "Trigger: <trigger words>. <What this skill does>."
license: MIT
metadata:
  author: andresnator
  version: "1.0"
---

# Skill: <skill-name>

## Activation Contract

Use this skill when <condition>.

Do **not** use this skill when <negative trigger or boundary>.

## Responsibility

This skill teaches <workflow/pattern>. It does not <agent responsibility or forbidden action>.

## Required Context

- <Input/context item the agent must know before using this skill>

## Context Budget

- Keep this `SKILL.md` focused on the executable contract.
- Put long explanations, catalogs, matrices, and conceptual background in `references/`.
- Put reusable templates, schemas, example files, and copy-paste artifacts in `assets/`.

## Hard Rules

- <Rule>

## Decision Gates

| Condition | Action |
|---|---|
|  |  |

## Execution Steps

1. <Step>

## Output Contract

Return:

- <Output item>

## Validation Scenarios

| Scenario | Expected behavior | Must not do |
|---|---|---|
| Happy path | <Expected output or decision> | <Forbidden behavior> |
| Ambiguous input | <Question or safe fallback> | <Over-assume> |
| Out of scope | <Decline or redirect> | <Execute unrelated work> |

## References

- `references/<file>.md` — <local documentation, extended guidance, examples, or decision tables>

## Assets

- `assets/<file>` — <template, schema, sample, or reusable artifact>
