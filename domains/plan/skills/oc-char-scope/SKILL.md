---
name: oc-char-scope
description: "Trigger: characterization tests, seams, high-risk refactor planning, test safety planning. Scope high-risk refactor work around tests, seams, containment, and rollback."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "3.1.0"
  status: testing
---

# Characterization Scope

## Intent

- **Goal:** Scope high-risk refactor work around characterization coverage, seams, containment, and rollback.
- **Limits:**
  - Characterization coverage comes before structural change; tests must precede structural refactoring.
  - Prioritize seam creation only when it reduces containment or rollback risk.
  - Keep executable work behavior-preserving; move redesigns, behavior changes, public API changes, and speculative cleanup to follow-up.
  - Keep characterization tests in a dedicated test class/file per unit (per `oc-conventions`); they are a permanent regression net and never mix with intent-revealing unit tests.
- **Fails if:** A safety layer (mutation, property, coverage, assertion tooling) is silently skipped, increments are not rollback-friendly, or containment rationale is missing.

## Context

- **Reads:** The refactor target, its tests, the `oc-tooling-audit` output (`tooling_audit.install_tasks`), and the `oc-tooling-matrix` skill.
- **Never reads:** Code the change cannot affect.
- **Persona:** Test-safety planner for legacy refactors.
- **Scope:** Load when a refactor plan runs at high/critical risk (the `oc-plan-deep` protected-planning flow) or when scoping work around characterization coverage, seams, and the test safety net.

## Expectations

- **Scenarios:**
  - WHEN there are no tests or behavior is unclear THEN put characterization coverage first.
  - WHEN a dependency is hard to isolate or a procedure is long THEN recommend seams that improve testability or rollback safety.
  - WHEN proposed work changes behavior or public API THEN move it to follow-up.
  - WHEN a bug is in scope THEN the first test reproduces it.
- **Done means:** Guidance that sharpens characterization coverage, seam selection, containment, rollback, and the test safety net: behavior to lock down first, the smallest characterization slices that reduce regression risk fastest, seam opportunities enabling isolation, fakes, or safer rollback, and incrementally verifiable backlog items.
- **Quality needs:** A few tests that would catch a real regression beat many trivial ones.

## Method

### Effect reasoning

Choose what to characterize by tracing effects forward from each change point until they become observable, along the three propagation paths: return values, mutation of reachable state, and statics/globals or external writes. The methods where those effects surface are the test points; code the change cannot affect needs no characterization. Characterize only the zone the plan will touch (targeted characterization), never the whole unit by default.

### Pinch points

When a change spans a cluster of coupled classes, find the narrowest downstream point where their effects converge and anchor a temporary integration-level characterization test there ("test one level back"). Pinch-point tests are scaffolding: they trade defect localization and speed for coverage, so the plan must schedule their removal or demotion once unit-level tests exist at the new seams.

### Test priority and types

Boundary conditions and the happy path rank highest; expected error paths rank medium; code that rarely changes ranks lowest.

- Characterization tests for current behavior.
- Unit tests around isolated rules after seams exist.
- Integration tests for persistence/external boundaries.
- Contract tests for public APIs/events.
- Approval/snapshot tests for broad legacy outputs when appropriate; prefer whole-object asserts (recursive comparison, approval, snapshot) over field-by-field cascades for complex outputs.
- Mutation testing for critical rules using the concrete tool named by the tooling audit and compatibility matrix.
- Property-based tests for invariants and input spaces when useful; name the concrete library when present, otherwise reference the install task.

### Tooling-aware planning

When tooling is absent, reference the `tooling_audit.install_tasks` item and explain which test step depends on it. If the matrix has a concrete tool for the detected stack, name that tool; if compatibility is uncertain, mark it as `hypothesis` and require verification before install.
