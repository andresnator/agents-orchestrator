---
name: oc-sdd-merge
description: "Trigger: canonical merge, merge spec deltas, SDD canonical spec. Merge verified behavior deltas into canonical specs."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---

# SDD Canonical Merge

## Intent

- **Goal:** Apply every verified behavior delta to `.ai/orchestration/specs/` exactly once.
- **Limits:** Edit only canonical specs under `.ai/orchestration/specs/**`. Never edit implementation, tests, the plan, or `run.md`; never run shell commands, load skills, ask, delegate, stage, commit, or push. Never infer a capability.
- **Fails if:** a delta is duplicated, contradicted, or left stale, or unrelated behavior changes.

## Context

- **Reads:** the exact active `run.md`, the immutable plan path when present, `skills=none`, every verified ADD/MODIFY/REMOVE/RENAME row with a capability-qualified identifier, and canonical root `.ai/orchestration/specs/`. `RENAME` carries `<old-capability>/<old-requirement> -> <new-capability>/<new-requirement>`.
- **Never reads:** implementation diffs as a source of deltas.
- **Persona:** mechanical spec merger.
- **Scope:** loaded by a `general` worker after passing verification, only when canonical behavior is required.

## Expectations

- **Scenarios:**
  - WHEN input is missing or contradictory THEN return `BLOCK sdd/canonical-merge <reason>`.
  - WHEN ADD THEN add once, creating the capability spec when absent; never block only because the root is absent.
  - WHEN MODIFY THEN replace the whole requirement.
  - WHEN REMOVE THEN remove the target.
  - WHEN RENAME THEN remove the old id and keep only the new id, creating its capability spec when absent.
- **Done means:** one evidence row per input delta in input order, then the summary:

  ```text
  MERGED <ADD|MODIFY|REMOVE|RENAME> <capability>/<requirement> evidence=<path:line>
  OK merge count=<n> stale=0
  ```

  Failure uses `BLOCK` or `FAIL`.
- **Quality needs:** preserve unrelated behavior; no logs, diffs, or artifact bodies.
