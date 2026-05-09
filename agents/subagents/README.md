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
| [`prompt-evaluator`](prompt-evaluator.md) | [`prompt-evaluator`](../../skills/prompt-evaluator/) | Evaluates and rewrites prompt text without executing it |
