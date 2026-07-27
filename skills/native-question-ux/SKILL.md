---
name: native-question-ux
description: "Trigger: native question ux, portable question presentation. Chat is the default for questions; route only genuinely bounded decisions through the runtime's native question UX."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: in-progress
  version: "1.2.0"
---

## Activation Contract

Load when another skill delegates question presentation. This skill changes only HOW questions are shown, never their semantics, wording, or order. The delegating flow owns what to ask; this owns how it appears.

**Chat is the default.** The native question UX is the narrow exception, not the destination. A delegating flow that says "ask through `native-question-ux`" is asking which channel fits, not asking for the question tool.

## The Bounded Test

Apply before every question. A question is bounded only if **you can enumerate its complete option set before you write the question** — the options come from the flow (a gate, a grade, a mode, a yes/no), not from your imagination.

If you have to invent plausible answers to fill the options, the question is open. Ask it in chat.

Reverse-engineering an open question into 2-4 options is the failure this skill exists to prevent. "Which area do you want to focus on?", "What is the goal of this refactor?", and "How does this concept work in your own words?" are open, even though options can be fabricated for all three.

## Hard Rules

- Ask in normal chat unless the question passes the Bounded Test **and** a native mechanism is explicitly available in the current runtime/session.
- Use a runtime's native question UX only when that mechanism is explicitly available. Never invent or assume a tool, prompt primitive, or UI capability.
- Bounded questions are gates, grades, confirmations, and mode choices — decisions whose options the flow already fixed.
- Open-ended questions — interview questions, Socratic debriefs, teach-back prompts, scope and goal questions, anything expecting a free-text answer — are always asked in normal chat, even when the native mechanism offers a custom/freeform answer field. A freeform field does not make an open question bounded.
- Preserve the delegating flow's semantics: ask one question at a time, keep open-ended questions open-ended, and stop/wait after each answer.
- For bounded questions, when the native mechanism presents selectable options, put the delegated recommendation first/recommended; rely on any built-in custom/freeform answer field instead of adding a separate selectable custom/chat option; in opencode, rely on the built-in `Type your own answer` path.
- When in doubt, ask in chat. A bounded question asked in chat costs one extra line; an open question forced into options loses the answer the user actually had.
- Claude Code `AskUserQuestion` and opencode `question` are examples only; never treat either as required.

## Decision Gates

| Situation | Action |
| --- | --- |
| The question fails the Bounded Test (options must be invented) | Ask in normal chat |
| The question is open-ended and the native mechanism offers a custom/freeform field | Ask in normal chat — the freeform field is not a substitute |
| No native question UX is explicitly available in the current runtime/session | Ask in normal chat |
| Uncertain whether the question is bounded | Ask in normal chat |
| The question passes the Bounded Test, a native mechanism is explicitly available, and it preserves the delegated semantics | Use that native question UX |
| Running in opencode and the `question` tool is available | Treat `question` as the native question UX branch (bounded questions only, like every native branch) |
| The native mechanism presents selectable options for a bounded question | Put the delegated recommendation first/recommended, rely on any built-in custom/freeform field, and never add a duplicate custom/chat option; for opencode, use the `Type your own answer` path |

## Output Contract

Return the delegated question or answer flow unchanged; only its presentation adapts to the runtime.

## Attribution

Inspired by Matt Pocock's grilling skills at <https://github.com/mattpocock/skills>; extracted as the shared question-presentation contract for portable, agent-agnostic skills.
