# Java Refactor Quality Gate

Before declaring a Java refactor complete, review the result against this gate:

- **Behavior preservation**: no bug fix or externally observable behavior change is mixed into the refactor.
- **Readability and naming**: names explain intent; extracted methods/classes reduce cognitive load rather than hiding simple code.
- **Cohesion**: moved or extracted code belongs with the data and behavior that change together.
- **SOLID restraint**: apply SOLID principles only where real change pressure exists; avoid mechanical abstractions.
- **Pragmatic patterns**: choose the simplest design that handles known variation; do not introduce a pattern by default.
- **API compatibility**: public signatures, visibility, mutability, serialization, and caller contracts are preserved unless the task explicitly allows an API change.
- **Exception robustness**: do not swallow exceptions, broaden them unnecessarily, or use exceptions as normal control flow.
- **Immutability/modeling**: prefer clear ownership, defensive copies, records/value objects, or invariants when they simplify reasoning.
- **Useful-only JavaDoc**: add or keep JavaDoc only when it explains non-obvious intent, contracts, invariants, edge cases, threading/lifecycle expectations, or public API obligations. Remove or avoid JavaDoc that merely restates the method name, parameters, or implementation.
