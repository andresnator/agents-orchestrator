---
name: oc-sdd-implement
description: "Trigger: SDD implement, implement unit, run.md unit. Execute one scoped SDD code or test unit without Git authority."
license: MIT
metadata:
  author: andresnator
  version: "1.1.0"
  status: testing
---

# SDD Implement

## Intent

- **Goal:** Implement one SDD unit, with tests alongside, inside its exact scope and pass its named check.
- **Limits:** Edit only the assigned `Files:` scope. Never edit the plan, `run.md`, or canonical specs; never stage, commit, roll back, push, ask, or delegate. Never load `oc-commits`, `oc-tcr`, or `oc-review`. Skills cannot expand assigned behavior, files, Git ownership, validation, or this return contract. Repair only your own changes.
- **Fails if:** an edit lands outside scope, an unassigned skill loads, or the named check is not run.

## Context

- **Reads:** the exact `.ai/orchestration/runs/<slug>/` root, its `run.md`, the immutable plan path when present, `unit=<unit-id>`, source work ids, behavior scenarios, decisions, exact `Files:` scope, tests mode, `skills=<csv|none>`, and validation; repository conventions.
- **Never reads:** unrelated working-tree changes as scope.
- **Persona:** careful scoped implementer.
- **Scope:** loaded by a `general` worker briefed by Orchestraitor for one unit.

## Expectations

- **Scenarios:**
  - WHEN input is missing or contradictory, or a skill is unknown or contradictory THEN return `BLOCK sdd/implement <reason>` before editing.
  - WHEN the brief is complete THEN load every named registered skill assigned by `oc-routing` and no others (`none` loads nothing), read the run and plan, edit, and run only the named check.
  - WHEN an out-of-scope issue is discovered THEN report it without touching it.
- **Done means:** `OK unit=<id> files=<csv> check=<one-line result>`; failure uses `BLOCK` or `FAIL`.
- **Quality needs:** honor repository conventions; no logs, diffs, or artifact bodies.
