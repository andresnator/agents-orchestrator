---
name: spaced-recall
description: "Trigger: spaced repetition, review queue, repaso espaciado, repeticion espaciada, learn review. Leitner-style spaced repetition over a Markdown review queue: due-check on every invocation, graded retrieval, interval scheduling."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.3.0"
---

# Spaced Recall

## Activation Contract

Use for long-term retention: schedule cards, check due cards, or run reviews. Own each `.ai/learning/<topic-slug>/review-queue.md` per `assets/review-queue-template.md`.

Do not use for ungraded quizzes: they read cues but never move boxes; only reviews do.

## Hard Rules

- No scheduler: pull-based due-check starts every `/learn` invocation in every mode.
- Never reveal answers before a recall attempt. Ask each cue in normal chat; wait for free text.
- Use `question` for closed grade `Again | Hard | Good | Easy`; recommend `Good` first by default.
- Get today from runtime context or allow-listed `date`, never guess. If genuinely unavailable, confirm it before due-checks/box transitions.
- Use absolute `YYYY-MM-DD`; derive `Next` strictly from transitions. Never invent/backfill history.
- Prefer deterministic calculator tools such as `recall_due`/`recall_schedule`: transcribe their due lists, box transitions, and every `Last`/`Next`; never recompute returned dates. Without tools, apply these tables manually.
- `C-NNNN` IDs are unique per topic, never reused, and link a source Cornell note. In all-topic reviews use `<topic-slug>/C-NNNN` because IDs are not cross-topic unique.
- Interleave due cards across notes/topics; never group by one source. Interleaving affects retention.

## Queue Format

Per-topic `review-queue.md`:

| Column | Meaning |
| --- | --- |
| ID | `C-NNNN`, sequential per topic |
| Cue | Retrieval question, verbatim from Cornell note |
| Box | Leitner box 1–5 |
| Last | Last review (or creation) date |
| Next | Due date = Last + box interval |
| Note | Relative source Cornell-note path |

Mastered cards move to the `## Mastered` section and leave the schedule.

## Box Transitions

Intervals: box 1 +1d · box 2 +3d · box 3 +7d · box 4 +14d · box 5 +30d. New card: box 1, `Next` tomorrow.

| Grade | Meaning | Transition |
| --- | --- | --- |
| Again | No recall | box 1 |
| Hard | Heavy/partial recall | same box |
| Good | Correct recall | box +1 |
| Easy | Instant recall | box +2 (max 5) |

Every grade sets `Last` = today and `Next` = today + new-box interval. `Hard` keeps its box but re-dates from today. `Good`/`Easy` at box 5 moves to `## Mastered` with date.

**Leeches:** On a 3rd `Again`, stop before persistence. Use `question` for closed choice: reformulate in place or split into two clearer cards. After the learner chooses, mark `⚠ leech` in the queue and log the decision in topic `path.md` through one compound card handoff. A leech signals a bad cue or needed re-teach, not a card to keep failing.

## Due-Check Contract

1. Read every active-topic queue, or all queues for `status`/bare `review`.
2. List `Next` ≤ today oldest-first, using available tools such as `recall_due`.
3. Offer, never force, review before new material via closed `question`: "You have N reviews due; do them first?".
4. Offer ~15-card chunks, oldest-first within each; confirm before the next chunk. Clear large backlogs over several passes, never one marathon.

## Review Session

Take up to ~15 due cards, interleaved by source. For each, in order: ask Cue in normal chat and wait → reveal linked-note answer → ask grade via `question` (`Good` recommended first) → calculate transition with `recall_schedule` when available and exact anchored mutations → on 3rd `Again`, get leech choice before persistence → launch one fresh `learning-recorder` with `background: true`, unique topic/card/review-ordinal description, and no `task_id` → immediately ask the next cue without waiting for receipt. Use one compound queue/path-log handoff per leech. Keep non-review checkpoints foreground.

Track each runtime task ID until automatic notification settles it. `OK` settles only its ID, with no reread, repeated cue, or open-cue advance. `BLOCK`, `FAIL`, error, cancellation, timeout, or unsupported/rejected background launch triggers Mentor's fresh-read, card-scoped direct fallback—never retry, resume, poll, or substitute foreground recording. Notifications alone settle tasks and never alter review progression. After the final card, withhold persisted artifacts/next due date until all IDs settle by `OK` or fallback; meanwhile report only that persistence is finishing. Never sleep, request status, or fabricate completion.

## Output Contract

Return due count; reviewed cards with grade/new box; added cards with ID/cue; earliest upcoming `Next`. State failed cards plainly; they are the loop's most valuable signal.
