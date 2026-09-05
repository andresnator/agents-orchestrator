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

### General non-language module

Mentor teaches first and waits for later learner readiness before Practice. This staged flow applies only to non-language durable modules; language topics keep their two-wave flow.

| Phase | Expected result |
| --- | --- |
| Due-check | Offer overdue reviews; the learner decides whether to review first. |
| Class (10%) | Explain the objective, concepts, relationships, one non-solving example, and a recap. Save the note and lesson link, report module `🔄`, ask one localized readiness/clarification question in normal chat, and stop. |
| Practice (70%) | Only later learner readiness creates and links one coached exercise. Clarification updates the teaching and repeats the Class boundary. Record the actual result; never solve the exercise. |
| Consolidation | After `Result: done`, request a 2–3 sentence learner Summary. Confirm what is correct, explain gaps, and request revisions one question at a time. Once accepted, schedule every cue and record matching IDs in the note and exercise. |
| Debrief and Close (20%) | Capture the debrief and any required Feynman evidence; close only when all gates below pass. |

`Notes` contains Mentor's self-contained explanation, including a central-model row. `Summary` contains only the learner's words, lightly cleaned. A pause or unresolved summary gap keeps it pending and the module `🔄`.

### Checkpoint artifacts

Use the [Cornell template](../domains/learning/skills/cornell-notes/assets/cornell-template.md) for exact note markers and the [exercise template](../domains/learning/skills/learning-loop/assets/exercise-template.md) for pending outcomes. Set the note's `Teach-back` header to `required` for load-bearing concepts, otherwise `not-required`.

Each checkpoint uses one foreground `learning-recorder` handoff. Class persists only the note and lesson link; it never requests a Summary, creates Practice, schedules cards, or closes. Recorder receipts and notifications never count as learner readiness. Pending cues are neither scheduled cards nor quiz entries.

### Resume from persisted links

Follow the active `🔄` `path.md` row's lesson and exercise links. A `—` means create and link in one checkpoint; an absent linked target means recreate that exact path without changing the cell. Never infer targets from directory contents or repeat completed phases.

| Persisted state | Resume action |
| --- | --- |
| Lesson absent | Run Class. |
| Staged note exists; exercise cell `—` | Wait for later learner readiness, including after a restart; then create Practice. |
| Exercise absent or unfinished | Recreate if needed; resume Practice. |
| `Result: done`; Summary, recall IDs, or debrief pending | Finish Consolidation and debrief. |
| Teach-back required | Run Feynman and record its artifact path. Gaps keep `🔄` until return paths are resolved and a later gap-free teach-back replaces it. |

**Close requires** both linked artifacts, learner-authored Summary, `Result: done`, captured debrief, matching actual note/exercise card IDs, no blocking gaps, and Teach-back either `not-required` or referencing an existing artifact whose `## Verdict` is `gap-free`. See [learning-loop](../domains/learning/skills/learning-loop/SKILL.md#deterministic-module-resume) for the exact state rules. Recall uses Leitner intervals of 1, 3, 7, 14, and 30 days.

### Gaps and compatibility

| Case | Decision |
| --- | --- |
| Learner requests a fitting concept during Class or unfinished Practice | Teach it now; include it in the note, cues, exercise, and eventual Summary requirement, within one tangible win and 3–7 cues. |
| New concept after `Result: done` | Record separate reinforcement in `path.md`, whether addressed now or deferred. Keep current artifacts and Summary requirements unchanged. Reteaching existing concepts still belongs to Consolidation. |
| Mentor detects a gap or the request expands scope | Offer one recommended choice: address now or defer. Use separate reinforcement to preserve scope; deferred material stays out of current artifacts. A blocking gap keeps `🔄`. |
| Active legacy module with finalized note | Resume its original Practice/debrief/Feynman flow and copy note card IDs to the exercise before Close. Do not request another Summary or add staged fields. Never reopen completed legacy modules. |

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
