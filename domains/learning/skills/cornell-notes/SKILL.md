---
name: cornell-notes
description: "Trigger: cornell note, route lesson capture, standalone one-off learning summary. Markdown Cornell profiles for durable lesson notes or independent session summaries."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "1.1.0"
---

# Cornell Notes

## Activation Contract

Use one of two explicit profiles:

- **Route lesson:** the 10% formal step of `learning-loop`, or a Cornell lesson inside an existing durable topic. Notes live at `.ai/learning/<topic-slug>/notes/NNNN-<lesson>.md`, numbered sequentially from `0001`.
- **Standalone summary:** a saved one-off `learning-session`, created only by `learning-summarizer` at `.ai/learning/summaries/<YYYY-MM-DD>-<HHMMSS>-<slug>.md`.

Do not use for book-chapter synthesis — that is the `summarize` skill. Select one profile explicitly; never blend standalone summaries with route state.

## Route Lesson Profile

- Follow `assets/cornell-template.md`: metadata header, Mermaid map, cue/notes table, summary, recall hand-off.
- **Cues are retrieval questions**, never topic labels: "What does the filter chain decide per request?" not "Filter chain". Each cue must be answerable from its Notes cell alone.
- 3–7 cues per note; notes cells stay concise (2–4 lines each). If a lesson needs more, it is two lessons.
- The **Summary is the learner's voice**: ask them to state it in 2–3 sentences and record what they say (lightly cleaned up); never invent it. If they can't, that is a signal — reteach before closing.
- Every note embeds at least one Mermaid diagram (`mindmap` for concept overviews, `graph TD` for processes, `sequenceDiagram` for interactions) and cites at least one primary source in the header.
- Every cue is handed to `spaced-recall` as a new card, and the note's `Recall hand-off` line lists the card IDs. Cues are also the topic's quiz bank.
- Notes are Markdown in English; never HTML.

### Format

See `assets/cornell-template.md`. Structure:

1. `# NNNN — {Lesson title}` + header quote block (topic, module, date, sources).
2. `## Map` — Mermaid diagram of the lesson's concepts.
3. `## Notes (Cornell)` — two-column table `| Cue (question) | Notes |`.
4. `## Summary` — 2–3 sentences in the learner's own words.
5. `## Recall hand-off` — card IDs added to `review-queue.md`.

### Output Contract

Return the note path, the list of new cues (as questions), and confirmation that each cue was scheduled via `spaced-recall`. Flag any cue the learner could not answer during capture so the loop can reinforce it.

## Standalone Summary Profile

- Follow `assets/standalone-summary-template.md` in the conversation language; never force English.
- Start with the synthesis. Then record key questions with notes that stand alone without the transcript.
- Include an application or example only when the supplied session contains one. List only sources actually used in that session; write `None` in the conversation language when none were used.
- Mermaid is optional and appears only when it materially reduces cognitive load.
- This profile is independent: never create or update a topic, mission, path, route note, cards, review queue, quiz bank, dashboard, or recall hand-off.
- The summarizer writes one complete new file and never edits or overwrites an existing file.

### Output Contract

Return only the standalone summary path to the calling summarizer. Do not schedule cues or request any route-state mutation.
