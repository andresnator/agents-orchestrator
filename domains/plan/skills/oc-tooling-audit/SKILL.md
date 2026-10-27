---
name: oc-tooling-audit
description: "Trigger: tooling audit, test tooling gaps, tooling compatibility matrix, mutation coverage tooling. Detect build/test/coverage/mutation tooling and pick compatible baselines for refactor safety plans."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "3.0.0"
  status: testing
---

# Tooling Audit

## Intent

- **Goal:** Identify existing test infrastructure, missing safety tooling, installation tasks, verification commands, and compatibility checks.
- **Limits:** Read-only detection. Never fetch versions; web fetch remains denied for harness workers. Prefer existing project conventions when present. `references/matrix.md` owns offline version/tool baselines; load it only when a gap needs an install task or a compatibility check.
- **Fails if:** A gap lacks an install task with an exact verify command, more than 5 gaps are emitted, a version without evidence or uncertain compatibility is not marked `hypothesis`, or an emitted version lacks `verify_latest_at_execution: true` and an executor task to verify it is current and CVE-free before installation.

## Context

- **Reads:** Prefer direct reads/globs for these files only when they are in or above the resolved target scope:
  - `pom.xml`, `build.gradle`, `build.gradle.kts`, `gradle/wrapper/gradle-wrapper.properties`
  - `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `tsconfig.json`, `vite.config.*`, `jest.config.*`, `vitest.config.*`
  - `pyproject.toml`, `requirements*.txt`, `setup.cfg`, `tox.ini`, `pytest.ini`, `poetry.lock`
  - `.java-version`, `.sdkmanrc`, `.tool-versions`, Maven compiler properties, Gradle Java toolchain declarations
- **Never reads:** Build files unrelated to the resolved target scope; network sources.
- **Persona:** Read-only tooling detector.
- **Scope:** Hardening and refactor planning at high or critical risk.

## Expectations

- **Scenarios:**
  - WHEN detecting THEN record language version and build tool with evidence, and present `test_framework`, `assertion_lib`, `coverage`, and `mutation` tooling.
  - WHEN a gap exists THEN load `references/matrix.md`, pick the matching row and snippet template, and create an install task with an exact verify command.
  - WHEN version evidence is missing, or version or plugin compatibility is uncertain, THEN mark it `hypothesis` and require verification before install.
- **Done means:** The compact `tooling_audit` YAML below, with max 5 gaps prioritized by safety impact and compatibility checks such as Java/PIT requirements or Node/Python floors.
- **Quality needs:** Every claim has evidence. Do not migrate tests or runners as safety-plan work unless required for execution.

## Method

```yaml
tooling_audit:
  language: ""            # include version and evidence file:line
  build_tool: ""
  present:
    test_framework: {}
    assertion_lib: {}
    coverage: {}
    mutation: {}
  gaps: []                # max 5
  install_tasks:
    - tool: ""
      matrix_ref: ""
      build_file: "file:line insertion point"
      snippet: ""
      verify_command: ""
      verify_latest_at_execution: true
  compatibility_checks:
    - "PIT >=1.15 requires Java 11+; detected Java 17: OK"
```
