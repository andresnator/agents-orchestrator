---
name: learning-session
description: "Trigger: bounded learning request, one-off explanation, puntual learning session. Teach a concrete request now without creating durable learning state; save a compact summary only when explicitly requested."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.0.1"
---

# Bounded Learning Session

## Activation Contract

Use for a concrete learning request that can be resolved in the current session.

Direct messages and raw `/learn` prompts use the same classification.

### `learning-session/classify-bounded-request`

- Route a specific question, explanation, or small concept that can be answered now to this skill.
- Explicit modes, an existing topic selected for continuation, and clear multi-session learning, progress, or continued-practice intent remain durable learning work.
- Do not turn a bounded request into durable learning merely because it uses words such as “learn” or “teach.”

### `learning-session/resolve-ambiguity`

When “I want to learn X” is ambiguous, ask once whether the learner wants a bounded session or a multi-session path.

Do not infer the choice silently. Continue only after the learner answers.

## Session Flow

### `learning-session/no-implicit-due-check`

Do not read learning state or run the due-check when a bounded session starts.

If the learner explicitly asks what is due, run the existing `spaced-recall` due-check then.

### `learning-session/natural-teaching`

Lead with the answer, teach in short chunks, and ask questions only when they help.

- Adapt depth and examples to the learner's request and responses.
- Prefer recognition, clear headings, and progressive disclosure over long exposition.
- Never require a quiz, Feynman teach-back, or exercise.
- Offer an optional next step only when it adds value.

## Persistence Contract

### `learning-summary/explicit-persistence`

Persist only after an explicit save or update request.

- Without that request, do not create, update, or delegate any artifact.
- Choose `.ai/learning/summaries/YYYY-MM-DD-<slug>.md`; for an unrelated collision, use the next available suffix.
- Suffix unrelated collisions as `<slug>-2`, `<slug>-3`, and so on. Reuse the current session's target only for an explicit update.
- Pass exactly the seven fields `operation`, `target`, `conversation_language`, `covered_material`, `sources_used`, `explicit_corrections`, and `request_ordinal` to the authorized writer; use the names, order, and rules in the mandatory block below.

### Mandatory writer handoff

On an explicit save or update request, before any `task` call, build exactly this seven-line payload and no other fields:

```yaml
operation: <create|update>
target: <exact .ai/learning/summaries/... path>
conversation_language: <language>
covered_material: <complete material covered>
sources_used: <sources|none>
explicit_corrections: <corrections|none>
request_ordinal: <ordinal>
```

Keep each value on its field's single line. All seven fields are mandatory. Use `none` only for `sources_used` or `explicit_corrections` when applicable. If any field is absent, abort without launching a task.

Invoke only `learning-summarizer`, only with `background: true`, and omit `task_id` entirely. The description must equal `Persist learning summary operation=<create|update> target=<path> request=<ordinal>`. The active turn continues without waiting for the result.

If background execution is unavailable or the launch is rejected, do not invoke or wait for a foreground task, retry, resume, or apply any fallback. Emit exactly one line, `No se pudo guardar: <motivo>. Puedes pedir “reintenta guardarlo”.`, then stop.

Treat automatic writer notifications only as lifecycle events correlated by runtime task ID and target:

- A correlated `OK` emits exactly one line: `Resumen guardado: <ruta>`.
- A correlated `BLOCK`, `FAIL`, timeout, cancellation, or runtime error emits exactly one line: `No se pudo guardar: <motivo>. Puedes pedir “reintenta guardarlo”.`
- After that one line, stop. Do not explain, verify, re-read, answer, repeat, or advance the open interaction.

## Compact Summary Contract

A compact summary uses the conversation language and one document with a title, date, brief synthesis, and lightweight Cornell cue-and-answer table.

Use `cornell-notes` variant `assets/session-summary-template.md` and apply `cognitive-doc-design` for short, scannable chunks.

- Include application, steps, or examples only when they add value.
- Include limits, unresolved questions, or sources only when they exist and add value.
- Merge semantically equivalent ideas into one canonical formulation while preserving distinct nuances.
- Apply explicit corrections by replacing the superseded claim. Mark unresolved differences instead of silently deleting them.
- Redact credentials, secrets, and personal or sensitive details that are unnecessary for learning.
- Never invent claims, sources, examples, learner opinions, or conclusions not covered in the session.
- Do not create a mission, path, module folder, learner-voiced summary, `Recall hand-off`, or review cards.

Loading `spaced-recall` for an on-demand review does not change this compact-summary boundary. The summary may cover material discussed during that review, but it never creates, promises, schedules, or includes new cards, `review-queue.md`, `Recall hand-off`, card IDs, or a review plan. Never mutate the review system from compact-summary persistence.

## Output Contract

During teaching, return the natural answer rather than a workflow receipt. On an explicit persistence request, apply the mandatory writer handoff and continue without claiming completion before the writer reports it. A writer launch failure or correlated notification uses only its exact one-line receipt.
