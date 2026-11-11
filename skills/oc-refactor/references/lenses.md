# Lens Catalog

Lenses adapted from `gentle-ai/plan-refactor` (Apache-2.0) by andresnator.

Load only the sections whose ids appear in the input `lenses=<csv>`. Each lens recommends the smallest safe behavior-preserving refactor per material finding.

## Shared rules (every lens)

- Preserve observable behavior; label functional changes as follow-up.
- Require evidence for every recommendation, or mark it as a hypothesis.
- WHEN concrete evidence exists THEN report `file:line` evidence, symbol, benefit, validation, and rollback (in the caller's output contract, which wins over this field list).
- WHEN evidence is incomplete THEN mark it hypothesis with lower confidence.
- WHEN cosmetic or speculative THEN omit unless maintainability benefit is clear.
- One finding per material issue; `no_findings` when nothing is material.

## srp

- **Activation:** single responsibility, SRP, reasons to change.
- **Rules:**
  - Identify separate business rules, orchestration, IO, mapping, validation, and formatting responsibilities.
  - Recommend Extract Class or Move Method only when cohesion improves.
  - Avoid splitting code merely because it is long.

## dry

- **Activation:** DRY, duplicated business knowledge, duplication.
- **Rules:**
  - Prioritize duplicated rules, validations, formulas, permissions, mappings, or invariants.
  - Do not merge coincidentally similar code with different meanings.
  - State the business knowledge that would become single-sourced.

## kiss

- **Activation:** KISS, YAGNI, overengineering, speculative abstraction.
- **Rules:**
  - Prefer explicit code until variation is proven.
  - Reject abstractions for hypothetical future cases.
  - Recommend deletion of unused speculative structure only when safe and validated.
- **Gate:** a finding without `file:line` evidence must be marked hypothesis. Note validation and rollback implications only where material; the caller decides where they land.

## ocp

- **Activation:** open closed principle, OCP, strategy, policy, polymorphism.
- **Rules:**
  - Look for repeated conditionals by type, state, operation, or strategy.
  - Suggest strategy, policy, or polymorphism only when new variants are likely or already present.
  - Block pattern use when a simple conditional is clearer.

## dip

- **Activation:** dependency inversion, DIP, ports, interfaces, adapters.
- **Rules:**
  - Flag direct dependencies on frameworks, gateways, clients, persistence, or external systems when they hurt testing or coupling.
  - Introduce ports/interfaces only for real variation, test seams, or architectural boundaries.
  - Do not wrap stable internal classes by default.

## coupling

- **Activation:** cohesion, coupling, circular dependency, layer mixing.
- **Rules:**
  - Flag classes whose methods use disjoint state subsets.
  - Flag layer violations, circular dependencies, high fan-out, and excessive collaborator knowledge.
  - Prefer Move Method, Extract Class, Facade, or Port/Adapter only with concrete coupling evidence.

## big-o

- **Activation:** complexity, Big O, cyclomatic, nested loops, queries in loops.
- **Rules:**
  - Flag high cyclomatic complexity, nested branches, loops, repeated scans, O(n²), and queries in loops.
  - Discuss Big O only when collections, algorithms, or repeated queries exist.
  - Avoid micro-optimizations without evidence; prioritize readability unless performance risk is real.

## god-object

- **Activation:** God Object, Large Class, too many collaborators.
- **Rules:**
  - Look for many unrelated methods, many collaborators, broad state ownership, and mixed domain concepts.
  - Recommend incremental extraction by cohesive responsibility.
- **Gate:** require characterization tests before risky legacy extractions.

## spaghetti

- **Activation:** spaghetti code, temporal coupling, hidden side effects, small functions, long method, extract method.
- **Rules:**
  - Flag tangled branches, implicit execution order, hidden side effects, and temporal coupling.
  - Flag methods that mix abstraction levels or interleave distinct phases.
  - Recommend guard clauses, Split Phase, Extract Method, or explicit state transitions: prefer Extract Method when a block has a meaningful domain name; prefer Split Phase when parsing, validation, calculation, or persistence are interleaved.
- **Gate:** never recommend a Big Bang rewrite.

## logging

- **Activation:** logging, observability, metrics, traces.
- **Rules:**
  - Flag noisy, duplicated, wrong-level, context-free, sensitive, or repeated exception logs.
  - Recommend logs only at useful boundaries, decisions, and failure points.
  - Use observability to validate before/after behavior without changing business behavior.

## preconditions

- **Activation:** input validation, preconditions, boundary validation.
- **Rules:**
  - Validate at system and module boundaries.
  - Flag implicit assumptions that can fail at runtime.
  - Centralize duplicated validation only when it represents one business rule.
  - Do not scatter defensive checks inside pure internals without need.
