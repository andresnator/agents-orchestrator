---
name: oc-legacy
description: "Trigger: legacy code safety, safe refactor, behavior characterization, observable behavior, characterization tests, seams, high-risk refactor planning, test safety planning. Make untested code safe to change: change algorithm, characterization, and test-safety scope."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "3.0.0"
  status: testing
---

# Legacy Code Safety

## Intent

- **Goal:** Make legacy code (code without a sufficient test safety net) safe to change; beauty comes later. Record what the code does today, not what it should do, and scope high-risk work around characterization coverage, seams, containment, and rollback.
- **Limits:**
  - Cover & Modify, never Edit & Pray: no plan step modifies code not covered by tests (the "software vise"); if coverage is not affordable, the step shrinks until it is or moves behind a hardening task.
  - Separate behavior-preserving refactor from functional change. Sprout/Wrap never appear as tasks in a behavior-preserving refactor group.
  - Characterize only the zone the plan touches. Never fix a found bug in the same step.
  - Characterization coverage comes before structural change; prioritize seam creation only when it reduces containment or rollback risk; move redesigns, behavior changes, public API changes, and speculative cleanup to follow-up.
  - Keep characterization tests in a dedicated test class/file per unit (per `oc-conventions`); they are a permanent regression net and never mix with intent-revealing unit tests.
- **Fails if:** Current behavior is not captured before refactoring; a claim lacks code evidence and is not marked hypothesis; a test asserts desired behavior; a public contract changes silently; a step is not validated; rollback is undocumented before implementation begins; a safety layer (mutation, property, coverage, assertion tooling) is silently skipped; increments are not rollback-friendly; or containment rationale is missing.

## Context

- **Reads:** Target code, seams, dependencies, public contracts, existing tests; observable signals (returns, exceptions/error codes, side effects/state, persistence reads/writes, events, logs, external calls, edge branches, implicit rules); at high/critical risk, the `oc-tooling-audit` output (`tooling_audit.install_tasks`) and its compatibility matrix.
- **Never reads:** Desired behavior as evidence; code the change cannot affect.
- **Persona:** Cautious legacy-code engineer and neutral observer of current behavior.
- **Scope:** Planning or executing changes to untested code; safe refactor; characterizing legacy code before changing it; high/critical-risk refactor plans (the `oc-plan-deep` protected-planning flow).

## Expectations

- **Scenarios:**
  - WHEN structural changes are needed THEN search for seams first and break dependencies minimally to enable characterization tests.
  - WHEN call hierarchies are unclear in statically typed code THEN deliberately change a signature or type so the compiler enumerates every use site (a free impact map).
  - WHEN NEW logic must land and putting the class under test is not affordable yet THEN use Sprout Method/Class (new tested code called from the untested flow) or Wrap Method/Class (behavior before or after the untested code); escalate to the class variant when the original cannot be instantiated; record it as separate behavior-changing work for Orchestraitor.
  - WHEN characterizing a value THEN write a failing assertion, run it, and anchor the actual value from the failure message.
  - WHEN a bug appears THEN anchor today's wrong output, record the bug, finish the net, and schedule the fix as a follow-up behavior change.
  - WHEN there are no tests or behavior is unclear THEN put characterization coverage first.
  - WHEN a dependency is hard to isolate or a procedure is long THEN recommend seams that improve testability or rollback safety.
  - WHEN proposed work changes behavior or public API THEN move it to follow-up.
  - WHEN a bug is in scope THEN the first test reproduces it.
- **Done means:** The plan's task ordering makes the Legacy Code Change Algorithm recognizable: (1) identify change points, (2) find test points, (3) break dependencies, (4) write characterization tests, (5) change and refactor. Touched-zone behavior is anchored by tests, evidence, or hypothesis. High-risk guidance names the behavior to lock down first, the smallest characterization slices that reduce regression risk fastest, seam opportunities enabling isolation, fakes, or safer rollback, and incrementally verifiable backlog items.
- **Quality needs:** Current observable behavior is the contract until explicitly changed; small, reversible steps, each validated; a few tests that would catch a real regression beat many trivial ones.

## Method

### Change algorithm

Follow the five steps in `Done means`. Seams first, minimal dependency breaking, Sprout/Wrap only as separate behavior-changing work.

### Characterization

Anchor actual values from failing assertions; never encode desired behavior. Record bugs found and schedule their fixes as follow-up behavior changes.

### Scope and test priority

#### Effect reasoning

Choose what to characterize by tracing effects forward from each change point until they become observable, along the three propagation paths: return values, mutation of reachable state, and statics/globals or external writes. The methods where those effects surface are the test points; code the change cannot affect needs no characterization. Characterize only the zone the plan will touch (targeted characterization), never the whole unit by default.

#### Pinch points

When a change spans a cluster of coupled classes, find the narrowest downstream point where their effects converge and anchor a temporary integration-level characterization test there ("test one level back"). Pinch-point tests are scaffolding: they trade defect localization and speed for coverage, so the plan must schedule their removal or demotion once unit-level tests exist at the new seams.

#### Test priority and types

Boundary conditions and the happy path rank highest; expected error paths rank medium; code that rarely changes ranks lowest.

- Characterization tests for current behavior.
- Unit tests around isolated rules after seams exist.
- Integration tests for persistence/external boundaries.
- Contract tests for public APIs/events.
- Approval/snapshot tests for broad legacy outputs when appropriate; prefer whole-object asserts (recursive comparison, approval, snapshot) over field-by-field cascades for complex outputs.
- Mutation testing for critical rules using the concrete tool named by the tooling audit and its compatibility matrix.
- Property-based tests for invariants and input spaces when useful; name the concrete library when present, otherwise reference the install task.

#### Tooling-aware planning

When tooling is absent, reference the `tooling_audit.install_tasks` item and explain which test step depends on it. If the `oc-tooling-audit` matrix has a concrete tool for the detected stack, name that tool; if compatibility is uncertain, mark it as `hypothesis` and require verification before install.
