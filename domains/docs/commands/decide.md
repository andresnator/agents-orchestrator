---
description: Decision interview that converges into an ADR
argument-hint: "[technical decision or problem to decide]"
---
# /decide

Interview the user about a technical decision until it is ADR-ready, then draft the ADR. If no decision or problem is provided, ask for it before starting.

## Flow

1. Load the `grilling` and `adr` skills. Follow `grilling` throughout: one question at a time via `native-question-ux`, attach a recommended answer, stop and wait, and explore the codebase instead of asking when the answer is discoverable.
2. Interview until each ADR ingredient is solid: the context and forces driving the decision, the constraints that bound it, at least two genuinely considered options with real trade-offs, the chosen option and its rationale, and the consequences (positive, negative, follow-up work).
3. Challenge weak spots before drafting: an option set with one real candidate, consequences nobody named, or rationale that restates the choice.
4. When the ingredients converge, draft the ADR following the `adr` skill.

## Write Step

This flow is plan-only until approval: present the ADR draft inline and ask once whether to write it. On yes, write exactly one ADR file at the location the `adr` skill or the project's existing ADR convention dictates; on no, leave the draft inline.

Interview in the user's language; the ADR artifact defaults to English.
