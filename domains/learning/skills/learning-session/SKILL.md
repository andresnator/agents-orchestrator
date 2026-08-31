---
name: learning-session
description: "Trigger: one-off /learn session, bounded explanation, learn something now without a path. Answer-first teaching in the user's language with progressive disclosure and no automatic persistence."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.0.0"
---

# Learning Session

## Activation Contract

Use after `mentor` has classified the raw request as one-off learning: it is clearly answerable in the current interaction and the user did not request a route, progress tracking, several sessions, review, repetition, or ongoing follow-up. `/learn session <request>` selects this skill explicitly; strip `session` before teaching.

Do not use for durable learning paths, existing `/learn` modes, book-chapter synthesis (`summarize`), or on-demand English correction outside `/learn` (`english-tutor`). Resolve an ambiguous topic before loading this skill.

## Teaching Contract

- Lead with the direct answer in the user's language. Reveal the essential model first, then examples, edge cases, or deeper detail only when they help.
- Adapt terminology and pace to the learner's visible level. Explain technical literals exactly; never dilute negations, limits, or safety boundaries.
- Prefer one useful interactive question. Ask no more than two questions before stopping for the learner's response; ask none when the request is already complete without one.
- Use only sources actually needed for the answer and identify them when used. Never invent a source for the later summary.
- Do not run a due-check or inspect `.ai/learning/`. Do not create or update a mission, path, route note, lesson note, exercise, quiz, card, queue, dashboard, language gap, or any other durable learning artifact.
- Do not persist automatically or merely because the session ends. Only the learner's explicit positive request to save may start Mentor's `learning-summarizer` handoff.

## Save Boundary

When the learner explicitly asks to save, keep teaching independent from persistence. Mentor passes only the pertinent session segment, conversation language, and sources actually used to one fresh background `learning-summarizer`; the summarizer owns the standalone Cornell artifact. Never convert the session into a route or reuse `learning-recorder` for this summary.

## Output Contract

Return the answer first, followed only by the next layer of explanation needed now. If an interactive question would improve understanding, ask it in normal chat and wait after at most the second question.
