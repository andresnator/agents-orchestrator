# Agents

Agents are executable personas with boundaries, permissions, and output contracts.

## Quick path

1. Put coordinating agents in [`primary/`](primary/).
2. Put focused specialists in [`subagents/`](subagents/).
3. Link any reusable method to a skill in [`../skills/`](../skills/).

## Agent types

| Type | Use when | Directory |
|---|---|---|
| Primary agent | It coordinates multiple steps, tools, or subagents | `agents/primary/` |
| Subagent | It performs one bounded specialist task | `agents/subagents/` |

## Current agents

| Agent | Type | Purpose |
|---|---|---|
| [`java-refactor-anchor-first`](primary/java-refactor-anchor-first.md) | Primary | Dumb orchestrator for safe Java refactors using Engram topic keys, strict gates, and bounded phase subagents |
| [`java-refactor-baseline-auditor`](subagents/java-refactor-baseline-auditor.md) | Subagent | Audits Java baseline health and coverage/mutation tooling before refactor work starts |
| [`java-refactor-evidence-curator`](subagents/java-refactor-evidence-curator.md) | Subagent | Curates compact Java refactor phase evidence into final reporting |
| [`java-refactor-test-anchorer`](subagents/java-refactor-test-anchorer.md) | Subagent | Adds or verifies Java characterization and unit-test anchors before refactoring |
| [`java-refactor-tcr-worker`](subagents/java-refactor-tcr-worker.md) | Subagent | Executes one small Java refactor slice with TCR and review-size guardrails |
| `prompt-evaluator` | Subagent | Reviews and refines prompt text only |

## Rule

If an agent cannot explain its boundaries in one paragraph, it is not ready to be added.
