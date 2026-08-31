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

A bare topic such as `/learn pizza` is intentionally ambiguous. Mentor first asks `Sesión puntual` or `Ruta durable`; it does not inspect existing topics to infer the answer.

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

Automatic completion never interrupts or advances the conversation. The next normal response appends only the matching result:

```text
(Resumen guardado: <path>.)
(No se pudo guardar el resumen.)
```

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

General modules combine 10% formal input in Cornell route notes, 70% learner-owned exercises, and 20% Socratic debrief. Retrieval cues become Leitner cards with 1, 3, 7, 14, and 30-day intervals. A capstone teach-back closes the mission; reviews continue until cards are mastered.

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
