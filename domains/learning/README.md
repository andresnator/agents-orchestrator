# Learning Domain

Durable, multi-session learning and explicit English coaching. Learning remains independent from the opt-in SDLC profile.

## Quick path

1. Include `learning,common` in the full selected domain list.
2. Start or resume a topic with `/learn <topic>`.
3. Complete due reviews before new material; use `/english` for explicit English input.

## Entry points

| Entry | Use | Result |
|---|---|---|
| `/learn <topic>` | Start or resume learning | Mission, path, exercises, and reviews |
| `/learn <mode>` | Run review, quiz, map, teach, vocab, drill, or status | Updated topic artifacts |
| `/english <text>` | Request English coaching | Correction, explanation, and practice |
| `mentor` | Work in a primary learning session | Same routing as `/learn` |

State lives under `.ai/learning/`. The mentor may inspect a repository and ask to run its tests, but never edits learner code. `/english` stores only synthetic gap patterns, and only after explicit opt-in. The optional `recall-calc` plugin provides read-only Leitner date calculations. See the [learning guide](../../docs/learning-domain.md).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent (primary) | `mentor` | Coordinates multi-session learning flows |
| Agent (subagent) | `english-tutor` | Provides explicit English coaching |
| Command | `/learn` | Routes learning and review modes |
| Command | `/english` | Routes English correction and practice |
| Plugin | `recall-calc` | Calculates Leitner dates read-only |
| Skill | `anki-vocab` | Creates situation-driven vocabulary batches |
| Skill | `bidirectional-translation` | Runs delayed retranslation drills |
| Skill | `cornell-notes` | Captures lessons as Cornell notes |
| Skill | `english-tutor` | Improves English and records gaps |
| Skill | `feynman-teachback` | Runs learner-led concept teach-backs |
| Skill | `language-loop` | Runs input-first language sessions |
| Skill | `learning-loop` | Runs mission-grounded learning loops |
| Skill | `spaced-recall` | Schedules Leitner-style Markdown reviews |
