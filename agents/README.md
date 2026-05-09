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
| `prompt-evaluator` | Subagent | Reviews and refines prompt text only |

## Rule

If an agent cannot explain its boundaries in one paragraph, it is not ready to be added.
