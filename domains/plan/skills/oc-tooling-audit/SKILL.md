---
name: oc-tooling-audit
description: "Trigger: tooling audit, test tooling gaps. Detect build/test/coverage/mutation tooling for refactor safety plans."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# Tooling Audit

## Intent

- **Goal:** Identify existing test infrastructure, missing safety tooling, installation tasks, verification commands, and compatibility checks.
- **Limits:** Read-only detection. The `oc-tooling-matrix` skill owns offline version/tool baselines; load it.
- **Fails if:** A gap lacks an install task with an exact verify command, more than 5 gaps are emitted, or a version without evidence is not marked `hypothesis`.

## Context

- **Reads:** Prefer direct reads/globs for these files only when they are in or above the resolved target scope:
  - `pom.xml`, `build.gradle`, `build.gradle.kts`, `gradle/wrapper/gradle-wrapper.properties`
  - `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `tsconfig.json`, `vite.config.*`, `jest.config.*`, `vitest.config.*`
  - `pyproject.toml`, `requirements*.txt`, `setup.cfg`, `tox.ini`, `pytest.ini`, `poetry.lock`
  - `.java-version`, `.sdkmanrc`, `.tool-versions`, Maven compiler properties, Gradle Java toolchain declarations
- **Never reads:** Build files unrelated to the resolved target scope.
- **Persona:** Read-only tooling detector.
- **Scope:** Hardening and refactor planning at high or critical risk.

## Expectations

- **Scenarios:**
  - WHEN detecting THEN record language version and build tool with evidence, and present `test_framework`, `assertion_lib`, `coverage`, and `mutation` tooling.
  - WHEN a gap exists THEN create an install task from the compatibility matrix with an exact verify command.
  - WHEN version evidence is missing THEN mark the version `hypothesis` and require verification.
- **Done means:** The compact `tooling_audit` YAML below, with max 5 gaps prioritized by safety impact and compatibility checks such as Java/PIT requirements or Node/Python floors.
- **Quality needs:** Every claim has evidence.

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
