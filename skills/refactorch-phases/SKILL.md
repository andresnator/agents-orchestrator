---
name: refactorch-phases
description: >
  Shared RefactorCh phase contract for Engram topic keys, artifact references, and compact result envelopes.
  Trigger: RefactorCh primaries or scouts need shared phase state, topic-key, or result-envelope rules.
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

## Contract

Use this skill as the shared transport and artifact contract for RefactorCh setup agents. It defines how agents name compact Engram artifacts, read/write them, and return caller-readable envelopes. It does not authorize broad source reads, code edits, shell execution, future phase routing, or refactor implementation.

## Common Input

```yaml
project: <required Engram project name>
repo_path: <absolute repository path>
repo_key: <stable repository identifier>
run_id: <stable run id, when run-scoped>
request: <human refactor request or bounded profile task>
constraints: <optional compact scope, safety, or review constraints>
```

## Topic Keys

| Artifact | Topic key |
|---|---|
| Project Profile | `refactorch/project-profile/{repo-key}` |
| Target Brief | `refactorch/{run-id}/target-brief` |
| Run State | `refactorch/{run-id}/state` |

Topic keys must be exact. Reusable project artifacts use the normalized `repo_key`; run-scoped artifacts use the caller-provided or generated `run_id`.

## Engram Protocol

- Read with topic search, then retrieve the full matching observation before relying on it.
- Write with exact `topic_key`, `scope: "project"`, and `capture_prompt: false`.
- Store compact structured content only: gate status, artifact references, blockers, risks, confidence, and next action.
- Do not store raw source, full command logs, diffs, prompt dumps, or broad repository excerpts.
- Read existing run state before updating it; merge known fields instead of overwriting unrelated state.

## Artifact Reference Shape

```yaml
kind: project-profile | target-brief | run-state
project: <Engram project name>
topic_key: <exact topic key>
title: <short title>
```

## Shared Result Envelope

```yaml
status: blocked | complete | failed
project: <Engram project name>
run_id: <stable run id, when run-scoped>
executive_summary: <1-3 sentence action summary>
artifacts:
  - kind: <artifact kind>
    project: <Engram project name>
    topic_key: <exact topic key>
    title: <short title>
next_recommended: human_decision | caller_decides | none
human_question: <one question only, when blocked>
risks:
  - <compact risk, or "None">
skill_resolution: injected | fallback-registry | fallback-path | none
```
