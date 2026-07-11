---
name: anki-vocab
description: "Trigger: anki, vocab, vocabulary cards, vocabulario, tarjetas anki, learn vocab. Anki-importable vocabulary batches for any target language: situation-driven natural phrases built preferentially from already-learned vocabulary, with Spanish translations, exported as ;-separated txt."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "1.0.1"
---

# Anki Vocab

## Activation Contract

Use for the `vocab` mode of `/learn` on **language-learning topics** — any target language (the language named in `mission.md`), always translated into Spanish: generating a batch of Anki-importable vocabulary cards from words, phrases, or a situation/theme. Owns `vocabulary.md` (the learned-unit registry, from `assets/vocabulary-template.md`) and `anki/` (batch exports, format fixture for an English-topic batch in `assets/batch-format.txt`) under each `.ai/learning/<topic-slug>/`.

Do not use for non-language topics: if `mission.md` shows the topic is not a language, say vocab mode only applies to language topics and ask (via `native-question-ux`) whether to pick a language topic or run another mode — never generate anyway. Do not create Leitner cards for exported units: Anki is their spaced-repetition system; `review-queue.md` stays for conceptual cues (add a vocab unit there only on explicit learner request).

## Hard Rules

- **Phrase as unit**: every row anchors a common, natural phrase or chunk of the target language as native speakers use it — never an isolated dictionary word with a synthetic sentence.
- **Situation-driven**: sentences come from real situations relevant to the learner — the theme they passed, or contexts drawn from `mission.md`/`path.md` when they passed none.
- **Reinforcement (i+1)**: build each sentence preferentially from units already in `vocabulary.md` and cues in `review-queue.md`, so one new element rides on known material. Due or recently demoted cards are preferred filler.
- **No duplicates**: a unit already in `vocabulary.md` is never re-exported as a new row's anchor (it may still appear inside other rows' sentences). Report skipped duplicates.
- **Registry stays in sync**: every generated batch appends its new units to `vocabulary.md` in the same session — an exported unit that is not registered breaks future reinforcement.
- Batch files are the one non-Markdown artifact in the learning state: plain UTF-8 `.txt`, exactly per the Output Format below.

## Input Handling

| Input after `vocab` | Behavior |
| --- | --- |
| words or phrases | One row per given unit, normalized into a natural chunk; sentences situation-grounded and reinforcement-built. |
| a situation/theme (e.g. "at the airport") | Select the most useful natural phrases for that situation; default batch size 12, confirmed via `native-question-ux`. |
| empty | Propose a batch: pick a situation from `mission.md`/`path.md` plus reinforcement of due/weak `review-queue.md` cards; confirm before generating. |

## Output Format

One row per card, no header line, no quoting, separator `;`, five fields:

`unit;meaning;part of speech;example;spanish translation`

- `unit`: the phrase/word anchor, in the target language.
- `meaning`: short gloss of the unit, in simple target-language terms.
- `part of speech`: of the unit (phrase, phrasal verb, verb, noun, idiom, ...).
- `example`: one full natural target-language sentence using the unit in the situation.
- `spanish translation`: full-sentence Spanish translation of the example.
- No `;` and no double quotes inside any field — rephrase instead.
- File: `.ai/learning/<topic-slug>/anki/NNNN-<batch-slug>.txt`, `NNNN` sequential from `0001` within `anki/`, `<batch-slug>` from the theme or first unit.

## Output Contract

End every batch by reporting: batch file path, row count, new units registered in `vocabulary.md`, duplicates skipped, a reinforcement summary (which known units were reused), and the Anki import reminder (File > Import, separator `;`).
