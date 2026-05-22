---
name: java-refactor-engram-contract
description: "Trigger: Java refactor Engram contract, anchor-first topic keys, java-refactor-anchor-first. Centralize phase handoff and evidence rules."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
---

# Java Refactor Engram Contract

## Activation Contract

Use this skill for `java-refactor-anchor-first` and its workflow-private subagents when they exchange phase evidence through Engram.

Do not use it for generic Java refactoring advice, testing technique selection, or non-Engram workflows.

## Hard Rules

- The skill owns transport rules; agents own phase behavior.
- Require `project` and `run_id` before any Engram access; do not infer them from cwd or session.
- All workflow topics must match `java-refactor-anchor-first/{run_id}/...`, unless an exact caller allowlist explicitly overrides defaults.
- Read Engram artifacts with `mem_search(query: topic_key, project: project, scope: "project")` followed by `mem_get_observation(id)`; search previews are never source material.
- Write generated evidence with `mem_save`, exact `topic_key`, `scope: project`, `capture_prompt: false`, and `**What**/**Why**/**Where**/**Learned**` content.
- Use topic-key upserts for evolving topics (`state`, `coverage`, `mutation`, `review-strategy`, `evidence-report`); use distinct topic keys for per-slice artifacts (`tcr-slice-{n}`).
- Merge evolving `state`; never overwrite it with a partial snapshot.
- Subagents do not talk to each other directly; the primary passes topic keys, not expanded artifacts.
- Keep Engram artifacts compact. Do not save raw source, full tests, build files, coverage/mutation reports, logs, diffs, or broad file excerpts.

## Decision Gates

| Condition | Action |
|---|---|
| Missing `project`, `run_id`, or active-run validation | Block before Engram access. |
| Topic key outside the run namespace or `active_run_topic_prefix`/`allowed_topic_keys` allowlist | Block as stale/mismatched context. |
| Required dependency topic missing or ambiguous | Block; do not proceed from preview text. |
| Updating `state` | Read existing state first, then merge gate status, topic refs, attempts, retries, and human decisions. |

## Execution Steps

1. Resolve topic keys from caller overrides or these defaults: `state` (includes `anchor_attempts[]`), `baseline-audit`, `target-scope`, `test-anchor`, `coverage`, `mutation`, `slice-plan`, `review-strategy`, `tcr-slice-{n}`, `evidence-report` under `java-refactor-anchor-first/{run_id}/`.
2. Accept minimal handoff input:

```yaml
project: <required Engram project name>
run_id: <required stable run id>
phase: baseline | test-anchor | refactor | evidence
read_topics: [<exact dependency topic keys>]
write_topics: [<exact output topic keys>]
active_run_topic_prefix: <optional prefix for output-key validation>
allowed_topic_keys: [<optional exact allowlist for output-key validation>]
phase_context: <optional compact phase-specific payload>
```

3. Read each dependency topic with `mem_search` in project scope, then `mem_get_observation` for full content.
4. Save only compact evidence: gate status, command result summaries, blockers, risks, next action, topic references, command status, waivers, decision sources, and rollback boundary.
5. Return the shared envelope plus phase-specific fields defined in the agent; do not include expanded peer artifacts or raw evidence.

## Output Contract

```yaml
status: blocked | ready | complete | failed
project: <provided Engram project name>
run_id: <stable run id>
engram_topics:
  read: [<exact topic keys read>]
  written: [<exact topic keys written>]
next_recommended: next_task | human_decision | caller_decides | none
human_question: <one question only, when blocked>
risk: low | medium | high
```

Phase-specific fields such as `gate`, `anchor_attempt`, `retry_decision`, `quality_gate`, or final report details remain in each agent's own output contract.

## References

| Phase | Agent | Reads | Writes | Owns |
|---|---|---|---|---|
| Baseline/tooling | `baseline-auditor` | state, target-scope (if provided) | baseline-audit, coverage, mutation | Build/test config audit, tooling readiness |
| Test anchor | `test-anchorer` | state, baseline-audit, target-scope, (coverage, mutation if available) | test-anchor, coverage, mutation | Characterization/unit-test anchors, target-scope coverage, mutation readiness |
| Refactor quality | `tcr-worker` | state, baseline-audit, target-scope, test-anchor, coverage, mutation, slice-plan, review-strategy | tcr-slice-{n} | One behavior-preserving refactor slice with quality gates |
| Evidence | `evidence-curator` | state, baseline-audit, target-scope, test-anchor, coverage, mutation, slice-plan, review-strategy, tcr-slice-{n} | evidence-report | Final gate matrix and traceable reporting |
| Orchestration | `primary` | Subagent envelopes + compact gate evidence (test-anchor, coverage, mutation) | state, target-scope, slice-plan, review-strategy | Gate advancement, retry decisions, human waivers |
