# Architecture Ideation

Loaded by `oc-arch`. Triggers: architecture refactor ideas, target architecture, modular monolith, architecture patterns, restructure the system.

## Intent

- **Goal:** An architecture change grounded in verified state.
- **Limits:** Write only one ADR and one plan; never edit source, commit, or push. Class/method refactors belong to `oc-plan` deep mode. No big-bang migration.
- **Fails if:** A pattern lacks evidenced forces or pragmatic/KISS gates (the `kiss` lens of `oc-refactor` lens mode); microservices lack justified operational cost; a work item maps to neither an ADR decision nor an architecture gap, or names no real files.

## Context

- **Reads:** Evidenced architecture and domain boundaries; `oc-plan`, `oc-routing`.
- **Never reads:** Folder layout as module proof.
- **Scope:** Activation per the triggers above.

## Expectations

- **Done means:** 2-3 candidates compared (forces, trade-offs, migration cost, first reversible step) and one recommended. ADR with decision and rejected candidates; `.ai/architect/plans/<slug>.md` naming skills per group. Return chosen architecture, ADR path, plan path, first reversible step, `ejecuta el plan <path>`.
- **Quality needs:** Group 1 adds fitness functions; later groups keep the build green.

## Method

Evidence, then modules from domain boundaries, then ADR, then plan.
