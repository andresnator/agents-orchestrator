# Harness Architecture

This repo is a personal AI agent harness: a place to design, store, validate, and reuse daily AI work tools.

## Mental model

| Layer | Role |
|---|---|
| Agents | Who acts |
| Skills | How capabilities are performed |
| Commands | Fast entry points |
| Recipes | Multi-step playbooks |
| Scenarios | Golden-case validation |
| Templates | Consistent creation patterns |

## Design rule

Keep each piece small and composable. If one file tries to be agent, skill, command, and recipe at once, split it.

## Context-saving orchestration

Large workflows should keep the primary agent thin. A primary agent may route phases, track gate state, and pass artifact references, but code-heavy reading and writing should live in bounded subagents.

Use Engram topic keys for durable handoffs when a workflow spans phases. The primary should pass references and compact status envelopes instead of copying raw source, reports, or long subagent outputs into its own context.

The Java refactor anchor-first workflow is the reference example:

```text
primary orchestrator
├─ baseline auditor
├─ test anchorer
├─ Java refactor quality worker
└─ evidence curator
```
