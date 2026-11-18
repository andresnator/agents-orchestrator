---
name: oc-conventions
description: "Andres's code and test conventions, with Java rules. Trigger: writing production code or tests, test naming, constants, DTOs, JUnit, Mockito, ApprovalTests."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "3.2.3"
---

# Code Conventions

## Intent

- **Goal:** Apply Andres's code and test conventions.
- **Limits:** Defaults for new code and repos without an established convention; when the target repo consistently follows another convention, the repo wins. Never churn diffs only to apply a soft preference.
- **Fails if:** Tests assert tautologically against their own constants; characterization tests mix with intent-revealing unit tests.

## Context

- **Reads:** The code under change, the repo's existing conventions.
- **Scope:** Load when writing production code or tests. Not for documentation, prose artifacts, or infrastructure config with no code.

## Expectations

- **Scenarios:**
  - WHEN writing a plan or design document THEN record the detected language and tool versions with evidence (e.g. `java.version` in `pom.xml`, `typescript` in `package.json`). The implementer can then fetch version-correct documentation.
- **Done means:** Code and tests follow the Method rules or the repo's winning convention; any deviation is named in the plan, design, or summary.
- **Quality needs:** Single Responsibility and Open-Closed carry weight. Introduce interfaces or dependency inversion only for real variation, test seams, or architectural boundaries, never as SOLID dogma (see `oc-refactor` lens mode, `dip` lens).

## Method

### Production code

- **No magic literals:** extract hardcoded numbers and strings into named constants placed where tests can reuse them. Tests reuse them for fixtures and setup; when the constant IS the behavior under test, assert against the expected literal value.
- **Top-level DTOs:** DTOs and helper types are independent top-level classes/files, never inner or nested classes (Java), even when only one private method uses them. In TS, exported types in their own module following the repo layout.
- **Stepdown order (soft):** code reads top-down; private methods appear in the order they are called.

### Tests

- **Naming:** `should{Behavior}When{Condition}` or `when{X}Then{Y}`. Never Given-When-Then in the name.
- **Section markers:** every non-trivial test body is split with `// Given`, `// When`, `// Then` comments. They delimit phases; they are not explanatory comments.
- **Unified asserts:** fluent single-entry assertions: AssertJ `assertThat` in Java, `expect` in TS.
- **Whole-object asserts:** for complex objects or DTOs with many fields, assert the full object (`usingRecursiveComparison()` or ApprovalTests in Java, `toMatchObject`/`toMatchSnapshot` in Vitest/Jest). Never write a cascade of field-by-field asserts. Prefer structured comparison over raw snapshots when golden-master fragility hurts.
- **Characterization tests live apart:** a dedicated class/file per unit, `{ClassName}CharacterizationTest` (Java) or `<name>.characterization.test.ts` (TS). They are a permanent regression net.

### Java

- Use Mockito only across real boundaries. Use Spring context tests only when framework behavior is the subject.
- Use `@InjectMocks` only when constructor setup adds noise.
- Use `ArgumentCaptor` only when the passed object is the behavior under test.
- Review an ApprovalTests baseline before you approve it. A bad baseline freezes bugs.
- Keep the stack trace when you wrap an exception, except at a deliberate sanitization boundary.

### Resources

- `assets/examples/OrderServiceTest.java`: Java test with G/W/T sections, `assertThat`, recursive comparison, and a separate characterization class note.
- `assets/examples/order-service.test.ts`: Vitest test with G/W/T sections and `toMatchObject`.
