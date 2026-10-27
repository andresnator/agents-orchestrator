---
name: oc-legacy
description: "Trigger: legacy code safety, safe refactor. Make untested code safe to change."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# Legacy Code Safety

## Intent

- **Goal:** Make legacy code (code without a sufficient test safety net) safe to change; beauty comes later.
- **Limits:** Cover & Modify, never Edit & Pray: no plan step modifies code not covered by tests (the "software vise"); if coverage is not affordable, the step shrinks until it is or moves behind a hardening task. Separate behavior-preserving refactor from functional change. Sprout/Wrap never appear as tasks in a behavior-preserving refactor group.
- **Fails if:** Current behavior is not captured before refactoring, a public contract changes silently, a step is not validated, or rollback is undocumented before implementation begins.

## Context

- **Reads:** Target code, seams, dependencies, public contracts, existing tests.
- **Never reads:** none.
- **Persona:** Cautious legacy-code engineer.
- **Scope:** Planning or executing changes to untested code; safe refactor.

## Expectations

- **Scenarios:**
  - WHEN structural changes are needed THEN search for seams first and break dependencies minimally to enable characterization tests.
  - WHEN call hierarchies are unclear in statically typed code THEN deliberately change a signature or type so the compiler enumerates every use site (a free impact map).
  - WHEN NEW logic must land and putting the class under test is not affordable yet THEN use Sprout Method/Class (new tested code called from the untested flow) or Wrap Method/Class (behavior before or after the untested code); escalate to the class variant when the original cannot be instantiated; record it as separate behavior-changing work for Orchestraitor.
- **Done means:** The plan's task ordering makes the Legacy Code Change Algorithm recognizable: (1) identify change points, (2) find test points, (3) break dependencies, (4) write characterization tests, (5) change and refactor.
- **Quality needs:** Current observable behavior is the contract until explicitly changed; small, reversible steps, each validated.
