---
description: "Learning router: start or continue a learning path, spaced-repetition review, quiz, mind map, or progress status."
agent: mentor
argument-hint: "[topic | review [topic] | quiz [topic] | map [topic] | teach [concept] | vocab [words|theme] | drill [unit] | audio [unit] | status]"
---
You are running `/learn` with raw arguments:
`$ARGUMENTS`

Run this workflow as the `mentor` agent with the exact raw arguments above. The `learning-loop` skill is the methodology contract; its Modes table routes the arguments:

| `$ARGUMENTS` | Mode |
| --- | --- |
| empty | Continue: due-check, then resume the active topic (ask which one if several). |
| `review [topic]` | Spaced-repetition session over all due cards. |
| `quiz [topic]` | Retrieval quiz from the topic's Cornell cue bank (recorded, boxes untouched). |
| `map [topic]` | Regenerate or expand the topic's Mermaid mindmap. |
| `teach [concept]` | Feynman teach-back: the learner explains, the mentor plays a naive student (`feynman-teachback`). |
| `vocab [words \| theme]` | Anki vocabulary batch for a language topic: `;`-separated txt under `anki/`, units registered in `vocabulary.md` (`anki-vocab`). |
| `drill [unit]` | Bidirectional-translation drill on a dialogue unit, weakest-first when empty (`bidirectional-translation`); language topics only. |
| `audio [unit]` | Dialogue-unit audio per `lesson-audio`: normal + slow target-language renditions under `audio/`, engine-laddered with graceful skip; `pending` units backfilled oldest-first when empty; language topics only. |
| `status` | Progress dashboard across topics plus upcoming reviews. |
| anything else | A topic: resume it if its slug exists, otherwise start a new path (mission interview first). |

Hard constraints:

- Runtime writes go only under `.ai/learning/**`; never modify the learner's repositories or solve their 70% exercises.
- Run the `spaced-recall` due-check first in every mode and offer overdue reviews before new material.
- Today's date comes from the environment (the allow-listed `date` command or runtime context), never a guess.
- Bash is ask-gated and narrow: reading the date, running the learner's tests/build to check a 70% exercise outcome, or `lesson-audio` TTS synthesis writing only under `.ai/learning/<topic-slug>/audio/` — never any other mutating command, and a missing TTS engine skips audio (install hint), never fails the session.
- Understand the learner's repo graph-first (CodeGraph MCP/CLI when available, query-only) before file-by-file crawling when designing or reviewing exercises.
- Every user-facing question goes through `native-question-ux`; one question at a time per `grilling`.
- Materials are Markdown in English (never HTML), each with at least one Mermaid diagram — except Anki batch exports under `anki/`, plain `;`-separated `.txt` per `anki-vocab`; conversation in the user's language.
- Follow `cornell-notes` for lesson capture and `spaced-recall` for queue updates and box transitions.
- Vocab batches follow `anki-vocab`; exported units get no Leitner cards — Anki is their review system.
- Language topics (mission names a target language) follow `language-loop` for the session flow: two waves per session, and a scan of the topic's `gaps.md` inbox during the due-check — pending rows are offered for adoption (card or drill) and flipped to `adopted`.
