---
name: spaced-recall
description: "Trigger: spaced repetition, review queue, repaso espaciado, repeticion espaciada, learn review. Leitner-style spaced repetition over a Markdown review queue: due-check on every invocation, graded retrieval, interval scheduling."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.2.0"
---

# Spaced Recall

## Activation Contract

Use when a learning flow needs long-term retention: scheduling new recall cards, checking which cards are due, or running a review session. Owns `review-queue.md` under each `.ai/learning/<topic-slug>/`, following `assets/review-queue-template.md`.

Do not use for ungraded quizzes — quiz mode reads the same cues but never moves boxes; only review sessions do.

## Hard Rules

- There is no scheduler: scheduling is **pull-based**. The due-check below runs at the start of every `/learn` invocation, in every mode.
- Never reveal an answer before the learner attempts recall. Retrieval effort is the mechanism, not a formality.
- Grading questions go through `native-question-ux`, recommended option first.
- **Today's date comes from the environment**, never from a guess: read it from the runtime context or the agent's allow-listed `date` command. If it is genuinely unavailable, confirm the date with the learner before any due-check or box transition.
- Dates are absolute `YYYY-MM-DD`. Compute `Next` strictly from the transition table; never invent or backfill review history.
- **Deterministic math over mental math**: when the runtime exposes recall calculator tools (for example `recall_due` and `recall_schedule` from the learning domain's `recall-calc` plugin), take due lists, box transitions, and every `Last`/`Next` date from them and transcribe the results into `review-queue.md` — never recompute a date the calculator already returned. Without such tools, apply the tables below manually.
- Card IDs (`C-NNNN`) are unique per topic and never reused; each card links back to its source Cornell note. In an all-topic review, reference cards as `<topic-slug>/C-NNNN` because IDs are only unique within a topic.
- **Interleave, don't block**: when due cards span several notes or topics, order the session by mixing sources rather than grouping all of one note's cards together — interleaving is part of the retention mechanism, not a cosmetic choice.

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

On every grade set `Last` = today and `Next` = today + the new box's interval — including `Hard`, which keeps the box but still re-dates from today. Good or Easy at box 5 → move to `## Mastered` with the date.

**Leeches**: when a card is graded `Again` for the 3rd time, mark it `⚠ leech` in its `Cue` cell and stop letting it churn — propose (via `native-question-ux`) reformulating the cue in place or splitting it into two clearer cards, and log the decision in the topic's `path.md`. A leech is a signal the cue is badly formed or the underlying lesson needs a re-teach, not a card to keep failing.

## Due-Check Contract

1. Read every `review-queue.md` (active topic, or all topics for `status`/bare `review`).
2. List cards with `Next` ≤ today, oldest first (via a due-check calculator tool such as `recall_due` when available).
3. Offer — never force — to review them before new material: "You have N reviews due; do them first?" via `native-question-ux`.
4. **Cap the backlog per session**: offer due cards in chunks of ~15, oldest-first within the chunk, and confirm before continuing to the next chunk. A large backlog is cleared over several passes, not one exhausting marathon.

## Review Session

Take up to ~15 due cards, interleaved across their source notes/topics rather than grouped. For each card, in order: ask the Cue and wait for the learner's attempt → reveal the Notes answer (from the linked note) → ask for the grade (Good recommended by default) → apply the transition (via a calculator tool such as `recall_schedule` when available) and update Box/Last/Next. Watch for the 3rd `Again` on a card and apply the leech rule. Close by reporting cards reviewed, grades, promotions/demotions, mastered cards, any leeches flagged, and the next due date.

## Output Contract

Return: due count found, cards reviewed with grade and new box, cards added (ID + cue), and the earliest upcoming `Next` date. State plainly when the learner failed a card; failed cards are the loop's most valuable signal.
