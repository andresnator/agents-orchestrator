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

General modules combine 10% formal input in Cornell route notes, 70% learner-owned exercises, and 20% Socratic debrief. The lifecycle, staged checkpoint, resume, and scoped-gap rules below apply only to durable general non-language modules. Language topics retain their separate two-wave flow, and standalone summaries never use this state.

### General module lifecycle

1. **Due-check** — offer overdue reviews before new material.
2. **Class** — teach the objective, essential concepts, their relationships, one example, and a brief recap. Persist the Mermaid `Map` and Mentor-authored `Notes`; one Notes row synthesizes the section's central model. Report the checkpoint, ask one readiness or clarification question, and stop.
3. **Practice** — only after later learner input signals readiness, assign one tangible learner-owned exercise. Mentor constrains, coaches, and reveals escalating hints without solving it.
4. **Consolidation** — after meaningful practice, ask for a 2–3 sentence summary in the learner's own words. Confirm what is correct first, explain each missing or incorrect concept, and ask for a revision one question at a time. After accepting the Summary, schedule the cues and record matching card IDs in the note and exercise.
5. **Close** — finalize the learner Summary, recall hand-off, exercise result, debrief, and exercise cue hand-off. `> Teach-back: required` mandates a Feynman teach-back whose `## Verdict` is `gap-free`; `not-required` skips it.

`Notes` and `Summary` have different owners: Notes are Mentor's self-contained explanation of the concepts; Summary is only the learner's wording, lightly cleaned up. Mentor never fabricates or completes it. A pause or unresolved concept leaves the note pending and the module `🔄`.

### Staged checkpoint and resume

Immediately after `Class`, `learning-recorder` creates the route note in normal Cornell order. Its header records exactly one conditional state:

- `> Teach-back: required` for a load-bearing concept.
- `> Teach-back: not-required` otherwise.

The body uses these exact placeholders:

```markdown
## Summary

_Pending learner summary after practice._

## Recall hand-off

Cues added to `review-queue.md`: pending until consolidation.
```

The pending markers are resumable state only: they are not learner-authored content, do not schedule cards, do not enter the quiz bank, and do not authorize module completion. When a required Feynman teach-back creates an artifact, its header state becomes `> Teach-back: teachbacks/NNNN-<concept>.md`; Close follows that file and requires a `gap-free` verdict.

At the Class checkpoint, Mentor replaces `—` in the active `🔄` row's `10% lesson` cell with the persisted note link. It then shows a brief recap, reports the staged checkpoint and module `🔄`, asks exactly one normal-chat readiness or clarification question, and stops. It never creates Practice in that response. Only later learner input can start Practice; a recorder receipt or automatic notification does not count. If the learner asks for clarification, Mentor answers it, updates the staged teaching when needed, repeats this one-question boundary, and stops again.

When later input starts Practice, Mentor stores its link in that row's `70% exercise` cell and initializes `Attempted: pending`, `Result: pending`, `Debrief (20%): pending until consolidation`, and `Cues sent to review queue: pending until consolidation`.

A fresh session starts from the active `🔄` row and follows those persisted links; it never discovers or infers a lesson or exercise from directory contents.

| Active row and linked state | Resume phase |
| --- | --- |
| `10% lesson` is `—` | `Class`; create the note and replace `—` with its link |
| Lesson link exists but its target is absent | `Class`; recreate that exact target without changing the cell |
| Lesson linked; `70% exercise` is `—` | After later learner readiness, enter `Practice` and persist the exercise link |
| Exercise link exists but its target is absent | Recreate that exact target without changing the cell, then `Practice` |
| Both linked; Summary pending and `Result` is `pending`, `partial`, or `stuck at ...` | `Practice` |
| Both linked; `Result: done` and Summary pending | `Consolidation` |
| Summary filled but recall hand-off, debrief, or `Cues sent to review queue` is pending | Finish `Consolidation` |
| Both linked; Summary and actual recall IDs, `Result: done`, real debrief, matching exercise cue IDs; Teach-back is `required` | Run Feynman and replace `required` with its evidence path |
| Teach-back evidence reports gaps | Keep the module `🔄`, resolve its return paths, then run a later teach-back and replace the header path |
| Both linked and all fields complete; Teach-back is `not-required` or its evidence verdict is `gap-free` | `Close` |

Existing finalized route notes remain valid and need no staged-marker migration. When an active `🔄` legacy row links such a note but its exercise is absent, `pending`, `partial`, or `stuck at ...`, resume `Practice` through the row without requesting another Summary or adding staged markers or a Teach-back header. Create and link an exercise only for `—`; recreate an absent linked target without changing its cell. Before legacy Close, copy the note's actual card IDs into the exercise cue hand-off; a completed exercise finishes its original debrief and conditional Feynman flow. Never reopen an already ✅ legacy module. Resume preserves recorded outcomes and never repeats a completed phase.

### Scoped concept gaps

For these general non-language modules, if the learner requests a supporting concept that still fits the same tangible win and the Cornell limit of 3–7 cues, Mentor teaches it now and incorporates it into `Map`, `Notes`, cues, and practice. The final learner summary must connect that concept too.

When Mentor detects the gap, or the requested concept would expand the module, Mentor offers a localized closed choice with a recommendation: address it now or defer it as reinforcement. Addressing it now uses a targeted reinforcement step when necessary to preserve the single-win and 3–7-cue limits. Deferred material is recorded in `path.md` and excluded from the current note, summary, cues, and exercise. A gap that blocks the exercise keeps the module `🔄` until resolved.

During Consolidation, an accepted learner Summary turns the retrieval cues into Leitner cards with 1, 3, 7, 14, and 30-day intervals. Close still waits for the exercise debrief and any required gap-free Feynman evidence. A capstone teach-back closes the mission; reviews continue until cards are mastered.

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
