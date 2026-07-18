# Using the learning domain

Two commands, a primary mentor plus a hidden tutor, nine methods. `/learn` drives multi-session learning paths whose state lives in the project you run it from, under `.ai/learning/`; `/english` is the on-demand English coaching surface that feeds recurring gaps into those paths. The `mentor` is `mode: primary`, sdd-style: it shows up in OpenCode's agent switcher and you can talk to it directly (a direct message is routed like `/learn` input), with `/learn` as the front door. `english-tutor` stays `mode: subagent` and is only reachable through `/english`.

## Install

```bash
installers/opencode.sh install          # default --domain all; install is a SYNC
```

Do not install with `--domain learning` alone if other domains are already installed: install syncs against the previous manifest and would remove them.

## Commands

| Invocation | What happens |
| --- | --- |
| `/learn spring-security` | New topic: short mission interview (why, observable goal, success criteria, time budget, prior knowledge) → `mission.md`, then a 4–8 module `path.md` with a Mermaid roadmap you confirm before module 1. If the slug already exists, it resumes. |
| `/learn` | Continue: overdue-review check, then the active topic's next module (asks which topic if several are active). |
| `/learn review` | Spaced-repetition session over all due cards (add a topic to scope it). |
| `/learn quiz [topic]` | Retrieval quiz from the topic's Cornell cue bank. Recorded in `quizzes/`, informs pacing, never moves boxes. |
| `/learn map [topic]` | Regenerate or expand the topic's Mermaid mindmap. |
| `/learn teach [concept]` | Feynman teach-back: you explain, the mentor plays a curious novice and probes for gaps. |
| `/learn vocab [words\|theme]` | Anki vocabulary batch for a language topic: natural phrases (situation-driven, built from already-learned vocabulary), exported as `;`-separated txt under `anki/` ready for Anki import; units registered in `vocabulary.md`. |
| `/learn drill [unit]` | Bidirectional-translation drill on a dialogue unit (weakest-first when empty): retranslate the native text into the target language from memory, compare against the original, capture the differences. Language topics only. |
| `/learn audio [unit]` | Generate or refresh a dialogue unit's audio (`pending` units backfilled oldest-first when empty): normal + slow (~−20%) renditions of the target-language text under `audio/`, using the best available engine — a configured TTS MCP (e.g. ElevenLabs) → `edge-tts` → macOS `say` → skip with an install hint. Language topics only. |
| `/learn status` | Dashboard across topics: progress, due and upcoming reviews, mastered counts. |
| `/english [text]` | Explicit English coaching: five-field corrections (`Original/Improved/Explanation/Learning gap/Practice suggestion`), practice prompts, or a progress summary over the gaps inbox. Opt-in only — never passive monitoring. |

Every invocation, in every mode, starts with the due-check: cards with `Next ≤ today` are offered (never forced) before new material. There is no scheduler — the queue is pull-based, so just invoking `/learn` regularly is the cadence.

## The methods, and where they bite

- **70-20-10** (`learning-loop`): each module is 10% formal (a micro-lesson captured as a Cornell note, with a primary source), 70% doing (a real exercise in your own repo — the mentor proposes, constrains, and gives escalating hints, but never writes the solution), and 20% social (Socratic debrief plus curated community resources in `resources.md`). When you finish an exercise, the mentor may ask permission to run your repo's tests to check the outcome (verification only — it never edits your code). To design and review exercises it reads your repo graph-first (CodeGraph when available) before crawling files.
- **Cornell** (`cornell-notes`): every lesson note is a Mermaid map + a `Cue (question) | Notes` table + a summary **in your own words** (the mentor records what you say, it never invents it). Each cue is a retrieval question.
- **Spaced repetition** (`spaced-recall`): every cue becomes a card in `review-queue.md`. Leitner boxes 1–5 with intervals 1/3/7/14/30 days; grades Again/Hard/Good/Easy move cards down/same/up; every grade re-dates the card from today (today's date comes from the environment, never a guess), and Good or Easy at box 5 masters the card. A card failed (`Again`) 3× is flagged `⚠ leech` and reformulated or split instead of left to churn. Reviews are offered in chunks of ~15, oldest-first and **interleaved** across notes/topics rather than blocked by lesson. In a review the mentor asks the cue, waits for your attempt, then reveals and asks for the grade.
- **Anki vocab** (`anki-vocab`): for language topics — any target language, translated into your native language (from `mission.md`, Spanish by default) — `vocab` mode exports card batches you import into Anki. Each row anchors a natural target-language phrase/chunk (never an isolated word), chosen from real situations (the theme you pass, or your mission/path context) and built preferentially from vocabulary you already know (i+1). Format: `unit;meaning;part of speech;example;native translation` — UTF-8, no header, no IPA. Exported units are registered in `vocabulary.md` for reinforcement and duplicate prevention, but get no Leitner cards: Anki is their review system (no double SRS).
- **Feynman** (`feynman-teachback`): in `teach` mode you explain a concept in simple terms; the mentor asks naive questions and never corrects mid-explanation. Gaps are classified (missing piece, hand-waved, wrong claim, jargon crutch), demote the matching cards to box 1, and each gets a return path to a source. You close with an analogy in your own words. A fluent teach-back never auto-promotes cards — only scheduled reviews promote.

When every module is ✅, the topic closes with a **capstone teach-back** against your mission's observable goal and success criteria; `mission.md` flips to `Status: completed` and `/learn status` lists it under Completed. Reviews keep surfacing until every card is Mastered — completion closes the path, not the retention loop.

Materials are Markdown in English (never HTML), always with at least one Mermaid diagram — except Anki batch exports under `anki/`, plain `;`-separated `.txt`; the conversation follows your language.

## Language topics (English as a learning subdomain)

When a topic's `mission.md` names a target language, `language-loop` replaces the 70-20-10 module flow with an input-first, two-wave session (absorbed from Assimil, Lampariello, Kaufmann, and Krashen):

- **Passive wave**: each session adds one new bilingual dialogue unit (`dialogues/NNNN-<slug>.md`) — target-language text with a natural native translation, built from your mission's situations and ~90% from vocabulary you already know (comprehensible i+1). You read for comprehension; unknowns are captured in context, not lectured. Production is invited, never forced early.
- **Audio** (`lesson-audio`): each dialogue unit can be heard, not just read — one normal and one slow (~−20%) rendition of the target-language text only, saved under `audio/`, with one consistent voice per topic recorded in `mission.md`. With audio the passive wave runs listen-first (listen slow → listen normal while reading → read), the Assimil order. Engines are probed in a ladder — a TTS MCP you already configured (e.g. ElevenLabs) → `edge-tts` (free neural voices, also writes synced subtitles) → macOS `say` (reduced quality) — and synthesis is ask-gated, announced, and writes only under `audio/`. No engine available never fails the session: the unit is marked `Audio: pending` with a one-line install hint, and `/learn audio` backfills later.
- **Active wave** (`bidirectional-translation`): once 5+ units exist, each session also retranslates unit N−5 — you turn the native text back into the target language from memory, then compare against the original. Differences are classified (word choice, structure/order, missing chunk, grammar pattern) and captured: chunks → Anki candidates, patterns → recall cards. Noticing over grading; the delay is the method. `/learn drill [unit]` runs one standalone.
- **Gap handoff** (`english-tutor` + `/english`): correction sessions can, with your opt-in, append recurring gap categories with **synthetic example patterns only** (never your actual sentences) as `pending` rows in the topic's `gaps.md` inbox. The mentor scans the inbox at every due-check and offers adopting each row as a recall card or a drill, flipping it to `adopted`. No topic yet → `/english` suggests `/learn english`. The old Notion-side `English Coach Memory` is retired; `gaps.md` is the recurring-gap memory.
- Everything transversal still applies: the due-check runs first, vocabulary goes through `anki-vocab` (Anki is its SRS — no Leitner double-tracking), grammar patterns go through `spaced-recall`, and quizzes/teach-backs work as in any topic.

## State layout (per project, created by the mentor)

```
.ai/learning/
  dashboard.md                 # rebuilt by /learn status
  <topic-slug>/
    mission.md                 # why + observable goal + success criteria
    path.md                    # Mermaid roadmap + module table + pacing log
    review-queue.md            # Leitner queue + Mastered section
    resources.md               # curated primary sources + community venues
    vocabulary.md              # units exported to Anki (reinforcement inventory)
    anki/NNNN-<batch>.txt      # Anki import batches (;-separated, no header)
    notes/NNNN-<lesson>.md     # Cornell notes (10%)
    exercises/NNNN-<name>.md   # briefs, hints, outcome log (70% + 20% debrief)
    quizzes/NNNN-YYYY-MM-DD.md # quiz results (pacing signal)
    teachbacks/NNNN-<concept>.md # Feynman sessions: gaps, return paths, analogy
    dialogues/NNNN-<slug>.md   # language topics: bilingual units + retranslation log
    audio/NNNN-<slug>[-slow].mp3 # language topics: unit renditions (lesson-audio; container per engine)
    gaps.md                    # language topics: gap inbox (english-tutor -> mentor)
```

The mentor writes only under `.ai/learning/**` — it reads your repos to design and review the 70% exercises but never edits them. The `english-tutor` agent is narrower still: its only writable path is an existing topic's `gaps.md`, append-only and opt-in.

## Troubleshooting

- **Native questions don't surface from the subtask session**: only `/english` runs its agent as a subtask (`agent: english-tutor` + `subtask: true` — its opt-in gap handoff is question-driven); `/learn` runs in the `mentor` primary session, where the question UI is native. If OpenCode doesn't show the question UI from `/english`'s child session, drop `subtask: true` from `domains/learning/commands/english.md` or set `english-tutor` to `mode: primary` (it becomes visible in the switcher) and re-run the installer.
- **Reviews pile up**: `/learn review` clears the backlog oldest-first; `/learn status` shows what's coming so you can pick session days.
- **Wrong pacing**: the mentor adjusts from quiz/review/teach-back evidence (zone of proximal development) and records every pacing decision in the `path.md` log — override it by just saying so during a session.
- **The mentor asks to run tests**: when you close a 70% exercise it may ask permission to run your repo's test/build command to verify the outcome. Bash is ask-gated and narrow — it reads the date, runs your suite, or synthesizes lesson audio into `.ai/learning/<topic>/audio/`; it never edits your code or runs any other mutating command. Decline and just report the result yourself if you prefer.
- **No audio / TTS engine missing**: `lesson-audio` probes a configured ElevenLabs MCP first (only if you already set up `elevenlabs-mcp` with `ELEVENLABS_API_KEY`; free tier ~10k credits/month), then `edge-tts`, then macOS `say`. For the recommended free default, install it with `pipx install edge-tts` (or `pip install edge-tts`). Units skipped meanwhile stay `Audio: pending` — backfill them anytime with `/learn audio`.
