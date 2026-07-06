---
name: characterization-test-scoping
description: "Trigger: characterization tests, seams, legacy safety plan, test safety planning. Scope legacy safety work around tests, seams, containment, and rollback."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.0.1"
  status: in-progress
---

## Activation Contract
Load this skill when building a legacy safety plan or scoping work around characterization coverage, seams, and the test safety net.

## Hard Rules

- Prefer characterization coverage before structural change.
- Prioritize seam creation only when it reduces containment or rollback risk.
- Keep executable work behavior-preserving; move redesigns and behavior changes to follow-up.
- Require rollback-friendly increments and explicit containment rationale.
- Tests must precede structural refactoring.

## Decision Gates

| Signal | Action |
|---|---|
| No tests or unclear behavior | Put characterization coverage first |
| Hard-to-isolate dependency or long procedure | Recommend seams that improve testability or rollback safety |
| Proposed work changes behavior or public API | Move it to follow-up |

## Execution Steps

1. Identify current behavior that must be locked down first.
2. List the smallest characterization slices that reduce regression risk fastest.
3. Highlight seam opportunities that enable isolation, fakes, or safer rollback.
4. Prefer backlog items that can be validated incrementally.
5. Keep speculative cleanup and redesign out of executable refactor-plan backlog.

## Test Types

- Characterization tests for current behavior.
- Unit tests around isolated rules after seams exist.
- Integration tests for persistence/external boundaries.
- Contract tests for public APIs/events.
- Approval/snapshot tests for broad legacy outputs when appropriate.
- Mutation testing for critical rules using the concrete tool named by the tooling audit and compatibility matrix.
- Property-based tests for invariants and input spaces when useful; name the concrete library when present, otherwise reference the install task.

## Tooling-Aware Planning

When mutation, property, coverage, or assertion tooling is absent, do not silently skip that safety layer. Reference the `tooling_audit.install_tasks` item and explain which test step depends on it. If the matrix has a concrete tool for the detected stack, name that tool; if compatibility is uncertain, mark it as `hypothesis` and require verification before install.

## Output Contract

Return guidance that sharpens characterization coverage, seam selection, containment, rollback, and the test safety net.

## References

- the refactor-planner agent
- the reviewer-output-contract skill
- the tooling-audit skill
- the tooling-compatibility-matrix skill
