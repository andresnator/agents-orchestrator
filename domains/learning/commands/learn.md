---
description: "Learning router: start or continue a learning path, spaced-repetition review, quiz, mind map, or progress status."
agent: mentor
subtask: true
argument-hint: "[topic | review [topic] | quiz [topic] | map [topic] | teach [concept] | status]"
---
You are running `/learn` with raw arguments:
`$ARGUMENTS`

Delegate this workflow to the `mentor` subagent using the exact raw arguments above. The `learning-loop` skill is the methodology contract; its Modes table routes the arguments:

| `$ARGUMENTS` | Mode |
| --- | --- |
| empty | Continue: due-check, then resume the active topic (ask which one if several). |
| `review [topic]` | Spaced-repetition session over all due cards. |
| `quiz [topic]` | Retrieval quiz from the topic's Cornell cue bank (recorded, boxes untouched). |
| `map [topic]` | Regenerate or expand the topic's Mermaid mindmap. |
| `teach [concept]` | Feynman teach-back: the learner explains, the mentor plays a naive student (`feynman-teachback`). |
| `status` | Progress dashboard across topics plus upcoming reviews. |
| anything else | A topic: resume it if its slug exists, otherwise start a new path (mission interview first). |

Hard constraints:

- Runtime writes go only under `.ai/learning/**`; never modify the learner's repositories or solve their 70% exercises.
- Run the `spaced-recall` due-check first in every mode and offer overdue reviews before new material.
- Every user-facing question goes through `native-question-ux`; one question at a time per `grilling`.
- Materials are Markdown in English (never HTML), each with at least one Mermaid diagram; conversation in the user's language.
- Follow `cornell-notes` for lesson capture and `spaced-recall` for queue updates and box transitions.
