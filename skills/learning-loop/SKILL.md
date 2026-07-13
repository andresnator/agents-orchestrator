---
name: learning-loop
description: "Trigger: /learn, learn topic, learning path, teach me, ensename, aprender, ruta de aprendizaje. Mission-grounded 70-20-10 learning loop: Mermaid roadmaps, Cornell micro-lessons, real-repo exercises, Socratic debriefs, and spaced-repetition hand-off."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: andresnator
  source: https://github.com/mattpocock/skills
  status: in-progress
  version: "1.2.1"
---

# Learning Loop

## Activation Contract

Use when the user wants to learn a topic or skill over multiple sessions: starting a learning path, continuing one, quizzing, mapping, or checking progress. This is the methodology contract for the `mentor` agent and the `/learn` command.

Do not use for one-off explanations, book-chapter synthesis (`summarize` skill), or English coaching (`english-tutor` skill).

## Hard Rules

- Optimize **storage strength over fluency**: long-term retention through effortful retrieval, spacing, and interleaving beats feeling fluent in the moment. Knowledge acquisition minimizes difficulty; practice maximizes effortful retrieval.
- All state lives under `.ai/learning/<topic-slug>/`; artifacts are Markdown only (never HTML), written in English — except Anki batch exports under `anki/`, plain `;`-separated `.txt` per `anki-vocab`. The conversation follows the user's language.
- Every user-facing question goes through `native-question-ux`; interviews follow `grilling`: one question at a time, recommendation attached, stop and wait.
- Every path, lesson, and map embeds at least one Mermaid diagram: `mindmap` for concept overviews, `graph TD` for processes and roadmaps, `sequenceDiagram` for interactions.
- Lesson capture follows `cornell-notes`; retention scheduling follows `spaced-recall`; vocabulary export follows `anki-vocab`. Run the `spaced-recall` due-check first in **every** mode.
- 70% exercises are the learner's to solve: propose, constrain, and give escalating hints — never write the solution. Reading the learner's repos to design or review an exercise is fine; editing them is not.
- Each lesson is completable quickly with a single tangible win, sits inside the learner's zone of proximal development (per `mission.md` prior knowledge plus quiz/review history), and cites at least one primary source.
- Never fabricate progress: quiz results, review grades, and exercise outcomes are recorded as they actually happened.

## Modes

Route the raw `/learn` arguments:

| Arguments | Mode | Behavior |
| --- | --- | --- |
| empty | continue | Due-check, then resume the active topic's next module; if several topics are active, ask which one. |
| `review [topic]` | review | Run a `spaced-recall` review session over all due cards (one topic or all). |
| `quiz [topic]` | quiz | Retrieval quiz from the topic's Cornell cue bank; record results in `quizzes/`; results inform pacing but do not move boxes. |
| `map [topic]` | map | Regenerate or expand the topic's Mermaid mindmap from its notes and path. |
| `teach [concept]` | teach | Feynman teach-back per `feynman-teachback`: the learner explains, the mentor plays a naive student; gaps demote cards and set return paths. |
| `vocab [words \| theme]` | vocab | Anki vocabulary batch per `anki-vocab`: natural phrases from a situation or the given units, reinforced from `vocabulary.md` and the review queue; language topics only; empty input proposes a batch from mission context plus weak cards. |
| `status` | status | Rebuild `.ai/learning/dashboard.md`: per-topic progress, due/upcoming reviews, mastered counts. |
| anything else | topic | Treat as a topic: resume if `<topic-slug>` exists, otherwise start a new path. |

## New Topic Flow

1. **Mission grounding** — short interview (why, observable goal, success criteria, time budget, prior knowledge) → `mission.md` from `assets/mission-template.md`. Failing to understand the mission means knowledge acquisition is not grounded; do not skip it.
2. **Path** — draft 4–8 modules, each with a single tangible win, ordered by dependency → `path.md` from `assets/path-template.md`, with a `graph TD` roadmap using ✅/🔄/⬜ status markers. Confirm the path with the learner before starting module 1.
3. **Resources** — seed `resources.md` from `assets/resources-template.md` with 2–3 curated primary sources and community venues (curated with reasons, never dumped).

## Module Session Flow (70-20-10)

1. **Due-check** (`spaced-recall`): offer overdue reviews before new material.
2. **10% formal** — micro-lesson captured as a Cornell note (`cornell-notes`, `assets/cornell-template.md` in that skill): Mermaid map, cue questions, notes, learner-voiced summary, primary source.
3. **70% doing** — real exercise in the learner's repo (or a self-contained kata when no repo fits) → `exercises/NNNN-<name>.md` from `assets/exercise-template.md`: brief, constraints, escalating hints, outcome log. The learner executes; the mentor coaches.
4. **20% social** — Socratic debrief (what did you learn, what surprised you, where would you use it) recorded in the exercise's outcome log, plus any new community resources into `resources.md`. When the module's concept is load-bearing, close the debrief with a Feynman teach-back (`feynman-teachback`).
5. **Close** — new cues go to `review-queue.md` via `spaced-recall`; update `path.md` status, roadmap markers, and log; state the next module and the next due review date.

## Zone of Proximal Development

Before each module, read the latest quiz results and review grades: mostly failed recalls or a stuck exercise → insert a reinforcement step or split the module; effortless success → compress or skip ahead. Record the pacing decision in the `path.md` log.

## Output Contract

End every session by reporting: mode run, artifacts written (paths), cards reviewed/added, current module status, and the next due review date. Report review/quiz performance plainly.

## Attribution

Adapted from Matt Pocock's `teach` skill at <https://github.com/mattpocock/skills> (mission grounding, single-win lessons, storage strength, learning records); reworked for Markdown artifacts, Mermaid visuals, Cornell capture, Leitner spaced repetition, and the 70-20-10 model.
