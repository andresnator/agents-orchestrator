# Use the Learning Domain

`mentor` and `/learn <prompt>` can answer a bounded learning request without creating state. Explicit path requests still build durable learning under `.ai/learning/`; `/english` remains a separate opt-in coaching flow.

## Quick path

```bash
installers/opencode.sh install --domain learning,common
```

Filtered installation is a sync; include every domain you want to keep in the selected list.

Ask a concrete question for a bounded session, or explicitly ask for a path when you want durable progress. Durable sessions offer due reviews before new material; bounded sessions check reviews only on request. There is no persistent background scheduler: active review grades and explicit compact-summary writes use transient background tasks.

## Commands

| Command | Outcome |
|---|---|
| `/learn <prompt>` | Answer a bounded request or classify it as durable |
| `/learn <topic or path request>` | Start or resume a durable topic |
| `/learn review [topic]` | Review due cards |
| `/learn quiz [topic]` | Run retrieval practice |
| `/learn map [topic]` | Refresh the topic map |
| `/learn teach [concept]` | Run a Feynman teach-back |
| `/learn vocab [theme]` | Export phrase-based Anki cards |
| `/learn drill [unit]` | Run delayed bidirectional translation |
| `/learn status` | Rebuild the dashboard |
| `/english [text]` | Correct, explain, or practice English |

## Bounded sessions and durable paths

Use a bounded session for a concrete question that can be handled now. It leads with the answer, uses short chunks, asks only useful questions, and does not create a topic, mission, path, note, exercise, capstone, or review card.

| Learner request | Result |
|---|---|
| `Explícame la diferencia entre cohesión y acoplamiento` | Teach now without state, date lookup, or automatic due-check. |
| `Guárdalo` | Start one background compact-summary write and continue the conversation. |
| `Actualiza el resumen con esta corrección y elimina ideas repetidas` | Re-read and canonically rewrite the same summary, deduplicating without losing distinct nuances. |
| `¿Hay algo para repasar?` | Run the existing due-check at that moment. |
| `/learn quiero un path trimestral de diseño de APIs Java` | Use the durable loop, including topic discovery and due reviews. |

Explicit modes, an existing topic selected for continuation, and clear requests for a path, progress, or continued practice always use durable learning. If intent is ambiguous, `mentor` asks once whether the learner wants a bounded session or a path.

## Learning loop

General modules combine 10% formal input in Cornell notes, 70% real exercises, and 20% Socratic debrief plus curated resources. The mentor scopes exercises but never solves or edits the learner's repository work.

Retrieval cues become Leitner cards with 1, 3, 7, 14, and 30-day intervals. Repeated failures become leeches to split or rewrite. `recall-calc` supplies read-only date arithmetic when installed; the skill tables are the fallback.

Module completion is not mission completion. A capstone teach-back must satisfy the observable goal; reviews continue until cards are mastered.

## Background persistence

Review grades and compact summaries use separate task maps, targets, receipts, and failure rules. A completion from one protocol never settles or advances the other.

### Review grades

After each review grade, the mentor starts a fresh, transient `learning-recorder` task and asks the next cue without waiting for persistence. A completion notification settles only its matching handoff; it does not repeat, answer, or advance a cue that is already open. After the final grade, the mentor may report that persistence is finishing, but the final persisted-artifact and next-due summary waits until every handoff has settled.

Background recorder support depends on the running OpenCode build. Supported builds may require this experimental flag to be set before OpenCode starts:

```bash
export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
```

Restart OpenCode after setting the flag. No minimum OpenCode release is claimed here; check whether the installed build exposes background Task mode.

If background mode is missing, rejects a launch, or a detached recorder task fails, the mentor reports the problem and uses the existing direct fallback for only that card's intended changes under `.ai/learning/**`. It rereads affected targets first so it can reconcile partial changes. It never silently falls back to a foreground recorder and never retries or resumes the failed detached task.

### Compact summaries

Only an explicit save or update request launches `learning-summarizer`. The mentor chooses an exact `.ai/learning/summaries/YYYY-MM-DD-<slug>.md` target, passes the conversation language and covered material, then continues without waiting. An unrelated filename collision uses `-2`, `-3`, or the next available suffix.

The writer creates or re-reads one document with a title, date, brief synthesis, and lightweight Cornell guide-question table. It merges semantically equivalent ideas, preserves distinct nuances, applies explicit corrections, and rewrites the complete canonical summary. It does not append blindly, invent missing material, create parallel versions, or write outside `summaries/`.

Only one summary mutation may be pending per target; the latest explicit update is coalesced until the current write succeeds. A failed current write discards that deferred update and requires a new explicit request. Success shows only `Resumen guardado: <ruta>`. Failure shows `No se pudo guardar: <motivo>. Puedes pedir “reintenta guardarlo”.` There is no automatic retry, foreground writer, direct fallback, or implicit save.

## Language topics

Language topics use two waves:

1. Read one comprehensible bilingual dialogue.
2. After five units, translate unit N-5 from memory and compare it with the original.
3. Send phrases to Anki and grammar patterns to the review queue.

`/english` never monitors passive conversation. With explicit opt-in, it stores only synthetic gap patterns in `gaps.md`; the mentor later offers them as cards or drills. Raw user sentences are not copied into that inbox.

## State and safety

```text
.ai/learning/
  dashboard.md
  summaries/                       # reserved; never discovered as a topic
    YYYY-MM-DD-<slug>.md            # opt-in compact session summary
  <topic>/                          # durable multi-session state
    mission.md
    path.md
    review-queue.md
    resources.md
    vocabulary.md
    gaps.md                         # language topics only
    anki/
    notes/
    exercises/
    quizzes/
    teachbacks/
    dialogues/                     # language topics only
```

The mentor delegates durable topic mutations to mechanical `learning-recorder`; review-card handoffs follow the background timing and scoped direct fallback above, while other durable checkpoints remain foreground. `learning-summarizer` separately owns semantic create/update operations only under `summaries/`, with no fallback. The mentor may read repository files and ask permission to run tests, but never edits learner code. `english-tutor` remains separate and may only append to an existing language topic after opt-in.

## Troubleshooting

- Due reviews accumulate: run `/learn review`; use `/learn status` for the queue.
- A summary failed: fix the reported cause, then explicitly ask to retry; no retry occurs automatically.
- Cadence feels wrong: tell the mentor; the learner owns final cadence.
- `/english` questions do not surface: remove subtask mode or expose `english-tutor` as primary, then reinstall.
- Verification should stay manual: decline test execution.
