# Programming Practices Skills Scenarios

Golden cases for autonomous programming-practice skills. These scenarios validate that each skill stays self-contained and does not depend on another skill.

## Scenario contract

Each scenario should define:

- input
- expected behavior
- must include
- must not include
- notes for manual review

## Core cases

| Skill | Input | Expected behavior | Must include | Must not include |
|---|---|---|---|---|
| `programming-practices-core` | “Review this code for Clean Code/DRY.” | Classifies readability, duplication, and abstraction risks. | Verdict, issues, tradeoffs, one next step. | References to other skills or language-specific claims without context. |
| `java-clean-code` | Java class with unclear names and nested logic. | Suggests Java naming/structure improvements. | Java-version assumptions and behavior-preservation note. | Architecture rewrite by default. |
| `java-solid-design` | Java service with multiple change reasons. | Maps relevant SOLID pressure and proposes smallest split. | Change reason and rejected overengineering. | Mechanical SOLID lecture. |
| `java-api-design` | Public Java class exposing mutable internals. | Recommends visibility/mutability boundary changes. | Compatibility risk and API contract notes. | Treating all internals as public API. |
| `java-immutability-modeling` | DTO/value object with list field. | Chooses record/class and defensive-copy policy. | Invariants and ownership policy. | Direct mutable exposure. |
| `java-exception-robustness` | Java IO code with manual close and swallowed exception. | Recommends try-with-resources and propagation/translation policy. | Recovery owner and cleanup strategy. | Silent catch. |
| `java-secure-coding` | Java code concatenating SQL from request input. | Flags high-risk injection and recommends parameterized query shape. | Trust boundary and severity. | Security certification claim. |
| `design-patterns-pragmatic` | “Should I use Strategy here?” | Asks/identifies variation force and compares simple branch vs Strategy. | Pattern verdict and tradeoff. | Pattern catalog dump. |

## Cross-skill independence check

For every skill response:

- Must not say “load/call/use another skill.”
- Must not assume another skill exists.
- Must be useful when copied into another runtime alone.
