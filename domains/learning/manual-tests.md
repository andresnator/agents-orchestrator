# Learning manual tests

Run these cases in a disposable OpenCode project. One-off cases must leave no durable state unless saving is explicitly requested; durable cases may write only under `.ai/learning/`.

## Quick path

1. Install the current checkout's `learning,common` domains into a disposable project.
2. Run the affected IDs from the pull-request summary in fresh sessions.
3. Inspect `.ai/learning/` literally, including hidden files, then remove the project.

### MT-LEARNING-SESSION

- **Title:** Teach one concept without durable state
- **Coverage key:** `learning/session/ephemeral-teaching`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/skills/learning-session/**`
- **Preconditions:** Start a fresh disposable project with no `.ai/learning/` directory.
- **Steps:**
  1. Run `/learn session explain why HTTP is stateless with one example`.
  2. Answer one learner-facing question, end the session without asking to save, and inspect hidden state.
- **Expected result:** Mentor teaches answer-first in the conversation language, asks at most two questions before waiting, performs no due-check, and creates no `.ai/learning/` state.
- **Cleanup:** Close the session and remove the disposable project.

### MT-LEARNING-PATH

- **Title:** Create a durable learning path
- **Coverage key:** `learning/path/durable-creation`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-recorder.md`, `domains/learning/commands/learn.md`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/cornell-notes/**`, `domains/learning/skills/feynman-teachback/**`, `domains/learning/skills/language-loop/**`, `domains/learning/skills/bidirectional-translation/**`, `domains/learning/skills/anki-vocab/**`
- **Preconditions:** Start a fresh disposable project and choose a multi-session topic with a concrete mission.
- **Steps:**
  1. Run `/learn path <topic>` and resolve mission, cadence, and scope.
  2. Inspect the topic directory, dashboard, mission, path, resources, and first persisted checkpoint.
- **Expected result:** Mentor loads the durable route, checks due work first, delegates exact writes under `.ai/learning/<topic>/`, and creates a mission-grounded path without touching repository source.
- **Cleanup:** Remove `.ai/learning/` and the disposable project.

### MT-LEARNING-MODULE-DELIVERY

- **Title:** Teach and consolidate a durable module
- **Coverage key:** `learning/module/explanation-progression`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-recorder.md`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/cornell-notes/**`, `domains/learning/skills/feynman-teachback/**`, `domains/learning/skills/spaced-recall/**`
- **Preconditions:** Use a disposable non-language topic `http-cache-validation` with no due work or cards. Its active load-bearing module `Freshness and validation` has lesson/exercise cells `—`. The win is to classify cached responses as reusable, requiring revalidation, or requiring refetch using `Cache-Control: max-age`, `Age`, and `ETag`.
- **Steps:**
  1. Run `/learn path http-cache-validation`; inspect the note and path before answering the Class question.
  2. Reply `Please also explain how the Age header affects freshness.` and inspect the updated note. Restart with `/learn path http-cache-validation`; confirm no exercise is created until you reply `I am ready to practice.`.
  3. Inspect the linked exercise. Ask `Please also explain how a CDN invalidates cached objects across regions.` and choose the recommended defer option. Run `/learn quiz http-cache-validation`, then `/learn path http-cache-validation` to resume Practice.
  4. Complete the exercise until `Result: done`. Submit: `max-age says how long a cached response can be reused. When it expires the cache can use ETag to ask the origin whether it changed.` Inspect the pending artifacts after feedback.
  5. Submit: `A cached response is fresh while its current age, including the Age value, is below max-age, so it can be reused without contacting the origin. Once stale, the cache can revalidate with ETag and reuse the body only if the origin confirms it has not changed.`
  6. Answer the debrief prompts and complete a gap-free Feynman teach-back; inspect the final note, exercise, queue, teach-back, and path.
- **Expected result:**
  - Class teaches the objective, concepts, relationships, non-solving example, and recap; saves the note and exact lesson link; asks one readiness/clarification question; and stops. The exercise remains absent and `—` through clarification and restart, without repeating Class. The note uses the Cornell template's exact pending markers and `Teach-back: required`.
  - `Age` appears in the Map, Notes, 3–7 cues, and eventual exercise. A Notes row connects freshness, current age, and `ETag` revalidation. Only readiness creates the exercise and exact path link. Pending cues never appear in the quiz; the next topic run resumes Practice. CDN invalidation appears only as reinforcement in `path.md`.
  - The incomplete Summary receives correct-first feedback and focused reteaching; Summary/recall markers stay pending and the module 🔄. The corrected learner wording finalizes Summary and matching note/exercise card IDs, but does not close.
  - Only a captured debrief and the recorded gap-free teach-back path allow ✅. Final artifacts exclude deferred concepts; the exercise retains actual outcomes.
- **Essential negative variant:** Copy the state just after `Result: done`, before Summary, with request directive `Cache-Control: max-age=0` absent from the note/exercise and room for one more cue. Ask `Please also explain how request Cache-Control: max-age=0 forces revalidation.`, then restart `/learn path http-cache-validation`. The new concept is logged as separate reinforcement; the current note, cues, exercise, `Result: done`, and Summary requirement stay unchanged. Resume Consolidation, complete steps 5–6, and confirm Close certifies only the practiced scope. On a second copy taken after cue scheduling but before Close, repeat the request; existing card IDs and current scope must remain unchanged.
- **Cleanup:** Remove the disposable topic state and project.

### MT-LEARNING-AMBIGUOUS-ROUTE

- **Title:** Choose a learning route before state access
- **Coverage key:** `learning/routing/ambiguous-topic`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/commands/learn.md`, `domains/learning/skills/learning-session/**`, `domains/learning/skills/learning-loop/**`
- **Preconditions:** Use a disposable project with one existing durable topic and a conversation language other than English.
- **Steps:**
  1. Run `/learn pizza` and inspect visible tool activity before answering.
  2. Choose the one-off option and continue for one teaching exchange.
- **Expected result:** One localized closed choice appears before any skill, date, due-check, or `.ai/learning/` read; the selected route maps internally to `learning-session` and does not inspect durable state.
- **Essential negative variant:** Repeat in a fresh session, choose the durable option, and confirm only `learning-loop` loads before the existing-topic due-check.
- **Cleanup:** Close both sessions and remove the disposable project.

### MT-LEARNING-SUMMARY-LIFECYCLE

- **Title:** Save a one-off summary in background
- **Coverage key:** `learning/summary/background-lifecycle`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-summarizer.md`, `domains/learning/skills/learning-session/**`, `domains/learning/skills/cornell-notes/**`, `domains/learning/skills/cognitive-doc-design/**`
- **Preconditions:** Complete a one-off learning session in a disposable project without existing summary files for that timestamp and topic.
- **Steps:**
  1. Explicitly ask to save the session, then immediately continue with a normal learner question.
  2. After the background notification, send another normal message and inspect `.ai/learning/summaries/`.
- **Expected result:** Mentor launches one fresh background summarizer without waiting; exactly one new localized Cornell summary appears, and the next normal response appends one localized success notice with its path.
- **Essential negative variant:** Force a target collision and confirm the attempt settles without overwrite, retry, foreground fallback, or a standalone notification response.
- **Cleanup:** Remove the generated summary and disposable project.

### MT-LEARNING-DURABLE-REVIEW

- **Title:** Persist review grades without advancing cues
- **Coverage key:** `learning/review/background-persistence`
- **Applies to:** `domains/learning/agents/mentor.md`, `domains/learning/agents/learning-recorder.md`, `domains/learning/skills/learning-loop/**`, `domains/learning/skills/spaced-recall/**`
- **Preconditions:** Use a disposable durable topic containing at least two due review cards and valid queue anchors.
- **Steps:**
  1. Run `/learn review <topic>`, answer the first cue, and choose a grade.
  2. Observe the next cue before persistence settles, then wait for notifications and finish the chunk.
- **Expected result:** Each grade launches a fresh card-scoped background recorder, only learner input advances cues, notifications correlate by task ID, and final artifact/next-due reporting waits until every write settles.
- **Essential negative variant:** Cause one recorder anchor to fail and confirm Mentor performs one fresh-read card-scoped direct fallback without retrying or changing another card.
- **Cleanup:** Remove the disposable topic state and project.

### MT-LEARNING-ENGLISH

- **Title:** Correct English only on request
- **Coverage key:** `learning/english/explicit-coaching`
- **Applies to:** `domains/learning/agents/english-tutor.md`, `domains/learning/commands/english.md`, `domains/learning/skills/english-tutor/**`, `domains/learning/skills/language-loop/**`
- **Preconditions:** Use a disposable project with an existing English durable topic and gaps inbox.
- **Steps:**
  1. Run `/english I have worked here since three years` and inspect the correction.
  2. Accept the offer to record the recurring category and inspect the topic's `gaps.md`.
- **Expected result:** The reply contains the five correction fields, preserves intent, and appends only a pending category with a synthetic pattern; it stores no learner raw text or correction history.
- **Essential negative variant:** Continue an unrelated coding conversation and confirm English Tutor produces no unsolicited correction or state write.
- **Cleanup:** Remove the synthetic gap row and disposable project.

### MT-LEARNING-RECALL

- **Title:** Calculate due cards and Leitner transitions
- **Coverage key:** `learning/recall/leitner-schedule`
- **Applies to:** `domains/learning/plugins/recall-calc.ts`, `domains/learning/skills/spaced-recall/**`, `domains/learning/agents/mentor.md`
- **Preconditions:** Use a disposable durable topic with one overdue box-2 card, one future card, and a known current date.
- **Steps:**
  1. Run `/learn review <topic>` and confirm only the overdue card is offered before new material.
  2. Grade it `Good` and inspect the updated box, Last date, Next date, and next-upcoming report.
- **Expected result:** Due cards are oldest first, the box-2 card moves to box 3 with the configured seven-day interval, the future card remains unchanged, and dates use local ISO format.
- **Essential negative variant:** Add one malformed queue row and confirm it is reported rather than scheduled or silently rewritten.
- **Cleanup:** Remove the disposable topic state and project.
