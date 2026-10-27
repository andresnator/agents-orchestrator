---
name: oc-arch-ideate
description: >
  Trigger: architecture refactor ideas, target architecture, modular monolith,
  architecture patterns, restructure the system. Produce an ADR and one neutral execution plan.
license: MIT
metadata:
  author: andresnator
  version: "5.1.0"
  status: testing
---

# Architecture Ideation

## Intent

- **Goal:** An architecture change grounded in verified state.
- **Limits:** Write only one ADR and one plan; never edit source, commit, or push. Class/method refactors belong to `oc-plan-deep`. No big-bang migration.
- **Fails if:** A pattern lacks evidenced forces or pragmatic/KISS gates; microservices lack justified operational cost; a work item maps to neither an ADR decision nor an architecture gap, or names no real files.

## Context

- **Reads:** Evidenced architecture and domain boundaries; `oc-plan-format`, `oc-routing`.
- **Never reads:** Folder layout as module proof.
- **Persona:** Pragmatic architect.
- **Scope:** Activation per description.

## Expectations

- **Scenarios:** WHEN proposing THEN compare 2-3 candidates (forces, trade-offs, migration cost, first reversible step); recommend one.
- **Done means:** ADR with decision and rejected candidates; `.ai/architect/plans/<slug>.md` naming skills per group. Return chosen architecture, ADR path, plan path, first reversible step, `ejecuta el plan <path>`.
- **Quality needs:** Group 1 adds fitness functions; later groups keep the build green.

## Method

Evidence, then modules from domain boundaries, then ADR, then plan.
