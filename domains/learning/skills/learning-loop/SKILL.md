---
name: learning-loop
description: "Trigger: durable /learn path, learning route, progress, review, several sessions, spaced repetition. Mission-grounded 70-20-10 learning loop: Mermaid roadmaps, Cornell micro-lessons, real-repo exercises, Socratic debriefs, and spaced-repetition hand-off."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "3.0.1"
---

# Learning Loop

## Activation Contract

Use after `mentor` has classified the raw request as durable learning: starting or continuing a multi-session path, reviewing, quizzing, mapping, drilling, teaching back, or checking progress. This is the durable methodology contract for the `mentor` agent and the `/learn` command.

Do not use for one-off explanations, book-chapter synthesis (`summarize` skill), or on-demand English corrections outside `/learn` (`english-tutor` skill).

## Routing Precondition

- Classify from the raw request before loading this skill or reading `.ai/learning/`; never use learning state to decide between a one-off session and a durable path.
- `/learn path <topic>` explicitly selects this skill. Strip `path` before routing the topic.
- Empty input and the existing `review`, `quiz`, `map`, `teach`, `vocab`, `drill`, and `status` modes are durable.
- A request for a route, progress, several sessions, review, repetition, or ongoing follow-up is durable.
- Resolve a bare or ambiguous topic through a closed choice whose two user-facing labels follow the conversation language. Map the one-off selection internally to `learning-session` and the durable selection to `learning-loop` before loading either skill. Do not list, grep, glob, or read `.ai/learning/` while that choice is open.

## Hard Rules

- Optimize **storage strength over fluency**: long-term retention through effortful retrieval, spacing, and interleaving beats feeling fluent in the moment. Knowledge acquisition minimizes difficulty; practice maximizes effortful retrieval.
- Durable topic state lives under `.ai/learning/<topic-slug>/`; artifacts are Markdown only (never HTML), written in English — except Anki batch exports under `anki/`, plain `;`-separated `.txt` per `anki-vocab`. `.ai/learning/summaries/` is reserved standalone-summary infrastructure, never a durable topic. The conversation follows the user's language.
- The exact `summaries` topic slug is reserved. Exclude that directory from topic discovery and never create or resume a topic with that slug. If a requested topic normalizes to `summaries`, propose a distinct slug such as `summaries-topic` for learner confirmation while preserving the topic title.
- **State discovery reads the directory, never a pattern search**: `.ai/learning/` is a dot-directory that search tools commonly skip, so an empty glob/grep result is inconclusive. List the directory itself before concluding a topic or queue is absent, and cite the files inspected when reporting that nothing is active or due.
- Ask open-ended interviews, retrieval prompts, Socratic debriefs, and teach-backs directly in normal chat, one question at a time, then stop and wait. Add `Recommendation: ...` only when useful; do not add question headings, numbering, rationale blocks, or interview-length estimates.
- Use the `question` tool only for closed choices such as topic selection, review confirmation, grades, or modes.
- Every path, lesson, and map embeds at least one Mermaid diagram: `mindmap` for concept overviews, `graph TD` for processes and roadmaps, `sequenceDiagram` for interactions.
- Lesson capture follows `cornell-notes`; retention scheduling follows `spaced-recall` (including its interleaving and leech rules); vocabulary export follows `anki-vocab`. Run the `spaced-recall` due-check first in **every** mode.
- 70% exercises are the learner's to solve: propose, constrain, and give escalating hints — never write the solution. Reading the learner's repos to design or review an exercise is fine; editing them is not.
- **Understand the repo graph-first**: when designing or reviewing an exercise, resolve the learner's repo structure from a code-graph index (for example, Graphify MCP/CLI) when available, before file-by-file crawling; the graph is query-only, and every claim still cites the underlying `file:line`.
- **Interleave retrieval**: reviews and quizzes mix cues across notes and modules rather than replaying one block — the mechanics live in `spaced-recall`.
- Quizzes are a low-stakes pacing instrument: they read only the finalized cue bank and never move Leitner boxes. Exclude every route note whose `Recall hand-off` is still `pending until consolidation`; only scheduled `spaced-recall` reviews and `feynman-teachback` gap demotions change the queue.
- Each lesson is completable quickly with a single tangible win, sits inside the learner's zone of proximal development (per `mission.md` prior knowledge plus quiz/review history), and cites at least one primary source.
- Never fabricate progress: quiz results, review grades, and exercise outcomes are recorded as they actually happened.
- **Language topics route to `language-loop`**: when `mission.md` names a target language, this skill stays the outer contract (mission, path, due-check, ZPD, output contract) but the Module Session Flow below is replaced by the `language-loop` two-wave session flow, and `bidirectional-translation` governs `drill` mode.

## Modes

Route the raw `/learn` arguments:

| Arguments | Mode | Behavior |
| --- | --- | --- |
| empty | continue | Due-check, then resume the active topic's next module; if several topics are active, ask which one. |
| `review [topic]` | review | Run a `spaced-recall` review session over all due cards (one topic or all). |
| `quiz [topic]` | quiz | Retrieval quiz from finalized Cornell notes, excluding every note whose `Recall hand-off` is pending; interleave cues across modules and record results in `quizzes/`, but never move boxes. |
| `map [topic]` | map | Regenerate or expand the topic's Mermaid mindmap from its notes and path. |
| `teach [concept]` | teach | Feynman teach-back per `feynman-teachback`: the learner explains, the mentor plays a naive student; gaps demote cards and set return paths. |
| `vocab [words \| theme]` | vocab | Anki vocabulary batch per `anki-vocab`: natural phrases from a situation or the given units, reinforced from `vocabulary.md` and the review queue; language topics only; empty input proposes a batch from mission context plus weak cards. |
| `drill [unit]` | drill | Standalone bidirectional-translation session per `bidirectional-translation` on the named dialogue unit (weakest-first when empty); language topics only. |
| `status` | status | Rebuild `.ai/learning/dashboard.md`: per-topic progress, due/upcoming reviews, mastered counts. |
| `path <topic>` | topic | Explicitly start or resume the durable topic after stripping the `path` selector. |
| anything else | topic | Treat as a topic: resume only if `<topic-slug>/mission.md` exists and the slug is not `summaries`; otherwise start a new path with a non-reserved slug. |

## New Topic Flow

1. **Mission grounding (propose-first)** — infer everything the topic and visible context already answer; interview only the essentials per `grilling` (why / observable goal; for a language topic also the learner's native language). Estimate the total effort the observable goal requires (e.g. ~20 h) and recommend a cadence (e.g. 3×30 min/week ≈ 3 months) — never ask for a time budget as a bare question; present the recommendation, let the learner adjust freely in chat, and the learner owns the final cadence. Then draft the full `mission.md` from `assets/mission-template.md` — inferred success criteria, prior-knowledge assumptions, and the effort estimate plus recommended and agreed cadence — and present it for correction. Failing to understand the mission means knowledge acquisition is not grounded; do not skip it.
2. **Path** — draft 4–8 modules, each with a single tangible win, ordered by dependency and sized against the mission's agreed cadence (the path draft states the estimated session count) → `path.md` from `assets/path-template.md`, with a `graph TD` roadmap using ✅/🔄/⬜ status markers and the `## Completion` capstone gate created ⬜. Confirm the path with the learner before starting module 1.
3. **Resources** — seed `resources.md` from `assets/resources-template.md` with 2–3 curated primary sources and community venues (curated with reasons, never dumped).

## Module Session Flow (Class → Practice → Consolidation)

This flow applies only to durable non-language modules. When `mission.md` names a target language, `language-loop` replaces it completely.

1. **Due-check** (`spaced-recall`) — offer overdue reviews before new material.
2. **Class (10% formal)** — explain the objective, essential concepts and relationships, one example that does not solve the exercise, and a recap of the central model before asking for retrieval or practice.
3. **Class checkpoint** — use the staged `cornell-notes` profile and its [template](../cornell-notes/assets/cornell-template.md). In one foreground `learning-recorder` handoff, persist the note and its backticked relative link in the active `path.md` row's `10% lesson` cell; follow the resume rules below for existing links. After persistence settles, show a compact recap, report the note path and module 🔄, ask exactly one localized readiness-or-clarification question in normal chat, and stop. Do not request a Summary, create Practice, schedule cards, or close. Recorder receipts and automatic notifications are not learner input.
4. **Practice (70% doing)** — enter only after a later learner message signals readiness. For clarification, explain, update the staged teaching when needed, repeat the Class question, and stop again. On readiness, create `exercises/NNNN-<name>.md` from `assets/exercise-template.md`: a real-repo exercise, or a self-contained kata when no repo fits. Persist it and its `70% exercise` link in one foreground handoff. The learner executes; Mentor gives escalating hints without solving it. Record the actual attempt and `Result`: `pending`, `partial`, or `stuck at ...` until the tangible win is `done`.
5. **Consolidation** — after `Result: done`, ask for a 2–3 sentence learner summary. Confirm what is correct first; explain each material gap and request a revision, one question at a time. A pause or unresolved gap leaves the Summary pending and the module 🔄.
6. **Finalize the note** — accept only a summary that demonstrates the practiced concepts. Save the learner's words, lightly cleaned without adding concepts or wording. Schedule every cue through `spaced-recall`; in one foreground checkpoint, replace the note's `Recall hand-off` and exercise's `Cues sent to review queue` with the same actual card IDs.
7. **Debrief and Close (20% social)** — ask what was learned, what surprised the learner, and where it applies, one question at a time; persist the actual debrief. Complete any required `feynman-teachback` under the resume rules below. Only after all Close gates pass, mark the module and roadmap ✅, update the path log, and report the next module and due review date.

## Scoped Concept Gaps (Non-Language Modules Only)

Apply only to staged non-language modules:

- Add concepts to the current module only during Class or unfinished Practice. After `Result: done`, record new concepts as separate reinforcement in `path.md`, whether addressed now or deferred; keep the current note, Summary requirement, cues, and exercise unchanged. Gaps in already-taught concepts still use Consolidation.
- During Class or unfinished Practice, explain a learner-requested supporting concept immediately if it fits the tangible win and 3–7 cues. Include it in `Map`, `Notes`, cues, the exercise when created or updated, and the learner's eventual Summary requirement; never write their Summary for them.
- For Mentor-detected gaps or scope expansion, offer one localized closed `question`: address now or defer. Recommend now for a blocking gap, otherwise defer. Preserve the single win and cue limit by using separate reinforcement when needed.
- Log deferred reinforcement in `path.md`; exclude it from the current artifacts. Any unresolved blocking gap keeps the module 🔄.

## Deterministic Module Resume

For staged non-language modules, follow the active 🔄 `path.md` row's `10% lesson` and `70% exercise` links exactly; never infer targets from directory contents. A `—` means create and link in one checkpoint. A link with an absent target means recreate that exact path without changing the cell. Use the first matching row below; preserve recorded outcomes and do not repeat completed phases.

| Persisted state | Resume action |
| --- | --- |
| Lesson absent | Class, including its checkpoint and turn boundary. |
| Staged note exists; exercise cell `—` | Wait for later learner readiness, then create Practice. A new session alone is not readiness. |
| Exercise absent or `Result` is `pending`, `partial`, or `stuck at ...` | Create/recreate if absent; resume Practice. |
| `Result: done`; Summary pending | Consolidation: request the summary or continue its feedback loop. |
| Learner Summary exists; recall hand-off, exercise cue IDs, or debrief pending | Finish Consolidation and debrief; do not close. |
| Summary, recall IDs, practice, and debrief final; `> Teach-back: required` | Run Feynman. Once its artifact exists, replace the header with `> Teach-back: teachbacks/NNNN-<concept>.md`. |
| Referenced teach-back Verdict has gaps | Keep 🔄, resolve its return paths, run another teach-back, and replace the header path. |
| All Close gates pass | Close the module. |

**Close gates:** both artifacts are linked; Summary is learner-authored; the note and exercise contain the same actual card IDs; `Result: done`; debrief is captured; no blocking gap remains; Teach-back is `not-required` or references an existing `teachbacks/...` artifact whose `## Verdict` is `gap-free`.

### Legacy Active-Module Resume

An active 🔄 row with a real learner Summary and actual recall IDs but no staged markers or Teach-back header keeps its original contract:

- Resume absent or unfinished Practice using the same create/link rules above. After `Result: done`, finish the original 20% debrief and conditional load-bearing Feynman flow.
- Before Close, copy the note's actual card IDs to the exercise's `Cues sent to review queue`.
- Do not request another Summary, add staged fields, migrate finalized notes, or reopen an already ✅ legacy module.

## Topic Completion

The capstone is an explicit state gate, not a prose reminder: `path.md`'s `## Completion` table (from `assets/path-template.md`) carries it as a ⬜ row from the day the path is created. When every module in `path.md` is ✅, close the topic rather than leaving it open-ended:

1. **Capstone teach-back** — one `feynman-teachback` session against the `mission.md` observable goal, checking off each success criterion the learner can now demonstrate; unmet criteria stay open and reopen the nearest module (which also resets the gate to ⬜).
2. **Flip the gate, then mark it done** — record the teach-back file path and date as the gate's Evidence, set the gate ✅, and only then set `Status: completed` in `mission.md`; `/learn status` lists it under Completed. `mission.md` never reads completed while the gate is ⬜.
3. **Reviews outlive completion** — the `review-queue.md` keeps surfacing due cards until every card is Mastered; completion closes the path, not the retention loop.

A fresh session resumes from files alone: all modules ✅ with the gate ⬜ means the capstone is due — offer it before any new material.

## Zone of Proximal Development

Before each module, read the latest quiz results and review grades: mostly failed recalls or a stuck exercise → insert a reinforcement step or split the module; effortless success → compress or skip ahead. Record the pacing decision in the `path.md` log.

## Output Contract

End every session by reporting: mode run, artifacts written (paths), cards reviewed/added, current module status, and the next due review date. Report review/quiz performance plainly.

## Attribution

Adapted from Matt Pocock's `teach` skill at <https://github.com/mattpocock/skills> (mission grounding, single-win lessons, storage strength, learning records); reworked for Markdown artifacts, Mermaid visuals, Cornell capture, Leitner spaced repetition, and the 70-20-10 model.
