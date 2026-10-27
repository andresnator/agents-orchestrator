---
name: oc-java-test
description: "Trigger: Java tests, JUnit, Mockito, AssertJ, Java legacy tests, Java characterization tests, Java seams. Generate and retrofit Java tests safely; planning the scope and protection of a legacy change belongs to oc-legacy."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "4.1.1"
---

# Java Testing Skill

## Intent

- **Goal:** Generate or retrofit Java tests safely: detect the local stack, choose the smallest safe technique, create or propose tests, and explain seam/dependency tradeoffs.
- **Limits:**
  - The caller owns product behavior, dependency approval, and running project commands when validation exists.
  - Preserve the project test stack. Do not add or upgrade JUnit, Mockito, AssertJ, PowerMock, or ApprovalTests unless the existing stack cannot support the required test and the tradeoff is stated.
  - Do not modify production behavior before a safety test exists for legacy code (Cover → Modify → Refactor).
- **Fails if:** Generated examples are incomplete, do not compile, or ignore local package, naming, and style conventions; collaborators are over-verified or over-mocked; a dependency-breaking seam is not named as Sensing or Separation.

## Context

- **Reads:** Java level, build tool, JUnit/Mockito versions, assertion style, and dependency management (detected independently); existing test naming, package layout, assertions, fixtures, and mocking style; class under test, observable behavior, collaborators, and failure/edge cases; for legacy code, change point, test point, hidden dependencies, and seam purpose. Inspect or ask before writing tests.
- **Never reads:** The full reference catalog by default; load progressively.
- **Persona:** Java test engineer following *Working Effectively with Legacy Code*.
- **Scope:** Java unit tests, JUnit/Mockito/AssertJ examples, characterization and Golden Master tests, seams, dependency-breaking. Not for non-Java projects, generic strategy, frontend/E2E, performance, security, or refactoring without a testing objective.

## Expectations

- **Scenarios:**
  - WHEN a clean, injectable class needs tests THEN write simple unit tests: pure unit first, Mockito only across real boundaries, Spring/context tests only when framework behavior is the subject; test behavior.
  - WHEN existing code has no tests but is easy to instantiate THEN characterize first, then improve.
  - WHEN legacy code is hard to test THEN follow the legacy flow and the decision table below.
- **Done means:** Return the chosen route and references used; detected Java test stack and conventions; files changed or proposed; tests added with behaviors and edge cases covered; dependency/seam tradeoffs, including Sensing vs Separation when applicable; validation performed or recommended command.
- **Quality needs:** Follow `oc-conventions` as the general contract; the Java specifics are below.

## Method

### Decision table

| Situation | Route |
|---|---|
| Clean, injectable class needs tests | Simple unit tests below. |
| Existing code has no tests but is easy to instantiate | Characterization tests first, then improve. |
| Constructor/static/global/framework dependencies block testing | `references/quick-decision-flow.md` and dependency-breaking references. |
| Dependency setup is missing or unclear | `references/dependency-setup.md` before adding imports or build snippets. |
| Golden Master or ApprovalTests is needed | `references/characterization-tests.md`, then `references/approvaltests-setup.md` before creating baselines. |
| Static/final mocking or captors are needed | `references/mockito-patterns.md` before choosing Mockito features. |
| Large legacy cluster or unclear effect propagation | `references/advanced-patterns.md` for pinch points, effect sketches, and hot spots. |

### Simple unit tests

- Place tests under `src/test/java/` mirroring the source package.
- Name classes `{ClassName}Test` and methods `should{Behavior}When{Condition}` unless the project uses another convention.
- Split every non-trivial test body with `// Given`, `// When`, `// Then`; avoid other comments/Javadocs.
- For JUnit 5 + Mockito, use `@ExtendWith(MockitoExtension.class)`, `@Mock`, and `@InjectMocks` only when constructor setup adds noise.
- Prefer AssertJ `assertThat()` / `assertThatThrownBy()` when present; `WithAssertions` is acceptable if it matches project style.
- For complex objects/DTOs, assert the whole object with `usingRecursiveComparison()` or ApprovalTests instead of field-by-field cascades.
- Use parameterized tests for meaningful input matrices, and `ArgumentCaptor` only when the passed object is the behavior under test.

### Legacy flow

1. Identify change points.
2. Find test points with effect sketches.
3. Break dependencies only where needed for Sensing or Separation.
4. Write characterization tests documenting current behavior in a dedicated permanent `{ClassName}CharacterizationTest` class, separate from intent-revealing unit tests.
5. Modify and refactor behind the safety net.

### Resources

Use `references/` for when and why to apply a technique; use `assets/examples/` only as copyable starting points, adapting package names, dependencies, naming, and conventions.

| Resource | Load when |
|---|---|
| `references/dependency-setup.md` | Dependency setup or version compatibility is unclear. |
| `references/mockito-patterns.md` | Mockito annotations, captors, verification, static/final mocking, or interaction boundaries are needed. |
| `references/characterization-tests.md` | Existing behavior must be locked before modification, including Golden Master tests. |
| `references/approvaltests-setup.md` | ApprovalTests setup or baseline workflow is needed. |
| `references/seam-model.md` | Seams and enabling points must be classified before breaking dependencies. |
| `references/dependency-breaking.md` | Constructor, interface, override, parameter adaptation, or global-reference techniques are needed. |
| `references/quick-decision-flow.md` | The code is hard to test and you need a first route. |
| `references/sensing-separation.md` | Decide whether the seam observes behavior or separates dependencies. |
| `references/pass-null-subclass-override.md` | Pass Null, null object, subclass-and-override, or extract-and-override is the likely seam. |
| `references/sprout-wrap-techniques.md` | Risky legacy additions call for Sprout Method/Class or Wrap Method/Class. |
| `references/method-object-skin-wrap.md` | Long methods, API skin wrapping, or method-object extraction is needed. |
| `references/tdd-legacy.md` | The task asks for TDD while modifying existing legacy Java. |
| `references/advanced-patterns.md` | Pinch points, effect sketches, God classes, hot spots, or scratch refactoring are needed. |
| `assets/examples/ExampleServiceTest.java` | Service test template with JUnit 5, Mockito, and AssertJ. |
| `assets/examples/ExampleConfigTest.java` | Configuration/value-object style example. |
| `assets/examples/ExampleHandlerTest.java` | Handler/controller collaborator example. |
| `assets/examples/ExampleCacheTest.java` | Cache/stateful behavior example. |
| `assets/examples/ExampleListenerTest.java` | Listener/event-driven example. |
