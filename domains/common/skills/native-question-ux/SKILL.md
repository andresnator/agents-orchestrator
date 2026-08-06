---
name: native-question-ux
description: "Trigger: native question ux, portable question presentation. Route bounded decisions through the runtime's native question UX and open-ended questions through plain chat."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: in-progress
  version: "1.1.0"
---

## Activation Contract

Load when another skill delegates question presentation. This skill changes only HOW questions are shown, never their semantics, wording, or order. The delegating flow owns what to ask; this owns how it appears.

## Hard Rules

- Use a runtime's native question UX only when that mechanism is explicitly available in the current runtime/session.
- Never invent or assume a tool, prompt primitive, or UI capability that is not explicitly available.
- Preserve the delegating flow's semantics: ask one question at a time, keep open-ended questions open-ended, and stop/wait after each answer.
- Reserve the native question UX for genuinely discrete, bounded-option decisions: gates, grades, confirmations, and mode choices.
- Open-ended questions — where the delegating flow expects a free-text answer (interview questions, Socratic debriefs, teach-back prompts) — are always asked in normal chat, even when the native mechanism offers a custom/freeform answer field.
- For bounded questions, when the native mechanism presents selectable options, put the delegated recommendation first/recommended; rely on any built-in custom/freeform answer field instead of adding a separate selectable custom/chat option; in opencode, rely on the built-in `Type your own answer` path.
- If no suitable native mechanism is explicitly available, ask in normal chat.
- Claude Code `AskUserQuestion` and opencode `question` are examples only; never treat either as required.

## Decision Gates

| Situation | Action |
| --- | --- |
| No native question UX is explicitly available in the current runtime/session | Ask in normal chat |
| A native question UX is explicitly available, preserves the delegated question semantics, and the current question is a discrete bounded-option decision | Use that native question UX |
| Running in opencode and the `question` tool is available | Treat `question` as the native question UX branch (bounded questions only, like every native branch) |
| The native mechanism presents selectable options for a bounded question | Put the delegated recommendation first/recommended, rely on any built-in custom/freeform field, and never add a duplicate custom/chat option; for opencode, use the `Type your own answer` path |
| The current question is open-ended (a free-text answer is expected) | Ask in normal chat — even when the native mechanism offers a custom/freeform field |
| The delegated flow genuinely requires a discrete choice and the native mechanism supports it | Use the native mechanism |

## Output Contract

Return the delegated question or answer flow unchanged; only its presentation adapts to the runtime.

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; extracted as the shared question-presentation contract for portable, agent-agnostic skills.
