---
name: cornell-notes
description: "Trigger: cornell note, route lesson capture, standalone one-off learning summary. Markdown Cornell profiles for durable lesson notes or independent session summaries."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.0.1"
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

Use `assets/cornell-template.md` only for staged durable non-language modules. `learning-loop` owns phase transitions, concept scope, resume, and Close; this profile owns the note format.

- **Class:** write the Mermaid `Map` and self-contained, Mentor-authored `Notes`, including one row explaining the central model and its relationships. Set `> Teach-back: required` for a load-bearing concept, otherwise `> Teach-back: not-required`; never persist the choice placeholder.
- **Pending state:** keep the template's exact `Summary` and `Recall hand-off` markers. Do not request a Summary, schedule cards, or use these cues in quizzes at Class.
- **Summary:** finalize only after the linked exercise has `Result: done` and the learner demonstrates the practiced concepts in 2–3 sentences. Follow `learning-loop`'s correct-first feedback and revision loop; pauses or unresolved gaps keep the markers pending. Record only the learner's wording, lightly cleaned without adding concepts.
- **Recall:** schedule every cue via `spaced-recall`, then replace the pending hand-off with actual card IDs matching the exercise. Only then do cues enter the quiz bank.
- **Teach-back:** `not-required` is final. Replace `required` with `teachbacks/NNNN-<concept>.md` only after that artifact exists. A Verdict with gaps keeps the module open until a later gap-free teach-back replaces the header path.

#### Staged Output Contract

At Class, return the note path, cue questions, and `consolidation pending`; do not claim scheduled cards. At finalization, return the path, cues, and scheduling confirmation. Flag unresolved concepts to `learning-loop`.

### Other Route Lessons and Compatibility

- Other route lessons keep one-pass capture: metadata, Mermaid `Map`, 3–7 cue/Notes rows, a 2–3 sentence learner Summary, and scheduled recall IDs. Reteach when needed; never invent the Summary. No staged markers, Practice prerequisite, scoped-gap rules, or Teach-back header apply.
- `language-loop` keeps its two-wave flow. Finalized legacy notes with learner Summary and actual recall IDs remain unchanged; do not migrate them.

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
