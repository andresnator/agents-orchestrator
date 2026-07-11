---
name: spaced-recall
description: "Trigger: spaced repetition, review queue, repaso espaciado, repeticion espaciada, learn review. Leitner-style spaced repetition over a Markdown review queue: due-check on every invocation, graded retrieval, interval scheduling."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "1.0.0"
---

# Spaced Recall

## Activation Contract

Use when a learning flow needs long-term retention: scheduling new recall cards, checking which cards are due, or running a review session. Owns `review-queue.md` under each `.ai/learning/<topic-slug>/`, following `assets/review-queue-template.md`.

Do not use for ungraded quizzes — quiz mode reads the same cues but never moves boxes; only review sessions do.

## Hard Rules

- There is no scheduler: scheduling is **pull-based**. The due-check below runs at the start of every `/learn` invocation, in every mode.
- Never reveal an answer before the learner attempts recall. Retrieval effort is the mechanism, not a formality.
- Grading questions go through `native-question-ux`, recommended option first.
- Dates are absolute `YYYY-MM-DD`. Compute `Next` strictly from the transition table; never invent or backfill review history.
- Card IDs (`C-NNNN`) are unique per topic and never reused; each card links back to its source Cornell note.

## Queue Format

`review-queue.md` per topic (see `assets/review-queue-template.md`):

| Column | Meaning |
| --- | --- |
| ID | `C-NNNN`, sequential per topic |
| Cue | The retrieval question, verbatim from the Cornell note |
| Box | Leitner box 1–5 |
| Last | Date of last review (or creation) |
| Next | Due date = Last + box interval |
| Note | Relative path to the source Cornell note |

Mastered cards move to the `## Mastered` section and leave the schedule.

## Box Transitions

Intervals: box 1 → +1d · box 2 → +3d · box 3 → +7d · box 4 → +14d · box 5 → +30d. New card → box 1, `Next` = tomorrow.

| Grade | Meaning | Transition |
| --- | --- | --- |
| Again | Could not recall | → box 1 |
| Hard | Recalled with heavy effort or partially | stays in box |
| Good | Recalled correctly | → box + 1 |
| Easy | Instant, effortless | → box + 2 (max 5) |

Good or Easy at box 5 → move to `## Mastered` with the date.

## Due-Check Contract

1. Read every `review-queue.md` (active topic, or all topics for `status`/bare `review`).
2. List cards with `Next` ≤ today, oldest first.
3. Offer — never force — to review them before new material: "You have N reviews due; do them first?" via `native-question-ux`.

## Review Session

For each due card, in order: ask the Cue and wait for the learner's attempt → reveal the Notes answer (from the linked note) → ask for the grade (Good recommended by default) → apply the transition and update Box/Last/Next. Close by reporting cards reviewed, grades, promotions/demotions, mastered cards, and the next due date.

## Output Contract

Return: due count found, cards reviewed with grade and new box, cards added (ID + cue), and the earliest upcoming `Next` date. State plainly when the learner failed a card; failed cards are the loop's most valuable signal.
