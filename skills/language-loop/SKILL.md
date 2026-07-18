---
name: language-loop
description: "Trigger: language-learning topics inside /learn (learn english, aprender ingles, language path, target language in mission). Input-first two-wave session flow: bilingual dialogue units, delayed retranslation, gap-inbox adoption."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "1.1.0"
---

# Language Loop

## Activation Contract

Use for language-learning topics inside `/learn`: any topic whose `mission.md` names a target language. `learning-loop` remains the outer contract (mission grounding, path, due-check, ZPD pacing, output contract, hard rules); this skill **replaces its 70-20-10 module flow** with a language-acquisition session flow.

Do not use for non-language topics, for on-demand corrections outside `/learn` (`english-tutor` skill), or for standalone vocabulary export (`anki-vocab` handles the batch mechanics either way).

## Hard Rules

- **Input first**: sessions are mostly comprehension. Production is invited, never forced early — a learner who prefers to only read/listen for the first units is on track, not behind (silent period).
- **Comprehensible i+1**: every dialogue unit is ~90% understandable for this learner — built preferentially from `vocabulary.md` units and review-queue cards (reinforcement), with a small number of new items. Too hard means shrink, not annotate everything.
- **Compelling content**: dialogues come from the learner's `mission.md` situations and interests, never generic textbook scenes. Interesting input keeps the affective filter low.
- **Tolerate ambiguity**: unknown items are captured in context, not exhaustively explained. A meaning that emerges from the situation needs no grammar lecture.
- **Two waves per session**: one new passive unit (comprehension) plus, once ≥5 units exist, one active retranslation of unit N−5 per `bidirectional-translation`. The waves run in parallel lanes, Assimil-style — the active wave always trails the passive wave.
- **Audio is an optional enhancement**: when a TTS engine is available, passive-wave units get audio per `lesson-audio` and the wave runs listen-first (listen slow → listen normal while reading → read). No engine → the wave proceeds text-only with the unit marked `Audio: pending`; never block a session on TTS availability.
- **No double SRS**: captured vocabulary units go to `anki-vocab` batches (Anki is their review system); noticed grammar/structure patterns become `spaced-recall` cards. One item, one system.
- **Gaps inbox**: adopt pending `gaps.md` rows (produced by `english-tutor` sessions) at session start — each becomes a `spaced-recall` card or a targeted `bidirectional-translation` drill, and the row flips to `adopted`. Adoption is the mentor's duty; rows are never silently dropped.
- All `learning-loop` hard rules still apply: state under `.ai/learning/<topic-slug>/`, environment-sourced dates, Markdown + Mermaid artifacts in English, `native-question-ux` for questions, honest outcome records. Dialogue content is target language + native translation — the artifact framing stays English.

## Session Flow

1. **Due-check** (`spaced-recall`) — overdue cards first, as always.
2. **Gaps inbox** — scan `gaps.md` for `pending` rows; offer adopting them (card or drill), flip accepted rows to `adopted`.
3. **Passive wave** — one new bilingual dialogue unit → `dialogues/NNNN-<slug>.md` from `assets/dialogue-template.md`: target-language text, native translation, units list. After writing the unit, offer audio per `lesson-audio` (normal + slow renditions of the target-language text); with audio the wave is listen-first — listen slow, listen normal while reading, then read. The learner reads/listens for comprehension; unknowns get captured, not lectured.
4. **Active wave** — once ≥5 units exist: retranslate unit N−5 per `bidirectional-translation` (its Phase B); log the result in that unit's file.
5. **Capture** — new vocabulary units → `anki-vocab` batch candidates (registered in `vocabulary.md`); noticed structure patterns → `spaced-recall` cards.
6. **Close** — per the `learning-loop` Output Contract: update `path.md`, schedule cards, report the next due review and the next unit due for retranslation.

## State Additions

Inside the standard `learning-loop` topic layout:

```
.ai/learning/<topic-slug>/
  dialogues/NNNN-<slug>.md          # bilingual units + retranslation log
  audio/NNNN-<slug>[-slow].mp3      # unit renditions per lesson-audio (container per engine)
  gaps.md                           # gap inbox from english-tutor (assets/gaps-template.md)
```

The mentor seeds `gaps.md` from `assets/gaps-template.md` when the language topic is created. For language topics, `path.md` modules are situation clusters drawn from `mission.md`; each session's dialogue unit serves the active module, and a module is ✅ when its situations are covered by units that survived the active wave.

## Output Contract

The `learning-loop` session report, plus: dialogue unit created (path), its audio status (files written per `lesson-audio`, or `pending`), retranslation run and its noticing summary, gaps adopted (count), and the next unit entering the active wave.

## Attribution

Session flow absorbed from published language-learning methodology: Assimil's two-wave structure (passive lessons + delayed active retranslation), Luca Lampariello's bidirectional translation, Steve Kaufmann's input-first content-driven acquisition, and Stephen Krashen's comprehensible-input hypothesis (i+1, silent period, affective filter).
