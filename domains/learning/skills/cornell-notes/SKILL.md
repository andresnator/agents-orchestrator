---
name: cornell-notes
description: "Trigger: cornell note, cornell notes, nota cornell, learning lesson capture, bounded session summary. Full learning-path notes plus an additive compact Cornell format for explicitly saved sessions."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.1.0"
---

# Cornell Notes

## Activation Contract

Use when a learning flow captures a micro-lesson as a note: the 10% formal step of the `learning-loop`, or any time the user asks for a Cornell-style note on a concept just studied. Notes live at `.ai/learning/<topic-slug>/notes/NNNN-<lesson>.md`, numbered sequentially from `0001`.

Do not use for book-chapter synthesis — that is the `summarize` skill; this skill defines the capture format inside a learning path.

## Hard Rules

- Follow `assets/cornell-template.md`: metadata header, Mermaid map, cue/notes table, summary, recall hand-off.
- **Cues are retrieval questions**, never topic labels: "What does the filter chain decide per request?" not "Filter chain". Each cue must be answerable from its Notes cell alone.
- 3–7 cues per note; notes cells stay concise (2–4 lines each). If a lesson needs more, it is two lessons.
- The **Summary is the learner's voice**: ask them to state it in 2–3 sentences and record what they say (lightly cleaned up); never invent it. If they can't, that is a signal — reteach before closing.
- Every note embeds at least one Mermaid diagram (`mindmap` for concept overviews, `graph TD` for processes, `sequenceDiagram` for interactions) and cites at least one primary source in the header.
- Every cue is handed to `spaced-recall` as a new card, and the note's `Recall hand-off` line lists the card IDs. Cues are also the topic's quiz bank.
- Notes are Markdown in English; never HTML.

## Format

See `assets/cornell-template.md`. Structure:

1. `# NNNN — {Lesson title}` + header quote block (topic, module, date, sources).
2. `## Map` — Mermaid diagram of the lesson's concepts.
3. `## Notes (Cornell)` — two-column table `| Cue (question) | Notes |`.
4. `## Summary` — 2–3 sentences in the learner's own words.
5. `## Recall hand-off` — card IDs added to `review-queue.md`.

## Output Contract

Return the note path, the list of new cues (as questions), and confirmation that each cue was scheduled via `spaced-recall`. Flag any cue the learner could not answer during capture so the loop can reinforce it.

## Compact Session Summary Variant

Use this additive variant only when a bounded `learning-session` receives an explicit save or update request. It does not change the full learning-path note contract above.

- Follow `assets/session-summary-template.md`.
- Write one document in the conversation language with a title, date, brief synthesis, and lightweight Cornell table of guide questions and canonical answers.
- Add application, steps, examples, limits, unresolved questions, or sources only when they exist in the covered material and add value.
- Merge semantically equivalent ideas, preserve distinct nuances, and let explicit corrections replace superseded claims. Mark unresolved differences.
- Redact unnecessary sensitive data. Never invent facts, sources, examples, opinions, or conclusions not covered in the session.
- Do not apply the full variant's numbering, learner-voice, Mermaid, source, scheduling, or output-receipt requirements to this compact variant.
