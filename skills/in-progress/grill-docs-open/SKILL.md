---
name: grill-docs-open
description: "Trigger: grill docs open, native question UX wrapper for grilling with docs. Route to grill-with-docs while preserving its open-ended interview flow."
license: MIT
metadata:
  author: Agents Orchestrator maintainers
  inspired_by: Matt Pocock
  source_url: https://github.com/mattpocock/skills
  version: "1.0.6"
---

## Activation Contract

Use this wrapper when the user wants the `grill-with-docs` flow presented through the active runtime's native question UX when that mechanism is explicitly available in the current session.

## Hard Rules

- Load and follow `grill-with-docs`; this wrapper only changes question presentation.
- Use a runtime's native question UX only when that mechanism is explicitly available in the current runtime/session.
- Native question branch: use the explicitly available mechanism that preserves the delegated question semantics; for opencode, the named example is the `question` tool when available.
- Never invent or assume a tool, prompt primitive, or UI capability that is not explicitly available.
- Preserve `grill-with-docs` semantics: ask one question at a time, keep open-ended questions open-ended, and stop/wait after each answer.
- When the native mechanism presents selectable options, put the delegated `grill-with-docs` recommendation first/recommended; if the runtime already provides a built-in custom/freeform answer field, rely on that native field instead of adding a separate selectable custom/chat option; in opencode, rely on the built-in `Type your own answer` path.
- If the native mechanism only supports bounded choices and has no custom/freeform answer field, do not force open-ended grilling questions into options; ask in normal chat instead.
- If no suitable native mechanism is explicitly available, ask in normal chat.
- Ask one question at a time, then stop and wait for the user's answer.
- Keep all other behavior aligned with `grill-with-docs` and any delegated skills it uses.

## Decision Gates

| Situation | Action |
| --- | --- |
| No native question UX is explicitly available in the current runtime/session | Ask in normal chat |
| A native question UX is explicitly available and preserves the delegated question semantics | Use that native question UX |
| Running in opencode and the `question` tool is available | Treat `question` as the native question UX branch |
| The native mechanism presents selectable options | Put the delegated `grill-with-docs` recommendation first/recommended, rely on any built-in custom/freeform answer field when present, and never add a duplicate selectable custom/chat option; for opencode, use the built-in `Type your own answer` path |
| The available native mechanism only supports bounded choices and has no custom/freeform answer field while the current grilling question is open-ended | Ask in normal chat |
| The delegated `grill-with-docs` flow genuinely requires a discrete choice and the native mechanism supports it | Use the native mechanism |

## Execution Steps

1. Load `grill-with-docs`.
2. Run its flow unchanged except for user prompt presentation.
3. For each user-facing question, apply the Decision Gates:
   - use the runtime's explicitly available native question UX when it preserves the delegated question semantics;
   - when that UX shows selectable options, put the delegated recommendation first/recommended and rely on the runtime's built-in custom/freeform answer field when present instead of adding a duplicate custom/chat option;
   - in opencode, use the `question` tool when available and rely on its built-in `Type your own answer` path for freeform answers;
   - otherwise ask in normal chat.
4. After each question, stop and wait.

## Output Contract

Return the delegated grilling question or conclusion from the active `grill-with-docs` flow.

## References

- `../grill-with-docs/SKILL.md`

## Attribution

This wrapper skill is inspired by Matt Pocock's skills at <https://github.com/mattpocock/skills> and adapts the flow for portable native question UX.
