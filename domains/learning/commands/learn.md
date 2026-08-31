---
description: "Learning router: choose a one-off session or a durable path, then teach, review, quiz, map, or report progress."
agent: mentor
argument-hint: "[session <request> | path <topic> | review [topic] | quiz [topic] | map [topic] | teach [concept] | vocab [words|theme] | drill [unit] | status]"
---
You are running `/learn` with raw arguments:
`$ARGUMENTS`

Run this workflow as the `mentor` agent with the exact raw arguments above. Classify the raw request before loading any skill, calling any tool, or reading `.ai/learning/`. Load exactly one initial methodology skill: `learning-session` for one-off learning or `learning-loop` for durable learning.

| `$ARGUMENTS` | Initial route |
| --- | --- |
| `session <request>` | One-off session; remove the selector and teach `<request>` now. |
| `path <topic>` | Durable path; remove the selector and route `<topic>` through `learning-loop`. |
| empty | Durable continue mode. |
| `review [topic]`, `quiz [topic]`, `map [topic]`, `teach [concept]`, `vocab [words \| theme]`, `drill [unit]`, `status` | Durable existing mode; preserve its current `learning-loop` behavior. |
| A request clearly answerable in this interaction, with no requested follow-up | One-off session. |
| A request for a route, progress, several sessions, review, repetition, or ongoing follow-up | Durable learning. |
| A bare or otherwise ambiguous topic, such as `pizza` | Before any skill or state access, ask one closed choice: `Sesión puntual` or `Ruta durable`; then load only the selected methodology skill. |

Hard constraints:

- One-off sessions never run a due-check, inspect `.ai/learning/`, or create a mission, path, note, card, queue, dashboard, or other durable state. Teach first in the user's language with progressive disclosure. Only an explicit positive request to save launches the isolated background summary flow.
- Durable routes retain the `learning-loop` Modes table and all existing behavior for `review`, `quiz`, `map`, `teach`, `vocab`, `drill`, and `status`.
- `summaries` is a reserved infrastructure slug, never a durable topic. A topic with that title uses a distinct confirmed slug such as `summaries-topic`.
- Runtime writes go only under `.ai/learning/**`; never modify the learner's repositories or solve their 70% exercises.
- Run the `spaced-recall` due-check first in every durable mode and offer overdue reviews before new material.
- Today's date comes from the environment (the allow-listed `date` command or runtime context), never a guess.
- Bash is ask-gated and narrow: reading the date or running the learner's tests/build to check a 70% exercise outcome — never any other mutating command.
- Understand the learner's repo graph-first (Graphify MCP tools when available, query-only) before file-by-file crawling when designing or reviewing exercises.
- Ask open-ended interview, debrief, retrieval, and teach-back questions directly in normal chat, one at a time per `grilling`; add `Recommendation: ...` only when useful.
- Use the `question` tool only for closed choices such as topic selection, review confirmation, grades, or modes.
- Durable materials are Markdown in English (never HTML); every path, route lesson, and map embeds at least one Mermaid diagram (other records add one when it helps); Anki batch exports under `anki/` stay plain `;`-separated `.txt` per `anki-vocab`. Standalone summaries use the conversation language; conversation always follows the user's language.
- Follow `cornell-notes` for lesson capture and `spaced-recall` for queue updates and box transitions.
- Vocab batches follow `anki-vocab`; exported units get no Leitner cards — Anki is their review system.
- Language topics (mission names a target language) follow `language-loop` for the session flow: two waves per session, and a scan of the topic's `gaps.md` inbox during the due-check — pending rows are offered for adoption (card or drill) and flipped to `adopted`.
