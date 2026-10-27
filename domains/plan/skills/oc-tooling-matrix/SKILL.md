---
name: oc-tooling-matrix
description: "Trigger: tooling compatibility matrix, mutation coverage tooling. Offline baseline for test, coverage, and mutation tool choices."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# Tooling Compatibility Matrix

## Intent

- **Goal:** Provide deterministic first-pass versions and compatibility notes for test, coverage, and mutation tooling.
- **Limits:** Never fetch versions; web fetch remains denied for harness workers. Prefer existing project conventions when present.
- **Fails if:** An emitted version lacks `verify-latest-at-execution: true` and an executor task to verify it is current and CVE-free before installation, an install task lacks a build verification command, or uncertain compatibility is not marked `hypothesis`.

## Context

- **Reads:** The detected stack from `oc-tooling-audit`.
- **Never reads:** Network sources.
- **Persona:** Offline tooling baseline.
- **Scope:** Hardening and high or critical refactor tooling recommendations.

## Expectations

- **Scenarios:**
  - WHEN a stack is detected THEN pick the matching row and snippet template.
  - WHEN version or plugin compatibility is uncertain THEN mark it `hypothesis` and require verification before install.
- **Done means:** Each install task names tooling from the matrix plus its verification command.
- **Quality needs:** Do not migrate tests or runners as safety-plan work unless required for execution.

## Method

### Java matrix

| Detected stack | Baseline tooling | Compatibility notes |
| --- | --- | --- |
| Java 8 + Maven/Gradle | JUnit 5.x via `junit-bom`, AssertJ 3.x, Mockito, JaCoCo 0.8.x, PIT Java-8-compatible line + `pitest-junit5-plugin` | Choose a PIT line compatible with Java 8; verify plugin/JUnit 5 compatibility before install. |
| Java 11+ + Maven/Gradle | JUnit 5.x via `junit-bom`, AssertJ 3.x, Mockito, ApprovalTests when snapshots help, JaCoCo 0.8.x, current PIT + `pitest-junit5-plugin` | PIT >=1.15 requires Java 11+; plugin must match JUnit 5.x. |
| Existing JUnit 4 | Keep JUnit 4 characterization if cheapest; add JUnit Vintage only when running JUnit 4 tests under JUnit Platform is required | Do not migrate tests as part of refactor safety unless required for execution. |

#### Maven snippet templates

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.junit</groupId>
      <artifactId>junit-bom</artifactId>
      <version>${junit.version}</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependency>
  <groupId>org.junit.jupiter</groupId>
  <artifactId>junit-jupiter</artifactId>
  <scope>test</scope>
</dependency>

<plugin>
  <groupId>org.pitest</groupId>
  <artifactId>pitest-maven</artifactId>
  <version>${pit.version}</version>
  <dependencies>
    <dependency>
      <groupId>org.pitest</groupId>
      <artifactId>pitest-junit5-plugin</artifactId>
      <version>${pitest.junit5.plugin.version}</version>
    </dependency>
  </dependencies>
</plugin>
```

#### Gradle snippet templates

```gradle
dependencies {
  testImplementation(platform("org.junit:junit-bom:${junitVersion}"))
  testImplementation("org.junit.jupiter:junit-jupiter")
  testImplementation("org.assertj:assertj-core:${assertjVersion}")
}

test {
  useJUnitPlatform()
}
```

### JavaScript and TypeScript matrix

| Detected stack | Baseline tooling | Compatibility notes |
| --- | --- | --- |
| Vite/Vitest present | Vitest, Testing Library when UI is present, `@stryker-mutator/core` + Vitest runner/plugin | Verify Node floor required by Stryker and runner plugin before install. |
| Jest present or non-Vite project | Jest, Testing Library when UI is present, `@stryker-mutator/core` + Jest runner/plugin | Keep Jest if already configured; avoid runner migration as safety-plan work. |
| No runner detected | Prefer Vitest for modern ESM/Vite projects; prefer Jest for existing CommonJS or Jest ecosystem clues | Record heuristic and verification task. |

#### `package.json` snippet template

```json
{
  "devDependencies": {
    "vitest": "${vitestVersion}",
    "@stryker-mutator/core": "${strykerVersion}"
  },
  "scripts": {
    "test": "vitest run"
  }
}
```

### Python matrix

| Detected stack | Baseline tooling | Compatibility notes |
| --- | --- | --- |
| pytest present or no runner | pytest, coverage.py, mutmut | mutmut is the default mutation option for simple projects; verify Python version support. |
| parallel or distributed mutation need | pytest, coverage.py, cosmic-ray | cosmic-ray is heavier; use only when parallel execution materially matters. |
| unittest-only project | Keep unittest characterization initially; add pytest only if it lowers execution friction | Do not migrate tests for style alone. |

#### Python snippet templates

```toml
[project.optional-dependencies]
test = [
  "pytest==${pytestVersion}",
  "coverage==${coverageVersion}",
  "mutmut==${mutmutVersion}",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

```text
pytest==${pytestVersion}
coverage==${coverageVersion}
mutmut==${mutmutVersion}
```

### Characterization tooling

| Need | Baseline option | Notes |
| --- | --- | --- |
| Golden master / approval of large outputs | ApprovalTests (Java, .NET, Python, JS variants) | Anchors current output verbatim; good first net for monster methods and report-like outputs. |
| Characterizing persistence or external boundaries | Testcontainers | Real dependency in a disposable container; heavier — prefer at pinch points, not per unit. |
| Comparing JSON outputs | JsonUnit (Java) or snapshot testing in JS/TS | Whole-document asserts with ignorable fields; aligns with whole-object assert conventions. |

### Verification commands

| Build tool | Verification command |
| --- | --- |
| Maven | `mvn -q verify` |
| Gradle wrapper | `./gradlew check` |
| Gradle | `gradle check` |
| npm/pnpm/yarn | `npm test` / `pnpm test` / `yarn test` matching existing lockfile |
| Python | `pytest -q` |
