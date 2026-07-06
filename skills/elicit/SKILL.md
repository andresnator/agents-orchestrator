---
name: elicit
description: "Question protocol for the Arnes harness: who may ask the user, how to format question-tool prompts, and how blocked subagent questions get relayed. Load before asking gate or clarification questions."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

# Elicit — Question Protocol

For runtime-portable question presentation, prefer the `native-question-ux` skill when an agent environment provides a native question UI.
## Who may ask

Only the sdd-orchestrator (or a primary agent such as `sdd-build`) may use the `question` tool. Subagents have `question: deny` and must never address the user; their only escalation path is returning `status: blocked` with `questions[]` in the result envelope.

## Question format

Every `question` tool call follows this shape:

- **Header** — a short title naming the decision (e.g. "Propose gate — dark-mode-toggle").
- **Question text** — concise; state what is being decided and the minimum context needed to decide it. Summarize artifacts from handoffs; never paste file contents.
- **Options** — 2 to 4 concrete options, each with its tradeoff stated in one line. For gates the canonical set is: approve (continue to the next phase) / adjust (state what to change; the phase re-runs) / abort (stop the change).
- **Custom input** — always allow free-form input in addition to the options; the user may answer something none of the options anticipated.

Ask one question at a time. Do not bundle unrelated decisions into a single call, and do not ask when the answer is already recorded in state.yaml or earlier in the session.

## Subagent relay procedure

When a subagent returns `status: blocked` with `questions[]`:

1. The sdd-orchestrator reads the questions from the envelope.
2. For each question (one `question` tool call at a time), ask the user, converting the subagent's question into the format above; propose concrete options when the subagent supplied candidates.
3. Re-delegate the same phase to the same agent type, with every answer inlined in the task prompt ("Previously blocked on X; the user answered Y").
4. Record nothing in state.yaml for the relay itself; the phase transition is recorded only when the re-delegated phase completes.

A subagent that guesses instead of blocking, or a relay that answers on the user's behalf, is a protocol violation.
