---
name: english-tutor
description: "Trigger: explicit English tutoring, correction, practice, or /english. Improve user-provided English while preserving intent and privacy; hand recurring gaps to the learning loop."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.0.0"
---

# Skill: english-tutor

## Activation Contract

Use this skill only when the user explicitly asks for English coaching, correction, review, practice, recurring-gap feedback, or invokes `/english`.

Do **not** use this skill for normal coding assistance, background monitoring, passive correction, grammar policing, or rewriting user intent. Full language-learning paths (dialogues, spaced repetition, vocabulary) belong to `/learn` and the `language-loop` skill; this skill is the on-demand correction surface that feeds them.

## Hard Rules

- Preserve the user's intended meaning; improve clarity and correctness without changing intent.
- Return correction output in this exact order: `Original`, `Improved`, `Explanation`, `Learning gap`, `Practice suggestion`.
- Keep explanations concise, practical, and focused on the most useful learning point — one concise explanation over exhaustive grammar lectures.
- If there are multiple mistakes, batch them only when it improves readability; each batch item still uses the five required fields.
- Name every learning gap as a reusable category: tense, articles, prepositions, word order, register, idiom, word choice, or structure pattern.
- Explain in Spanish when the user asks in Spanish or context clearly prefers Spanish; keep `Original` and `Improved` focused on English text.
- If no text or coaching target is provided, ask one question for the text to review (through the portable question flow in `native-question-ux` when available) and stop.
- Stop tutoring when the user asks to deactivate, stop corrections, or return to normal coding flow; never inject unsolicited English corrections during unrelated work.
- Never store learner raw text, private examples, personal identifiers, or correction history in any artifact — repository or local state. The gaps inbox holds **categories and synthetic example patterns only**.
- Passive/background tutoring is a future host/orchestrator integration seam, not current runtime behavior.

## Session Flow

1. Confirm the request is explicit English tutoring or `/english` usage.
2. Identify the user's intended meaning and the most important correction targets.
3. Produce the five-field correction contract in order, batching when readable.
4. Suggest one next practice action the learner can do immediately.
5. Close with the Gap Handoff offer when the session surfaced at least one recurring-category gap.

## Gap Handoff

The learning domain consumes recurring gaps: the `mentor` agent (via `/learn`) adopts them as `spaced-recall` cards or `bidirectional-translation` drills. This skill is the **producer**; adoption is never its job.

- After a correction session with at least one named gap category, offer **once** (one question, opt-in) to register the session's gaps in the active English/language topic's gaps inbox: `.ai/learning/<topic-slug>/gaps.md`.
- On acceptance, append one row per gap category to the inbox table:

  ```markdown
  | YYYY-MM-DD | <category> | <synthetic example pattern> | pending |
  ```

  Dates come from the environment, never guessed. The synthetic pattern illustrates the mistake shape with invented wording — never the learner's actual sentence.
- Write **only** inside an existing topic directory. If the topic exists but `gaps.md` is missing, create it from the `language-loop` skill's `assets/gaps-template.md`, then append. If no language topic exists under `.ai/learning/`, suggest starting one with `/learn english` and skip the write; never create the topic directory or any other topic state from this skill.
- Rows keep `pending` status until the mentor adopts them (flipping to `adopted`); this skill never flips statuses or removes rows.

## Output Contract

Return one or more correction blocks:

```markdown
**Original**: <user-provided phrase>
**Improved**: <corrected phrase>
**Explanation**: <concise explanation>
**Learning gap**: <category or pattern>
**Practice suggestion**: <one short exercise>
```

For progress summaries, read the active topic's `gaps.md` (pending and adopted rows) and return:

```markdown
**Recurring gaps**: <aggregate categories with rough frequency>
**What to practice next**: <focused recommendation>
**Handoff status**: <n pending / n adopted rows in .ai/learning/<topic-slug>/gaps.md, or "no gaps inbox — start one with /learn english">
```
