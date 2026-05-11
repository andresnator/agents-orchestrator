---
description: Coach English with corrections and practice
argument-hint: [text or coaching request]
---

# /english

## Purpose

Start an explicit English coaching turn for user-provided text, practice, or aggregate progress feedback.

## Invocation

```text
/english <text or coaching request>
```

If the text or coaching target is missing, ask one question for the text to review before continuing.

## Uses

| Agent/Skill | Purpose |
|---|---|
| `english-tutor` skill | Applies the correction method, silence rules, five-field output, and privacy boundary |
| `english-tutor` subagent | Handles bounded correction/review/progress-summary requests |

## Output

Return correction output in this order:

1. `Original`
2. `Improved`
3. `Explanation`
4. `Learning gap`
5. `Practice suggestion`

For progress feedback, summarize aggregate recurring gap categories and recommend one next practice action.

## Boundaries

- This command is opt-in only; it must not trigger unsolicited English coaching outside `/english` or another explicit tutoring request.
- Do not edit files, run commands, fetch web content, or store learner-specific data.
- Keep learner-specific history out of the public repo. Use private Notion-side `English Coach Memory` only when the host/user explicitly opts in.
- Passive/background tutoring is not implemented by this repository; it is a future host/orchestrator integration seam.
