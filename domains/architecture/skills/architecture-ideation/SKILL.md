---
name: architecture-ideation
description: >
  Trigger: architecture refactor ideas, target architecture, modular monolith,
  architecture patterns, restructure the system. Produce an ADR and one ready-for-sdd change.md.
license: MIT
metadata:
  author: andresnator
  version: "3.0.1"
  status: in-progress
---

## Contract

Design architecture-level change from verified state. Class/method refactors go to `/refactor-plan`. Write only ADR and `change.md`; never edit source, commit, push.

## Flow

1. Establish evidenced current architecture.
2. Shape modules from domain boundaries, not folders.
3. Compare 2-3 candidates by forces, trade-offs, migration cost, first reversible step. Recommend one; microservices must justify operational cost.
4. Converge on boundaries, incremental migration; no big bang.
5. Record decision and rejected candidates in one ADR.
6. Load `sdd-execution-skills`; use `sdd-draft-change` for one `Status: ready-for-sdd | Source: architect` `change.md`. Record selected names per Work group. Group 1 creates fitness-function guardrails; later groups keep build green.

Patterns need evidenced forces plus pragmatic/KISS gates. Each work item maps to ADR decision or architecture gap and names real files. Return chosen architecture, ADR path, `change.md` path, first reversible step, `ejecuta el plan <change>`.
