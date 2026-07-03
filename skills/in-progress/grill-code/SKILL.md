---
name: grill-code
description: "Trigger: grill code, native question UX wrapper for grilling. Route to grill-me for interview-style questioning, not generic code review."
license: MIT
metadata:
  author: Agents Orchestrator maintainers
  inspired_by: Matt Pocock
  source_url: https://github.com/mattpocock/skills
  version: "1.1.0"
---

## Activation Contract

Use this wrapper when the user wants the `grill-me` flow presented through the active runtime's native question UX when that mechanism is explicitly available in the current session.

## Hard Rules

- Load and follow `grill-me`; this wrapper only changes question presentation.
- Follow the `native-question-ux` skill for all question presentation and its chat fallback; never invent or assume an unavailable tool.
- Preserve `grill-me` semantics: ask one question at a time, keep open-ended questions open-ended, and stop/wait after each answer.
- Keep all other behavior aligned with `grill-me` and any delegated skills it uses.

## Execution Steps

1. Load `grill-me`.
2. Run its flow unchanged except for question presentation.
3. Present each user-facing question through the `native-question-ux` skill.
4. After each question, stop and wait.

## Output Contract

Return the delegated grilling question or conclusion from the active `grill-me` flow.

## References

- `grill-me` skill
- `native-question-ux` skill

## Attribution

This wrapper skill is inspired by Matt Pocock's skills at <https://github.com/mattpocock/skills> and adapts the flow for portable native question UX.
