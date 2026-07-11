# Using the learning domain

One command, one hidden agent, four methods. `/learn` drives multi-session learning paths whose state lives in the project you run it from, under `.ai/learning/`. The `mentor` agent (`mode: subagent`) never shows up in OpenCode's agent switcher — you only ever talk to it through `/learn`.

## Install

```bash
installers/opencode.sh install          # default --domain all; install is a SYNC
```

Do not install with `--domain learning` alone if other domains are already installed: install syncs against the previous manifest and would remove them. OpenCode-only for now — skip this domain when running `claude.sh`/`codex.sh` (the `agent:` + `subtask:` delegation is OpenCode-specific).

## Commands

| Invocation | What happens |
| --- | --- |
| `/learn spring-security` | New topic: short mission interview (why, observable goal, success criteria, time budget, prior knowledge) → `mission.md`, then a 4–8 module `path.md` with a Mermaid roadmap you confirm before module 1. If the slug already exists, it resumes. |
| `/learn` | Continue: overdue-review check, then the active topic's next module (asks which topic if several are active). |
| `/learn review` | Spaced-repetition session over all due cards (add a topic to scope it). |
| `/learn quiz [topic]` | Retrieval quiz from the topic's Cornell cue bank. Recorded in `quizzes/`, informs pacing, never moves boxes. |
| `/learn map [topic]` | Regenerate or expand the topic's Mermaid mindmap. |
| `/learn teach [concept]` | Feynman teach-back: you explain, the mentor plays a curious novice and probes for gaps. |
| `/learn status` | Dashboard across topics: progress, due and upcoming reviews, mastered counts. |

Every invocation, in every mode, starts with the due-check: cards with `Next ≤ today` are offered (never forced) before new material. There is no scheduler — the queue is pull-based, so just invoking `/learn` regularly is the cadence.

## The methods, and where they bite

- **70-20-10** (`learning-loop`): each module is 10% formal (a micro-lesson captured as a Cornell note, with a primary source), 70% doing (a real exercise in your own repo — the mentor proposes, constrains, and gives escalating hints, but never writes the solution), and 20% social (Socratic debrief plus curated community resources in `resources.md`).
- **Cornell** (`cornell-notes`): every lesson note is a Mermaid map + a `Cue (question) | Notes` table + a summary **in your own words** (the mentor records what you say, it never invents it). Each cue is a retrieval question.
- **Spaced repetition** (`spaced-recall`): every cue becomes a card in `review-queue.md`. Leitner boxes 1–5 with intervals 1/3/7/14/30 days; grades Again/Hard/Good/Easy move cards down/same/up; Good or Easy at box 5 masters the card. In a review the mentor asks the cue, waits for your attempt, then reveals and asks for the grade.
- **Feynman** (`feynman-teachback`): in `teach` mode you explain a concept in simple terms; the mentor asks naive questions and never corrects mid-explanation. Gaps are classified (missing piece, hand-waved, wrong claim, jargon crutch), demote the matching cards to box 1, and each gets a return path to a source. You close with an analogy in your own words. A fluent teach-back never auto-promotes cards — only scheduled reviews promote.

Materials are Markdown in English (never HTML), always with at least one Mermaid diagram; the conversation follows your language.

## State layout (per project, created by the mentor)

```
.ai/learning/
  dashboard.md                 # rebuilt by /learn status
  <topic-slug>/
    mission.md                 # why + observable goal + success criteria
    path.md                    # Mermaid roadmap + module table + pacing log
    review-queue.md            # Leitner queue + Mastered section
    resources.md               # curated primary sources + community venues
    notes/NNNN-<lesson>.md     # Cornell notes (10%)
    exercises/NNNN-<name>.md   # briefs, hints, outcome log (70% + 20% debrief)
    quizzes/NNNN-YYYY-MM-DD.md # quiz results (pacing signal)
    teachbacks/NNNN-<concept>.md # Feynman sessions: gaps, return paths, analogy
```

The mentor writes only under `.ai/learning/**` — it reads your repos to design and review the 70% exercises but never edits them.

## Troubleshooting

- **Native questions don't surface from the subtask session**: the command runs the subagent via `agent: mentor` + `subtask: true`. If OpenCode doesn't show the question UI from the child session, either drop `subtask: true` from `domains/learning/commands/learn.md` or set `mentor` to `mode: primary` (it becomes visible in the switcher) and re-run the installer.
- **Reviews pile up**: `/learn review` clears the backlog oldest-first; `/learn status` shows what's coming so you can pick session days.
- **Wrong pacing**: the mentor adjusts from quiz/review/teach-back evidence (zone of proximal development) and records every pacing decision in the `path.md` log — override it by just saying so during a session.
