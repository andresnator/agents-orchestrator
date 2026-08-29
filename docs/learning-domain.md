# Use the Learning Domain

`/learn` builds durable learning paths under `.ai/learning/`. `/english` coaches explicit English input and can feed synthetic recurring gaps into a language topic after opt-in.

## Quick path

```bash
installers/opencode.sh install --domain learning,common
```

Filtered installation is a sync; include every domain you want to keep in the selected list.

Start with `/learn <topic>`, confirm the proposed mission and path, then return with `/learn`. Every session offers due reviews before new material; there is no background scheduler.

## Commands

| Command | Outcome |
|---|---|
| `/learn <topic>` | Start or resume a topic |
| `/learn review [topic]` | Review due cards |
| `/learn quiz [topic]` | Run retrieval practice |
| `/learn map [topic]` | Refresh the topic map |
| `/learn teach [concept]` | Run a Feynman teach-back |
| `/learn vocab [theme]` | Export phrase-based Anki cards |
| `/learn drill [unit]` | Run delayed bidirectional translation |
| `/learn status` | Rebuild the dashboard |
| `/english [text]` | Correct, explain, or practice English |

## Learning loop

General modules combine 10% formal input in Cornell notes, 70% real exercises, and 20% Socratic debrief plus curated resources. The mentor scopes exercises but never solves or edits the learner's repository work.

Retrieval cues become Leitner cards with 1, 3, 7, 14, and 30-day intervals. Repeated failures become leeches to split or rewrite. `recall-calc` supplies read-only date arithmetic when installed; the skill tables are the fallback.

Module completion is not mission completion. A capstone teach-back must satisfy the observable goal; reviews continue until cards are mastered.

## Language topics

Language topics use two waves:

1. Read one comprehensible bilingual dialogue.
2. After five units, translate unit N-5 from memory and compare it with the original.
3. Send phrases to Anki and grammar patterns to the review queue.

`/english` never monitors passive conversation. With explicit opt-in, it stores only synthetic gap patterns in `gaps.md`; the mentor later offers them as cards or drills. Raw user sentences are not copied into that inbox.

## State and safety

```text
.ai/learning/<topic>/
  mission.md
  path.md
  review-queue.md
  resources.md
  vocabulary.md
  gaps.md
  anki/
  notes/
  exercises/
  quizzes/
  teachbacks/
  dialogues/
```

The mentor delegates each exact state mutation to `learning-recorder`, which can only read, edit, or write under `.ai/learning/**`. If that handoff fails, the mentor reports the failure and uses its equally scoped direct-write fallback without retrying. It may read repository files and ask permission to run tests, but never edits learner code. `english-tutor` remains separate and may only append to an existing language topic after opt-in.

## Troubleshooting

- Due reviews accumulate: run `/learn review`; use `/learn status` for the queue.
- Cadence feels wrong: tell the mentor; the learner owns final cadence.
- `/english` questions do not surface: remove subtask mode or expose `english-tutor` as primary, then reinstall.
- Verification should stay manual: decline test execution.
