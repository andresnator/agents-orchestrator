---
name: cornell-notes
description: "Trigger: cornell note, route lesson capture, standalone one-off learning summary. Markdown Cornell profiles for durable lesson notes or independent session summaries."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.0.0"
---

# Cornell Notes

## Activation Contract

Use one of two explicit profiles:

- **Route lesson:** the 10% formal step of `learning-loop`, or a Cornell lesson inside an existing durable topic. Notes live at `.ai/learning/<topic-slug>/notes/NNNN-<lesson>.md`, numbered sequentially from `0001`.
- **Standalone summary:** a saved one-off `learning-session`, created only by `learning-summarizer` at `.ai/learning/summaries/<YYYY-MM-DD>-<HHMMSS>-<slug>.md`.

Do not use for book-chapter synthesis — that is the `summarize` skill. Select one profile explicitly; never blend standalone summaries with route state.

## Route Lesson Profile

- **Cues are retrieval questions**, never topic labels: "What does the filter chain decide per request?" not "Filter chain". Each cue must be answerable from its Notes cell alone.
- 3–7 cues per note; Notes cells stay concise (2–4 lines each). If a lesson needs more cues, it is two lessons.
- Every note embeds at least one Mermaid diagram (`mindmap` for concept overviews, `graph TD` for processes, `sequenceDiagram` for interactions) and cites at least one primary source in the header.
- Notes are Markdown in English; never HTML.

### Staged Non-Language Module Profile

Use this staged profile, including `assets/cornell-template.md`, only when `learning-loop` is running its Class → Practice → Consolidation flow for a durable non-language module.

- At **Class**, Notes cells are self-contained and mentor-authored; at least one row explains the central model and how its concepts relate.
- Decide whether the concept is load-bearing. Render the template header as exactly `> Teach-back: required` or `> Teach-back: not-required`; never leave the choice placeholder in a persisted note.
- Write the `Map`, cues, and `Notes`, then leave the template's exact pending `Summary` and `Recall hand-off` markers. Do not ask for a summary, schedule cards, or expose these cues to quiz mode at this checkpoint.
- Finalize only after the linked exercise reports meaningful practice as `Result: done` and the learner demonstrates the concepts in a 2–3 sentence summary. State what is correct before any gap; reteach a material gap and ask for a revised summary. If the learner pauses or remains incomplete, keep the pending markers and return to consolidation later.
- The finalized **Summary is the learner's voice**: record what they say, lightly cleaned up, but never add a concept or wording they did not express. Replace the pending recall marker only after every cue has been scheduled via `spaced-recall` and actual card IDs are available.
- Once finalized, every cue is a scheduled card, the note's `Recall hand-off` lists the actual card IDs, and those cues enter the topic's quiz bank. A note whose hand-off remains pending is never a quiz source.
- When Teach-back is `required`, replace that exact value with the created relative `teachbacks/NNNN-<concept>.md` path only after the teach-back artifact exists. Its Verdict remains authoritative: gaps keep the module open, and a later gap-free teach-back replaces the header with its own path. `not-required` is already a final state.

#### Staged Format

See `assets/cornell-template.md`. Structure:

1. `# NNNN — {Lesson title}` + header quote block (topic, module, date, sources, exact Teach-back state).
2. `## Map` — Mermaid diagram of the lesson's concepts.
3. `## Notes (Cornell)` — two-column table `| Cue (question) | Notes |`.
4. `## Summary` — the exact pending marker until practice and consolidation finish; then 2–3 sentences in the learner's own words.
5. `## Recall hand-off` — the exact pending marker until consolidation; then card IDs added to `review-queue.md`.

#### Staged Output Contract

At the Class checkpoint, return the note path, staged cue questions, and `consolidation pending`; never claim that cards were scheduled. At finalization, return the note path, new cues, and confirmation that each cue was scheduled via `spaced-recall`. Flag unresolved concepts so `learning-loop` can keep the module 🔄 and reinforce them.

### Other Route Lessons and Compatibility

- A route lesson outside the staged non-language `learning-loop` module keeps the original one-pass contract: metadata, Mermaid `Map`, and 3–7 cue/Notes rows; ask for a 2–3 sentence learner Summary, record it lightly cleaned without inventing it, and reteach before closing if the learner cannot produce it; then schedule the cues and record actual recall card IDs. It does not gain pending markers, the scoped-gap state machine, a Practice prerequisite, or a Teach-back header.
- `language-loop` continues to replace the non-language module flow; never apply this staged profile to its dialogue units or route state.
- Existing route notes without staged markers or a Teach-back header stay unchanged. A legacy note with a real learner Summary and actual recall card IDs remains finalized; do not migrate it or require the new staged fields.

#### Output Contract

Return the note path, the list of new cues as questions, and confirmation that each cue was scheduled via `spaced-recall`. Flag any cue the learner could not answer during capture so the calling flow can reinforce it.

## Standalone Summary Profile

- Follow the complete format below in the conversation language; never force English.
- Start with the synthesis. Then record key questions with notes that stand alone without the transcript.
- Include an application or example only when the supplied session contains one. List only sources actually used in that session; write `None` in the conversation language when none were used.
- Mermaid is optional and appears only when it materially reduces cognitive load.
- This profile is independent: never create or update a topic, mission, path, route note, cards, review queue, quiz bank, dashboard, or recall hand-off.
- The summarizer writes one complete new file and never edits or overwrites an existing file.

### Complete Format

Translate every heading and label into the conversation language. Omit the application/example section when the supplied session has none, and omit the Mermaid section unless it materially reduces cognitive load.

````markdown
# {Session topic}

> {Localized date label}: {YYYY-MM-DD}

## {Localized synthesis heading}

{Direct summary of the central idea.}

## {Localized key questions heading}

| {Localized question label} | {Localized notes label} |
| --- | --- |
| {Key question} | {Self-contained explanation} |
| {Key question} | {Self-contained explanation} |

## {Localized application or example heading}

{Application or example supplied by the session.}

## {Localized sources heading}

- {Only sources actually used in the session, or the conversation-language equivalent of `None`.}

## {Optional localized map heading}

```mermaid
{Diagram that materially reduces cognitive load.}
```
````

### Output Contract

Return only the standalone summary path to the calling summarizer. Do not schedule cues or request any route-state mutation.
