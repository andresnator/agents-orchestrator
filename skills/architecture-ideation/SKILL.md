---
name: architecture-ideation
description: >
  Trigger: architecture refactor ideas, target architecture, modular monolith,
  architecture patterns, restructure the system. Question-driven architecture
  refactor ideation producing an ADR plus a ready-for-sdd OpenSpec bundle.
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

# Architecture Ideation

## Activation Contract

Use this skill to ideate an architecture-level refactor with the user: target styles (e.g. modular monolith, hexagonal), module boundaries, and architecture-scoped design patterns.

Do not use it for class/method-level refactors — route those to `/refactor-plan`.

## Hard Rules

- Question-driven: run the interview through `native-question-ux`, one focused round at a time, grounded in the verified current state (from `architecture-state`).
- Always present 2-3 candidate target architectures with explicit trade-offs and a recommendation — never a single take-it-or-leave-it answer. For monoliths, modular monolith is the default first candidate; microservices must earn their operational cost.
- Every proposed pattern passes `design-patterns-pragmatic` and `kiss-yagni` gates: it must resolve a named force in evidence, not decorate the design.
- Ideation is plan-only: no code edits.

## Ideation Flow

1. **Current state in**: start from the `architecture-state` output (style, modules, gaps). Missing state = establish it first.
2. **Bounded contexts**: slice the domain with `domain-modeling`; candidate module boundaries come from the domain, not the folder layout.
3. **Candidates**: draft 2-3 target architectures. For each: the shape, what it fixes (tied to gap IDs), migration cost, and the first reversible step.
4. **Question rounds**: converge with the user on candidate, boundaries, and migration appetite (big-bang is never offered; strangler-fig/incremental only).
5. **Decision**: record the chosen target and the rejected candidates with reasons.

## Outputs

Two artifacts, produced in this order:

1. **ADR** via the `adr` skill, saved under `<docfolder>/architecture/adr/` — the decision, alternatives, and consequences.
2. **Ready-for-sdd bundle** per `docs/plan-handoff.md`, composed with the `sdd-draft-*` templates: proposal, design (target architecture + migration order rationale), delta specs, and tasks. `tasks.md` requirements:
   - First group establishes guardrails: the fitness functions proposed by `architecture-state` for the decided boundaries (see its `references/fitness-functions.md`).
   - Migration tasks are incremental and each leaves the build green.
   - Test tasks honor the `code-conventions` contract.

## Verification

- 2-3 candidates were presented with trade-offs; the rejected ones are recorded in the ADR.
- Every task ties to a gap ID or a decision in the ADR.
- Bundle passes the plan-handoff self-check: marker first line, four artifacts, `- [ ] X.Y` tasks naming real files, forecast guard lines, no Mode/TDD/Judgment line.

## Output Contract

Return: chosen target architecture, ADR path, bundle path, first reversible step, and the adoption hint ("ejecuta el plan <change>").
