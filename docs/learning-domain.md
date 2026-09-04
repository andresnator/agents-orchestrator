# Use the Learning Domain

Choose a one-off session for learning something now or a durable path for missions, exercises, reviews, and progress. Mentor makes that choice before it reads `.ai/learning/`.

## Quick path

```bash
installers/opencode.sh install --domain learning,common
```

Filtered installation is a sync; include every domain you want to keep in the selected list.

```text
/learn session explícame el event loop con un ejemplo
/learn path event-driven architecture para sistemas Java
```

A bare topic such as `/learn pizza` is intentionally ambiguous. Mentor first asks a one-off or durable choice using labels in the conversation language; it does not inspect existing topics to infer the answer. The internal routes remain `learning-session` and `learning-loop`.

## One-off sessions

`/learn session <request>` teaches in the user's language, answer-first and with progressive disclosure. Mentor may ask an interactive question when useful, but never more than two before waiting. The session does not run a due-check or create missions, routes, notes, exercises, cards, queues, or dashboard entries.

A clearly bounded natural prompt may select the same route without the `session` prefix. Requests for a route, multiple sessions, follow-up, progress, review, or repetition select durable learning instead.

### Save a standalone summary

Nothing is saved automatically. An explicit positive request starts one fresh `learning-summarizer` task in background with no reused task ID. Mentor sends only the pertinent session segment, its language, and sources actually used, then continues the conversation immediately.

The summarizer creates one complete file and never edits an existing one:

```text
.ai/learning/summaries/<YYYY-MM-DD>-<HHMMSS>-<slug>.md
```

The standalone Cornell profile contains an opening synthesis, key questions with notes, an application or example when present, and only sources actually used. Mermaid is optional and appears only when it reduces cognitive load. It never creates route notes, cards, recall handoffs, queues, or dashboard state.

Automatic completion never interrupts or advances the conversation. The next normal response appends exactly one brief parenthetical notice in the conversation language: a success notice says the summary was saved and includes `<path>`; a failure notice says it could not be saved. The internal `OK summary=<path>`, `BLOCK`, and `FAIL` receipts are never translated.

On rejection, unavailable background mode, timeout, cancellation, `BLOCK`, or `FAIL`, Mentor does not retry, resume, poll, or fall back to foreground or direct writing.

The literal `summaries` slug is reserved for this infrastructure. Durable discovery excludes it and resumes a topic only when its directory contains `mission.md`. If a topic title normalizes to `summaries`, Mentor proposes a distinct slug such as `summaries-topic` for confirmation.

## Durable paths

Use `/learn path <topic>` to force a durable route. Bare `/learn`, `review`, `quiz`, `map`, `teach`, `vocab`, `drill`, and `status` also remain durable.

| Command | Outcome |
|---|---|
| `/learn path <topic>` | Start or resume a durable topic |
| `/learn` | Run due-check, then continue an active topic |
| `/learn review [topic]` | Review due cards |
| `/learn quiz [topic]` | Run retrieval practice without moving boxes |
| `/learn map [topic]` | Refresh the topic map |
| `/learn teach [concept]` | Run a Feynman teach-back |
| `/learn vocab [theme]` | Export phrase-based Anki cards |
| `/learn drill [unit]` | Run delayed bidirectional translation |
| `/learn status` | Rebuild the dashboard |
| `/english [text]` | Correct, explain, or practice English |

General non-language modules follow one rule: **Mentor explains first, stops at a persisted checkpoint, and starts Practice only after later learner input signals readiness.** Language topics keep their two-wave flow; standalone summaries never use this state.

### General non-language module

| Phase | What happens | Gate to continue |
| --- | --- | --- |
| Due-check | Offer overdue reviews before new material. | Learner chooses whether to review first. |
| Class (10%) | Explain the objective, essential concepts and relationships, one non-solving example, and a recap. Persist a Mermaid `Map` and Mentor-authored `Notes`, including one row for the central model. | Persist the staged note, report module `🔄`, ask one readiness-or-clarification question, and stop. |
| Practice (70%) | After a later readiness message, assign one tangible learner-owned exercise; constrain, coach, and reveal hints without solving it. | `Result: done` after meaningful practice. |
| Consolidation | Ask for a 2–3 sentence learner summary. Confirm what is correct first; explain each material gap and request revisions one question at a time. | Accept the Summary, schedule every cue, and write the same actual card IDs to the note and exercise. |
| Debrief and Close (20%) | Capture the Socratic debrief and finish any required Feynman teach-back. | All close fields are final and required evidence is `gap-free`. |

`Notes` and `Summary` have different owners: Notes are Mentor's self-contained explanation; Summary is only the learner's wording, lightly cleaned up. Mentor explains missing concepts but never adds them to the learner's Summary. A pause or unresolved gap leaves the markers pending and the module `🔄`.

### Class checkpoint

The note header records exactly one initial state:

- `> Teach-back: required` for a load-bearing concept.
- `> Teach-back: not-required` otherwise.

Its body contains these exact markers:

```markdown
## Summary

_Pending learner summary after practice._

## Recall hand-off

Cues added to `review-queue.md`: pending until consolidation.
```

In one foreground handoff, `learning-recorder` creates the note and replaces `—` in the active `🔄` row's `10% lesson` cell with its relative link. Mentor then shows a compact recap, reports the note path and checkpoint, asks exactly one localized readiness-or-clarification question in normal chat, and stops.

- This response never creates Practice, schedules cues, or closes the module.
- A recorder receipt or automatic notification is not learner input.
- A clarification updates the staged teaching when needed, repeats the one-question boundary, and stops again.
- A later readiness message creates Practice, records its link in `70% exercise`, and initializes `Attempted: pending`, `Result: pending`, `Debrief (20%): pending until consolidation`, and `Cues sent to review queue: pending until consolidation`.
- Pending cues are not cards, are excluded from quizzes, and cannot authorize completion.

### Resume from persisted links

Start from the active `🔄` row. Its lesson and exercise links are the artifact index; never infer a target from directory contents or repeat a completed phase.

| Persisted state | Resume action |
| --- | --- |
| `10% lesson` is `—` | Run Class; create the note and replace only that cell. |
| Lesson link exists but its target is absent | Run Class; recreate that exact target without changing the cell. |
| Staged note linked; `70% exercise` is `—` | After later learner readiness, create Practice and replace only that cell. |
| Exercise link exists but its target is absent | Recreate that exact target without changing the cell; resume Practice. |
| Summary pending; `Result` is `pending`, `partial`, or `stuck at ...` | Resume Practice. |
| `Result: done`; Summary pending | Resume Consolidation at the summary or unresolved feedback loop. |
| Summary exists; recall hand-off, debrief, or exercise cue hand-off is pending | Finish Consolidation; do not close. |
| All fields final; Teach-back is `required` | Run Feynman; after its artifact exists, replace `required` with `> Teach-back: teachbacks/NNNN-<concept>.md`. |
| Referenced Teach-back reports gaps | Keep `🔄`, resolve its return paths, run another teach-back, and replace the header path. |
| All fields final; Teach-back is `not-required` or its referenced verdict is `gap-free` | Close the module. |

“All fields final” means both artifacts are linked, Summary is learner-authored, `Result: done`, debrief is captured, and the note and exercise contain the same actual card IDs. An accepted Summary creates Leitner cards at 1, 3, 7, 14, and 30-day intervals; Close still waits for debrief and any required `gap-free` evidence.

### Gaps and compatibility

| Case | Decision |
| --- | --- |
| Learner requests a supporting concept that still fits the tangible win and 3–7 cues. | Teach it now; add it to `Map`, `Notes`, cues, and practice, and require the learner's final Summary to connect it. |
| Mentor detects a gap, or the request expands scope. | Offer one localized closed choice with a recommendation: address now or defer. Use a targeted reinforcement step when needed to preserve the single win and cue limit. |
| Learner defers. | Record reinforcement in `path.md`; exclude it from the current note, Summary, cues, and exercise. A blocking gap keeps the module `🔄`. |
| Active `🔄` legacy row links a finalized note with real Summary and card IDs. | Do not migrate it, add staged markers or a Teach-back header, or ask for another Summary. Resume Practice if its exercise is absent or incomplete; create only for `—`, or recreate an absent linked target without changing its cell. Before Close, copy the note IDs to the exercise cue hand-off and finish the original debrief and conditional Feynman flow. |
| Legacy module is already ✅. | Never reopen it. |

A capstone teach-back closes the mission; reviews continue until cards are mastered.

### Background review persistence

After each review grade, Mentor starts a fresh `learning-recorder` in background and asks the next cue immediately. Completion settles only the matching task ID; it never repeats, answers, or advances an open cue. The final persisted-artifact and next-due report waits until every grade handoff settles.

Supported OpenCode builds may require this experimental flag for both detached review persistence and one-off summary saving:

```bash
export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
```

Restart OpenCode after setting it. No minimum release is claimed; check whether the installed build exposes background Task mode.

Review-card failure uses the existing fresh-read, card-scoped direct fallback under `.ai/learning/**`; summary failure never does. Neither flow retries or resumes a failed detached task.

## Language topics

Language paths use two waves:

1. Read one comprehensible bilingual dialogue.
2. After five units, translate unit N-5 from memory and compare it with the original.
3. Send phrases to Anki and grammar patterns to the review queue.

`/english` never monitors passive conversation. With explicit opt-in, it stores only synthetic gap patterns in an existing language topic; raw user sentences are not copied.

## State and safety

```text
.ai/learning/
  summaries/                 # independent one-off summaries
  dashboard.md               # durable cross-topic state
  <topic>/
    mission.md
    path.md
    review-queue.md
    resources.md
    vocabulary.md
    gaps.md
    anki/
    notes/
    exercises/
    quizzes/
    teachbacks/
    dialogues/
```

`learning-recorder` remains the mechanical writer for durable state and can only read, edit, or write under `.ai/learning/**`. `learning-summarizer` is separately assignable. OpenCode gates its file tools through `permission.edit`, scoped only to `summaries/**`; the agent contract still permits one new file and forbids editing or overwriting existing files. It cannot browse elsewhere, ask, delegate, or access external files. Mentor may read learner repositories and ask permission to run tests for durable exercises, but never edits their code.

## Troubleshooting

- Summary is not saved: confirm the request was explicit and background Task mode is available; failures are intentionally one-shot.
- Due reviews accumulate: run `/learn review`; use `/learn status` for the queue.
- Cadence feels wrong: tell Mentor; the learner owns final cadence.
- `/english` questions do not surface: remove subtask mode or expose `english-tutor` as primary, then reinstall.
- Verification should stay manual: decline test execution.
