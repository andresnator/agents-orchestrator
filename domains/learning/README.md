# learning

Interactive, multi-session learning built around one command: `/learn`. Inspired by Matt Pocock's `teach` skill, reworked for how Andres learns: Markdown artifacts only (no HTML), Mermaid mindmaps and flowcharts, question-driven retrieval, Cornell note-taking, Leitner spaced repetition, Feynman teach-backs, and the 70-20-10 model (70% doing real exercises in the learner's own repos, 20% Socratic debrief plus community resources, 10% formal micro-lessons with primary sources).

The domain has a single hidden agent, `mentor` (`mode: subagent`, so it never appears in OpenCode's agent switcher), invoked only through `/learn` (`agent: mentor` + `subtask: true`). The `learning-loop` skill is the methodology contract; `cornell-notes` defines lesson capture, `spaced-recall` defines the review queue and box transitions (leeches, ~15-card chunks, interleaving, environment-sourced dates), `feynman-teachback` defines teach-back sessions where the learner explains to a naive-student mentor and gaps demote recall cards, and `anki-vocab` defines Anki vocabulary batch exports for language topics (situation-driven natural phrases reinforced from already-learned vocabulary, translated into the learner's native language — Spanish by default). The mentor reads the learner's repo graph-first (CodeGraph when available) to design exercises and has ask-gated, verification-only bash (the `date` command and the learner's tests/build) — it never edits the learner's repos. Usage guide: `docs/learning-domain.md`. All questions go through `native-question-ux` and interviews follow `grilling` (both live in the `common` domain, which this domain assumes installed).

All state lives under `.ai/learning/`: a `dashboard.md` plus one `<topic-slug>/` directory per topic with `mission.md`, `path.md` (Mermaid roadmap), `review-queue.md`, `resources.md`, `vocabulary.md` (Anki export inventory), and `notes/`, `exercises/`, `quizzes/`, `anki/` files. Every `/learn` invocation runs the spaced-repetition due-check first — there is no scheduler; the queue is pull-based.

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (subagent) | `mentor` | Runs hidden multi-session learning flows |
| Command | `/learn` | Routes learning, review, quiz, and status modes |
| Skill | `anki-vocab` | Create situation-driven Anki vocabulary batches |
| Skill | `cornell-notes` | Capture micro-lessons as Cornell notes |
| Skill | `feynman-teachback` | Run learner-led Feynman teach-backs |
| Skill | `learning-loop` | Run mission-grounded 70-20-10 learning loops |
| Skill | `spaced-recall` | Schedule Leitner-style Markdown recall reviews |

```mermaid
graph TD
    L["/learn ..."] --> D{Due cards?}
    D -- yes --> R["Review session<br/>(spaced-recall: grade, move boxes)"]
    D -- no --> M{Mode}
    R --> M
    M -- new topic --> MI["Mission interview -> mission.md<br/>path.md roadmap"]
    M -- continue --> TEN["10% micro-lesson<br/>Cornell note + Mermaid map"]
    TEN --> SEV["70% exercise in the learner's repo<br/>(mentor coaches + ask-gated test run, never solves)"]
    SEV --> TWE["20% Socratic debrief<br/>+ community resources"]
    TWE --> Q["New cues -> review-queue.md<br/>path.md updated"]
    Q --> DONE{All modules done?}
    DONE -- yes --> CAP["Capstone teach-back vs mission<br/>mission.md -> completed"]
    M -- teach --> F["Feynman teach-back<br/>(gaps -> cards to box 1 + return paths)"]
    F --> Q
    M -- vocab --> V["Anki batch txt (anki-vocab)<br/>+ vocabulary.md registry"]
    M -- quiz/map/status --> A["Quiz from cue bank / mindmap / dashboard"]
```

Install with `installers/opencode.sh install --domain learning`. Known fallback: if native questions do not surface well from the subtask session, change `mentor` to `mode: primary` (it becomes visible) or drop `subtask: true` from the command.
