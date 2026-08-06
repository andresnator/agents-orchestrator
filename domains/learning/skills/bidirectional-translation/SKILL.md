---
name: bidirectional-translation
description: "Trigger: BDT, bidirectional translation, retraduccion, traduccion inversa, /learn drill, language-loop active wave. Delayed retranslation drill: native → target from memory, compare vs the original, notice differences."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "1.0.0"
---

# Bidirectional Translation

## Activation Contract

Use for the active wave of `language-loop`, or for a standalone `/learn drill [unit]` session on a chosen unit (weakest-first when none is named). Requires an existing bilingual dialogue unit under `.ai/learning/<topic-slug>/dialogues/`.

Do not use as a grading instrument, for units the learner saw today (the delay IS the method — retranslation is spaced retrieval), or outside language topics.

## Hard Rules

- **Noticing over grading**: the goal is to get curious about the differences between the learner's version and the original — not to score correctness. There is no pass/fail, no exam framing.
- **Natural equivalence, never word-for-word**: a different-but-natural rendering is a success; only differences that change meaning or break the target language's structure are material.
- **From memory**: the learner translates the unit's native text back into the target language WITHOUT looking at the original. Peeking mid-attempt just converts retrieval into re-reading — restart from the previous line instead.
- **Delay is mandatory**: drill only units captured in an earlier session (the `language-loop` N−5 offset, or any unit whose passive wave is at least a few days old).
- Classify every material difference into one category: `word choice`, `structure/order`, `missing chunk`, or `grammar pattern`.
- Every difference feeds exactly one loop (see Feedback Loops) — noticing without capture is wasted retrieval.
- Honest logs: record what the learner actually produced and noticed, in the unit's retranslation log.

## Drill Protocol

1. **Setup** — open the unit's dialogue file; show the learner ONLY the native-language text.
2. **Retranslation** — the learner writes their target-language version from memory, line by line or whole, their choice.
3. **Compare** — place the learner's version beside the original target text; walk through the differences together, asking "what did the original do differently, and why might it?" before explaining.
4. **Classify** — tag each material difference with its category; ignore stylistic variation that is natural in the target language.
5. **Capture** — run the Feedback Loops below.
6. **Log** — append a row to the unit's retranslation log (date, differences by category, follow-ups created) and note the drill in `path.md`'s pacing log.

Record the session with `assets/bdt-session-template.md` when run standalone (`/learn drill`); inside a `language-loop` session the unit's retranslation log row is enough.

## Feedback Loops

- **Missing chunk / word choice** → `anki-vocab` batch candidate (register in `vocabulary.md`; Anki is its review system, no Leitner card).
- **Grammar pattern / structure-order** → `spaced-recall` card (cue: produce the pattern, not recite the rule).
- A pattern that also matches an `english-tutor` gap category → additionally append or reinforce the row in `gaps.md` so recurring gaps aggregate in one place.
- A unit with many material differences returns to the active wave later (re-drill after its next spacing interval); a near-clean retranslation retires the unit from drilling.

## Output Contract

End every drill reporting: unit drilled, differences by category, follow-ups created (cards, vocab candidates, gaps rows), and whether the unit re-enters the drill queue or retires.

## Attribution

Adapted from Luca Lampariello's bidirectional translation technique (L2→L1 at capture time, delayed L1→L2 retranslation, difference-noticing as the learning event), integrated with this repo's Leitner scheduling (`spaced-recall`) and Anki export (`anki-vocab`).
