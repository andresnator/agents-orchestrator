---
name: native-question-ux
description: "Trigger: native question ux, portable question presentation. Present a delegated flow's questions via the runtime's native UX with chat fallback."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: in-progress
  version: "1.0.3"
---

## Activation Contract

Load when another skill delegates question presentation. This skill changes only HOW questions are shown, never their semantics, wording, or order. The delegating flow owns what to ask; this owns how it appears.

## Hard Rules

- Use a runtime's native question UX only when that mechanism is explicitly available in the current runtime/session.
- Never invent or assume a tool, prompt primitive, or UI capability that is not explicitly available.
- Preserve the delegating flow's semantics: ask one question at a time, keep open-ended questions open-ended, and stop/wait after each answer.
- When the native mechanism presents selectable options, put the delegated recommendation first/recommended; rely on any built-in custom/freeform answer field instead of adding a separate selectable custom/chat option; in opencode, rely on the built-in `Type your own answer` path.
- If the native mechanism only supports bounded choices and has no custom/freeform field while the current question is open-ended, ask in normal chat instead.
- If no suitable native mechanism is explicitly available, ask in normal chat.
- Claude Code `AskUserQuestion` and opencode `question` are examples only; never treat either as required.

## Decision Gates

| Situation | Action |
| --- | --- |
| No native question UX is explicitly available in the current runtime/session | Ask in normal chat |
| A native question UX is explicitly available and preserves the delegated question semantics | Use that native question UX |
| Running in opencode and the `question` tool is available | Treat `question` as the native question UX branch |
| The native mechanism presents selectable options | Put the delegated recommendation first/recommended, rely on any built-in custom/freeform field, and never add a duplicate custom/chat option; for opencode, use the `Type your own answer` path |
| The mechanism only supports bounded choices, has no freeform field, and the question is open-ended | Ask in normal chat |
| The delegated flow genuinely requires a discrete choice and the native mechanism supports it | Use the native mechanism |

## Output Contract

Return the delegated question or answer flow unchanged; only its presentation adapts to the runtime.

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; extracted as the shared question-presentation contract for portable, agent-agnostic skills.
