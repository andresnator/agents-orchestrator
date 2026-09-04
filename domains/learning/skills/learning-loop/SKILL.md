---
name: learning-loop
description: "Trigger: durable /learn path, learning route, progress, review, several sessions, spaced repetition. Mission-grounded 70-20-10 learning loop: Mermaid roadmaps, Cornell micro-lessons, real-repo exercises, Socratic debriefs, and spaced-repetition hand-off."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: testing
  version: "3.0.0"
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
2. **Class (10% formal)** — teach before asking the learner to retrieve or build. Give a visible, self-contained explanation with the module objective, the essential concepts, how they relate, one concrete example that does not solve the upcoming exercise, and a short mentor-authored recap of the central model.
3. **Class checkpoint and turn boundary** — capture the teaching through `cornell-notes`. Decide whether its concept is load-bearing and persist the staged note with the exact header `> Teach-back: required` or `> Teach-back: not-required`, the Mermaid `Map`, 3–7 cue questions, and self-contained `Notes`; at least one Notes row must synthesize the section's central model. Leave the exact staged `Summary` and `Recall hand-off` markers from `assets/cornell-template.md`. In one foreground `learning-recorder` handoff, create the note and replace the active `path.md` row's `10% lesson` `—` with its backticked relative path. After persistence settles, show a compact recap, report the staged note path and module 🔄 checkpoint, ask exactly one localized readiness-or-clarification question directly in normal chat, and stop. Do not ask for the learner's Summary, schedule cards, create the exercise, or mark the module ✅ in this turn. A recorder receipt or automatic notification is not learner input.
4. **Practice (70% doing)** — only a later learner response may enter this phase. If it requests clarification, answer it, update the staged teaching when needed, repeat the Class turn boundary, and stop again. Once the learner indicates readiness, create the real-repo exercise, or a self-contained kata when no repo fits, at `exercises/NNNN-<name>.md` from `assets/exercise-template.md`. In one foreground handoff, create it with `Attempted: pending` and `Result: pending` and replace the active path row's `70% exercise` `—` with its backticked relative path. The learner executes while the mentor coaches with escalating hints and never supplies the solution. Record the real attempt and keep `Result` as `partial` or `stuck at ...` until the single tangible win is actually `done`.
5. **Consolidation** — only after meaningful practice reaches `Result: done`, ask the learner for a 2–3 sentence summary in their own words. Say what is correct first, then identify what is missing or incorrect. For a material gap, give one targeted explanation and ask for a revised summary, one question at a time. If the learner pauses or still cannot demonstrate the concept, preserve the pending Summary marker and keep the module 🔄.
6. **Finalize the note** — once the summary demonstrates the module concepts, replace the pending Summary with the learner's words, lightly cleaned without adding concepts or wording they did not express. Schedule every cue through `spaced-recall`; in the same foreground checkpoint, replace the note's pending `Recall hand-off` and the exercise's pending `Cues sent to review queue` with the same actual card IDs.
7. **20% social and close** — run the Socratic debrief (what did you learn, what surprised you, where would you use it) and replace the exercise's pending debrief with the actual outcome. If the note says `> Teach-back: required`, run `feynman-teachback` and replace that exact line with `> Teach-back: teachbacks/NNNN-<concept>.md` only after its artifact exists; `not-required` needs no teach-back. A referenced teach-back whose Verdict reports gaps keeps the module 🔄 until its return paths are resolved and a later gap-free teach-back path replaces the header. Mark the module ✅ and update its roadmap/log only when the staged Close predicate below is satisfied; then state the next module and due review date.

## Scoped Concept Gaps (Non-Language Modules Only)

These rules apply only inside the staged non-language module flow above; never impose them on `language-loop`, another route-note flow, a legacy note, or a standalone summary.

- When the learner asks about an auxiliary concept that still serves the same tangible win and keeps the note within 3–7 cues, explain it now. Incorporate it into the note's `Map`, `Notes`, cue set, and exercise, and later ask the learner to connect it in their Summary. Never supply that Summary wording for them.
- When the mentor identifies the gap, or the requested concept would expand the module, use one localized closed `question` with two choices: address it now or defer it as reinforcement. Recommend addressing it now when it blocks the tangible win; otherwise recommend deferring it.
- If addressed now, preserve the single-win and 3–7-cue limits by splitting out a targeted reinforcement step when necessary. If deferred, add it to the `path.md` log as reinforcement and exclude it from the current note, Summary, cues, and exercise. A deferred blocking gap leaves the module 🔄 until it is resolved.

## Deterministic Module Resume

This state machine applies only to staged non-language modules created by the flow above. Start from the active 🔄 row in `path.md`; its `10% lesson` and `70% exercise` cells are the artifact index. Follow each recorded relative path exactly and never infer a resume target from directory contents.

1. `10% lesson` is `—` → resume **Class**. Choose the next note path, then create the note and replace that exact `—` with its relative link in one checkpoint.
2. `10% lesson` already contains a link but its target is absent → resume **Class** and recreate that exact linked target. Preserve the existing path cell; do not try to replace a `—` that is no longer there.
3. The linked note has the exact pending Summary marker and `70% exercise` is `—` → after the Class turn boundary and a later learner response indicating readiness, resume **Practice** by creating the exercise and replacing that exact `—` with its link in the same checkpoint.
4. `70% exercise` already contains a link but its target is absent → recreate that exact linked target before Practice. Preserve the existing path cell; `Result: pending`, `Result: partial`, or `Result: stuck at ...` resumes **Practice**.
5. `Result: done` plus the exact pending Summary marker resumes **Consolidation** at the learner-summary request or its unresolved feedback loop.
6. A real learner Summary plus a pending note `Recall hand-off`, pending exercise debrief, or pending exercise `Cues sent to review queue` resumes **Consolidation**; never close from this partial state.
7. Once Summary, recall IDs, `Result: done`, debrief, and exercise cue IDs are final, `> Teach-back: required` resumes the required **Feynman teach-back**. A recorded `teachbacks/...` path must be followed: a Verdict with gaps resumes its return paths and another teach-back, while `> Teach-back: not-required` skips this step.
8. **Close** only when the active row links both artifacts, the Summary is learner-authored, the note and exercise contain the same actual card IDs, `Result: done`, the debrief is captured, and Teach-back is either `not-required` or a recorded `teachbacks/...` path whose Verdict is `gap-free`.

Existing route notes with a learner Summary and actual recall card IDs but no staged markers or Teach-back header remain finalized under their original contract; do not migrate them or reopen already ✅ legacy modules. At every resume point, preserve recorded outcomes and do not repeat a completed phase.

### Legacy Active-Module Resume

When an active 🔄 row links a finalized legacy note (real learner Summary and actual recall card IDs, with no staged markers or Teach-back header), resume its original module contract:

- Exercise cell `—` → resume **Practice**, create the exercise, and replace only that `—` with its relative link. Existing exercise link with an absent target → recreate that exact target without editing the path cell.
- Exercise `Result: pending`, `partial`, or `stuck at ...` → resume **Practice**. `Result: done` → finish the original 20% debrief and optional load-bearing Feynman flow.
- Before Close, record the legacy note's actual card IDs in the exercise's `Cues sent to review queue`. Do not request another Summary, add staged markers, or require a Teach-back header. Do not reopen an already ✅ legacy module.

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
