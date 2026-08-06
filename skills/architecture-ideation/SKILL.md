---
name: architecture-ideation
description: >
  Trigger: architecture refactor ideas, target architecture, modular monolith,
  architecture patterns, restructure the system. Produce an ADR and one ready-for-sdd change.md.
license: MIT
metadata:
  author: andresnator
  version: "2.0.0"
  status: in-progress
---

## Contract

Ideate architecture-level change from verified current state. Class/method refactors go to `/refactor-plan`. Planning may write only the ADR and `change.md`; never edit code, tests, build files, commit, or push.

## Flow

1. Establish current architecture with evidence.
2. Use domain boundaries, not folder layout, to shape modules.
3. Present 2-3 candidates with forces, trade-offs, migration cost, and first reversible step. Recommend one; microservices must justify their operational cost.
4. Converge on target, boundaries, and incremental migration. Never propose a big-bang migration.
5. Write the decision and rejected candidates as an ADR.
6. Write one `Status: ready-for-sdd | Source: architect` `change.md` using `sdd-draft-change`. Group 1 establishes fitness-function guardrails; later work remains incremental and keeps the build green.

Every pattern must solve an evidenced force and pass pragmatic/KISS gates. Every work item ties to an ADR decision or architecture gap and names real files. Return the chosen architecture, ADR path, `change.md` path, first reversible step, and `ejecuta el plan <change>`.
