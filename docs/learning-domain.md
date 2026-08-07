# Use the Learning Domain

`/learn` builds durable multi-session learning paths under `.ai/learning/`. `/english` provides explicit English coaching and can feed recurring synthetic gap patterns into a language topic.

## Quick path

```bash
installers/opencode.sh install
```

Start a topic with `/learn <topic>`, confirm its mission and path, then use `/learn` regularly. Every session offers due reviews before new material; the queue is pull-based, not scheduled.

## Commands

| Command | Outcome |
|---|---|
| `/learn <topic>` | Create or resume a topic with mission, cadence, and 4-8 modules |
| `/learn` | Continue the active topic after the due check |
| `/learn review [topic]` | Review due cards oldest-first and interleaved |
| `/learn quiz [topic]` | Run retrieval practice and record pacing evidence |
| `/learn map [topic]` | Refresh the topic mind map |
| `/learn teach [concept]` | Run a Feynman teach-back |
| `/learn vocab [theme]` | Export phrase-based Anki cards for a language topic |
| `/learn drill [unit]` | Run delayed bidirectional translation |
| `/learn status` | Rebuild the cross-topic dashboard |
| `/english [text]` | Correct, explain, practice, or summarize explicit English input |

## Learning loop

Each general module combines:

- 10% formal input captured as a Cornell note with retrieval cues;
- 70% a real exercise that the mentor scopes but does not solve;
- 20% Socratic debrief and curated community resources.

Every cue becomes a Leitner card with 1/3/7/14/30-day intervals. Again, Hard, Good, and Easy update the box and next date. Repeated failures become leeches to reformulate or split. The optional `recall-calc` plugin performs date and due-list arithmetic; otherwise the mentor applies the same table.

Feynman sessions classify gaps, attach return paths, and end with the learner's analogy. Completing modules is not enough: the mission closes only after a capstone teach-back satisfies the observable goal. Reviews continue until cards are mastered.

## Language topics

Language topics replace the general module loop with bilingual dialogue units:

1. Passive wave: read a comprehensible target-language dialogue with natural translation.
2. Active wave after five units: translate unit N-5 back from memory and classify differences.
3. Send phrases to Anki and grammar patterns to the recall queue.

`/english` never monitors passively. With explicit opt-in, it appends recurring categories as synthetic patterns to the topic's `gaps.md`; the mentor offers each pending row as a card or drill. Actual user sentences are not stored in that inbox.

## State

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

The mentor writes only under `.ai/learning/**`; it may read a repository to design exercises and may ask permission to run tests for verification, but never edits the learner's code. `english-tutor` can only append to an existing language topic's `gaps.md` after opt-in.

## Troubleshooting

- Due reviews accumulate: run `/learn review`; `/learn status` shows the queue.
- Cadence feels wrong: tell the mentor; the learner owns the final cadence.
- `/english` questions do not surface: run it without subtask mode or expose `english-tutor` as a primary, then reinstall.
- Decline test execution if verification should remain manual.
