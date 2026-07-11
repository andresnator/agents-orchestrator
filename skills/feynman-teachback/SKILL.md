---
name: feynman-teachback
description: "Trigger: feynman, teach back, teach-back, explicamelo, metodo feynman, learn teach. Feynman-technique teach-back sessions: the learner explains a concept in simple terms to a naive-student mentor; gaps demote recall cards and drive re-study."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "1.0.0"
---

# Feynman Teach-Back

## Activation Contract

Use when the learner should prove understanding by explaining: the `teach` mode of `/learn`, the closing step of a 20% Socratic debrief, or whenever a review/quiz shows fluency without depth. Sessions are recorded at `.ai/learning/<topic-slug>/teachbacks/NNNN-<concept>.md` following `assets/teachback-template.md`.

Do not use as a lecture: in this skill the learner talks and the mentor listens, probes, and takes notes.

## Hard Rules

- The mentor plays a **curious novice** (smart, zero domain knowledge): asks short naive questions, never corrects mid-explanation, never completes the learner's sentences.
- Simple language is the test: jargon must be re-explained in plain words when the novice asks "what does that mean?". Unexplainable jargon is a gap.
- Every gap gets classified, not smoothed over: missing piece, hand-waved step, wrong claim, or jargon crutch.
- **Gap → queue**: if a gap maps to a queued cue in `review-queue.md`, grade that card `Again` (box 1, per `spaced-recall`) with today's date. A fluent teach-back never auto-promotes cards — promotion only happens in scheduled reviews.
- **Gap → source**: each gap ends with a return path — re-read a cited primary source, revisit the Cornell note, or a targeted mini-lesson next session; record it in the teach-back file.
- Close by asking the learner for one **analogy** in their own words; record it verbatim in the teach-back file and, when it improves the note, append it to the source Cornell note's Summary.
- All questions through `native-question-ux`, one at a time per `grilling`; artifacts are Markdown in English with the usual Mermaid rule when a diagram helps the explanation.

## Session Flow

1. Pick the concept: from `$ARGUMENTS`, or recommend the concept with the weakest recent review/quiz record.
2. Frame it: "Explain {concept} to me like I've never seen it. I'll interrupt like a curious novice."
3. Listen and probe: naive questions only ("why?", "what happens if...?", "what does {jargon} mean?"). Let silence and struggle happen — that is the retrieval effort.
4. Debrief: list gaps with their classification, apply the queue demotions, agree on the return path per gap.
5. Simplify: ask for the closing analogy; capture it.
6. Write `teachbacks/NNNN-<concept>.md` and update `review-queue.md` and the `path.md` log (pacing signal).

## Output Contract

Return: concept explained, gap list with classifications, cards demoted (ID → box 1), return paths agreed, the learner's analogy, and the teach-back file path. A gap-free teach-back is stated plainly too — that is evidence of storage strength, not a wasted session.
