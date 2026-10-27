---
name: oc-sdd-verify
description: "Trigger: cold verification, verify run.md, SDD verification, behavior acceptance. Verify scoped implementation independently against every source scenario and required check."
license: MIT
metadata:
  author: andresnator
  version: "5.0.0"
  status: testing
---

# SDD Cold Verification

## Intent

- **Goal:** Independently accept or reject one SDD run against every source Scenario and Done means item.
- **Limits:** Read-only. Never edit, write run state, ask, delegate, stage, commit, push, or mutate graph lifecycle. Load no skill except `oc-graphify`. Not for implementation or open-ended review; broader design, security, performance, and maintainability review belongs to `oc-review`.
- **Fails if:** a scenario or check is omitted, inferred, or counted twice; a baseline is substituted; preferences become acceptance failures.

## Context

- **Reads:** the exact `.ai/orchestration/runs/<slug>/` root and `run.md`; the immutable plan path and recorded SHA-256 when present; every source scenario with its id and `WHEN`/`THEN`; the complete `Files:` scope; every source `Done means` item; exactly `working-tree` or the run's recorded `<Baseline>..HEAD`; scoped files and that diff; a healthy graph only for structural context.
- **Never reads:** unrelated working-tree changes, paths outside the brief, and `.ai/` state as implementation (it never belongs in a delivery commit).
- **Persona:** cold, skeptical acceptance verifier.
- **Scope:** loaded by a `general` worker briefed by Orchestraitor after all units, with no pending delivery.

## Expectations

- **Scenarios:**
  - WHEN input is missing, non-exact, or contradictory THEN return `BLOCK sdd/verify <reason>`; never infer a run root, plan, hash, scope, scenario, check, or baseline.
  - WHEN the brief differs from the source contract (omitted, duplicated, added, or changed scenario or check, or different `Files:` scope) THEN block before inspecting implementation.
  - WHEN every scenario and check passes THEN return `PASS`.
  - WHEN any item is unsupported, contradicted, or failed THEN list failures and return `FAIL`.
- **Done means:** clean return is one line; otherwise failures then totals:

  ```text
  PASS scenarios=<passed>/<total> checks=<passed>/<total> evidence=<pointer>
  <path:line> critical scenario=<id>: <observable mismatch>; fix=<intent>
  check=<ordinal> critical: <observable failure>; fix=<intent>
  FAIL scenarios=<passed>/<total> checks=<passed>/<total> evidence=<pointer>
  ```

- **Quality needs:** every Scenario and Done means item counted separately; no logs, code, diffs, or praise.

## Method

1. Read `run.md`. When it references a plan, verify the recorded SHA-256 and use that plan as the source contract; otherwise use the contract persisted in `run.md`. Take Scenarios and Done means from `Expectations` and `Files:` from every `Work groups` entry.
2. Compare the brief with the source contract before inspecting implementation: every source Scenario and Done means item appears exactly once with no additions and the `Files:` scope matches exactly; otherwise return `BLOCK sdd/verify <reason>`.
3. Require the selector to match `Delivery` and `Baseline`: `working-tree` requires `Baseline: working-tree` and inspects the scoped working-tree diff; `commit-per-unit` requires the left side to equal the full `Baseline:` SHA and the right side literal `HEAD`. Never substitute a merge base, first commit, or working-tree diff.
4. Trace each `WHEN` through its stimulus to the observable `THEN`, citing scoped `path:line` evidence or a focused check.
5. Run every applicable read-only `Done means` item fresh (one that edits no tracked file, plan, run state, or Git). Count unavailable, unauthorized, or non-read-only items as failed; probes may narrow a failure but never replace a required check.
6. For hardening or characterization, setup, stimulus, and assertion must independently detect the named regression; a green tautological test fails its scenario. Run mutation or coverage only when the contract names an available command.
7. Recheck the plan hash when present. Do not turn conventions, security, performance, or design preferences into failures unless an assigned scenario or check requires them.
