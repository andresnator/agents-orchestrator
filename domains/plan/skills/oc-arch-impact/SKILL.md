---
name: oc-arch-impact
description: "Trigger: architecture impact review, layer boundaries. Decide whether legacy risk is local or architectural."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# Architecture Impact Review

## Intent

- **Goal:** Decide whether the target problem is local or architectural, and route it accordingly.
- **Limits:** Keep broad architectural cleanup as follow-up unless it is required for safe characterization. Never refactor across a bounded-context boundary.
- **Fails if:** A boundary claim lacks `file:line` evidence, or a deployable extraction is treated as a local refactor.

## Context

- **Reads:** Imports, build-file dependencies, or a code-graph index (for example, Graphify MCP/CLI) when available.
- **Never reads:** Code outside the review target's dependency neighborhood.
- **Persona:** Architecture reviewer separating local refactor risk from architectural decisions.
- **Scope:** Architecture impact review and layer-boundary questions during refactor or plan work.

## Expectations

- **Scenarios:**
  - WHEN looking for impact THEN check layer violations; domain logic mixed with infrastructure; business logic in controllers, repositories, or DTOs; circular dependencies; coupled modules; god classes and services with too many responsibilities; hidden business rules; boundary-crossing dependencies.
- **Done means:** A local-vs-architectural verdict with coupling, cycles, and boundary crossings verified and cited as `file:line`.
- **Quality needs:** Evidence over intuition; defer irreversible decisions.

## Method

- **Modules first, deployment last**: modularizing inside the current deployable is always the safe local move and belongs to refactor plans. Extracting a deployable (service) is an architectural decision — defer it to its last responsible moment, the point where not deciding would eliminate the alternative, and route it to the architecture domain.
- **Consistency boundary test**: components that must stay transactionally consistent belong in the same module (local concern); where eventual consistency and domain events are acceptable, a module boundary — and possibly an architectural decision — is in play.
- **Language boundary test**: when the same term means different things across the code under review ("policy", "account"), the scope is straddling a bounded-context boundary; escalate the boundary question instead of refactoring across it.
- **Problem nature test**: if nobody can predict whether the restructuring will work (a complex, experiment-first problem rather than a complicated, analyzable one), recommend the Plan discovery route (`operation=deep-plan intent=discovery`), not an executable change.
