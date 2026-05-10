# Subagents

Subagents are focused specialists. Each one should do one job well and stay inside strict boundaries.

## Add a subagent when

- The task is repeated often.
- The task benefits from a dedicated role and output contract.
- The task should be isolated from broader orchestration.

## Contract

Every subagent should declare:

- its single responsibility
- permissions and forbidden actions
- related skill, if any
- input shape
- output contract

## Current subagents

| Subagent | Related skill | Purpose |
|---|---|---|
| [`java-refactor-baseline-auditor`](java-refactor-baseline-auditor.md) | None | Audits Java baseline health and coverage/mutation tooling before refactor work starts |
| [`java-refactor-evidence-curator`](java-refactor-evidence-curator.md) | `cognitive-doc-design` | Curates compact Java refactor phase summaries into final evidence without reading raw source or reports |
| [`java-refactor-test-anchorer`](java-refactor-test-anchorer.md) | `java-testing` | Adds or verifies Java test anchors before refactoring and blocks on weak anchors or bugs |
| [`java-refactor-tcr-worker`](java-refactor-tcr-worker.md) | `refactor-java`, `tcr`, conditional `chained-pr` | Executes one small Java refactor slice with TCR discipline and review-size guardrails |
| [`prompt-evaluator`](prompt-evaluator.md) | [`prompt-evaluator`](../../skills/prompt-evaluator/) | Evaluates and rewrites prompt text without executing it |
