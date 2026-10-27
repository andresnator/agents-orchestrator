---
name: oc-conventions
description: "Trigger: writing production code or tests, applying test naming/assert style, extracting constants, placing DTOs or characterization tests. Andres's personal code and test conventions."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "3.1.1"
---

# Code Conventions

## Intent

- **Goal:** Apply Andres's code and test conventions.
- **Limits:** Defaults for new code and repos without an established convention; when the target repo consistently follows another convention, the repo wins. Never churn diffs only to apply a soft preference.
- **Fails if:** Tests assert tautologically against their own constants; characterization tests mix with intent-revealing unit tests.

## Context

- **Reads:** The code under change, the repo's existing conventions.
- **Never reads:** none
- **Persona:** Pragmatic implementer.
- **Scope:** Load when writing production code or tests. Not for documentation, prose artifacts, or infrastructure config with no code. Planners route it by name via `oc-routing` without loading this body.

## Expectations

- **Scenarios:**
  - WHEN writing a plan or design document THEN record the detected language and tool versions with evidence (e.g. `java.version` in `pom.xml`, `typescript` in `package.json`) so the implementer can fetch version-correct documentation.
- **Done means:** Code and tests follow the Method rules or the repo's winning convention; any deviation is named in the plan, design, or summary.
- **Quality needs:** Single Responsibility and Open-Closed carry weight. Introduce interfaces or dependency inversion only for real variation, test seams, or architectural boundaries, never as SOLID dogma (see the `dip` lens in `oc-refactor-lens` `references/lenses.md`).

## Method

### Production code

- **No magic literals:** extract hardcoded numbers and strings into named constants placed where tests can reuse them. Tests reuse them for fixtures and setup; when the constant IS the behavior under test, assert against the expected literal value.
- **Top-level DTOs:** DTOs and helper types are independent top-level classes/files, never inner or nested classes (Java), even when only one private method uses them. In TS, exported types in their own module following the repo layout.
- **Stepdown order (soft):** code reads top-down; private methods appear in the order they are called.

### Tests

- **Naming:** `should{Behavior}When{Condition}` or `when{X}Then{Y}`. Never Given-When-Then in the name.
- **Section markers:** every non-trivial test body is split with `// Given`, `// When`, `// Then` comments. They delimit phases; they are not explanatory comments.
- **Unified asserts:** fluent single-entry assertions: AssertJ `assertThat` in Java, `expect` in TS.
- **Whole-object asserts:** for complex objects or DTOs with many fields, assert the full object (`usingRecursiveComparison()` or ApprovalTests in Java, `toMatchObject`/`toMatchSnapshot` in Vitest/Jest), never a cascade of field-by-field asserts. Prefer structured comparison over raw snapshots when golden-master fragility hurts.
- **Characterization tests live apart:** a dedicated class/file per unit, `{ClassName}CharacterizationTest` (Java) or `<name>.characterization.test.ts` (TS). They are a permanent regression net.

### Resources

- `assets/examples/OrderServiceTest.java`: Java test with G/W/T sections, `assertThat`, recursive comparison, and a separate characterization class note.
- `assets/examples/order-service.test.ts`: Vitest test with G/W/T sections and `toMatchObject`.
