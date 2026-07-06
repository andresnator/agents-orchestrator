---
name: java-refactor-engram-contract
description: >
  Shared Engram transport contract for the Java anchor-first refactor workflow.
  Trigger: Java refactor agents need namespace validation, topic keys, compact evidence, or shared envelopes.
license: MIT
metadata:
  author: andresnator
  version: "1.0.1"
  status: in-progress
---

## Contract

Use this skill for transport-layer rules only. The Java refactor primary and private subagents own their phase behavior; this contract owns namespace validation, topic keys, read/write discipline, compact evidence rules, and the shared envelope fields.

## Namespace

- `project` and `run_id` are required before Engram access.
- Default topic keys live under `java-refactor-anchor-first/{run-id}/...`.
- If `active_run_topic_prefix` is provided, every read/write key must start with that prefix.
- If `allowed_topic_keys` is provided, every read/write key must exactly match one listed key.
- Block on missing, stale, mismatched, or contradictory prerequisite topics.

## Topic Catalog

| Field | Default topic key |
|---|---|
| `state` | `java-refactor-anchor-first/{run-id}/state` |
| `baseline_audit` | `java-refactor-anchor-first/{run-id}/baseline-audit` |
| `target_scope` | `java-refactor-anchor-first/{run-id}/target-scope` |
| `test_anchor` | `java-refactor-anchor-first/{run-id}/test-anchor` |
| `coverage` | `java-refactor-anchor-first/{run-id}/coverage` |
| `mutation` | `java-refactor-anchor-first/{run-id}/mutation` |
| `slice_plan` | `java-refactor-anchor-first/{run-id}/slice-plan` |
| `review_strategy` | `java-refactor-anchor-first/{run-id}/review-strategy` |
| `tcr_slice` | `java-refactor-anchor-first/{run-id}/tcr-slice-{n}` |
| `evidence_report` | `java-refactor-anchor-first/{run-id}/evidence-report` |

Caller-provided topic keys may override defaults only when they pass namespace validation.

## Read/Write Protocol

- Read with the runtime's memory/topic search operation, then fetch the complete matched observation before treating it as evidence. Search previews are not sufficient evidence.
- Write with the runtime's memory/topic save operation using the exact topic key, project scope, prompt-capture disabled when supported, and structured compact content.
- Read existing `state` before updating it; merge new gate fields without dropping unrelated known state.
- Pass topic keys between agents instead of expanded artifacts.

Example tool mapping: a runtime may expose search as `mem_search`, full observation fetch as `mem_get_observation`, and save as `mem_save`. If those tools are unavailable, use the runtime's equivalent memory or topic operations with the same read-before-write and exact-topic behavior.

## Compact Evidence Rules

Record gate status, short summaries, commands as status-only evidence, blockers, waivers, risks, and one next action. Do not persist raw source, full logs, broad reports, diffs, prompt dumps, or large subagent outputs.

## Shared Envelope Fields

```yaml
status: blocked | ready | complete | failed
project: <Engram project name>
run_id: <stable run id>
engram_topics:
  read: []
  written: []
next_recommended: next_task | human_decision | caller_decides | none
human_question: <one question only, when blocked>
risk: low | medium | high
```
