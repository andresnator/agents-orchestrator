---
name: oc-refactor
description: "Trigger: refactor, refactorizar, code smells, malos olores del código, olores de código, código sucio, limpiar código, simplificar condicionales, reestructurar clase, eliminar código duplicado, reducir complejidad, mejorar legibilidad, reorganizar código, clean code, código limpio, SOLID, simplify conditionals, extract method, extraer método, mejorar este código, legacy code, legacy code safety, characterization tests, safe refactor, dependency seam detection, hard dependencies, refactor lens, refactor analysis, analyze unit with lens, architecture impact review, layer boundaries, tooling audit, test tooling gaps, mutation coverage tooling. Behavior-preserving refactor in any language, plus read-only lens, legacy-safety, architecture-impact, and tooling-audit modes."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "4.0.1"
  attribution: "lens, legacy, impact, and tooling modes adapted from gentle-ai/plan-refactor (Apache-2.0)"
---

# Refactor

## Intent

- **Goal:** Improve code structure without a change to observable behavior, or return one read-only analysis that a mode below defines.
- **Limits:**
  - Cover, then modify. Do not change code that tests do not cover. If coverage is too expensive, make the step smaller or add a hardening task first.
  - Keep behavior-preserving work and functional change in different steps. Record a bug that you find as follow-up work. Do not fix it in the refactor.
  - Analysis modes (`lens`, `impact`, `tooling`) are read-only. They do not edit, ask, delegate, or fetch.
  - Do not refactor across a bounded-context boundary.
- **Fails if:** observable behavior changes; a public contract changes silently; a claim has no `file:line` and no `hypothesis` mark; a characterization test asserts desired behavior instead of current behavior.

## Context

- **Reads:** the target, its callers and tests, and build files in or above the target scope.
- **Never reads:** code that the change cannot affect; web sources.
- **Persona:** careful refactoring engineer.
- **Scope:** refactor requests in any language; `oc-plan` deep-mode briefs; `oc-arch` (`kiss` lens).

## Expectations

- **Scenarios:**
  - WHEN the target has no sufficient tests THEN write characterization tests for the touched zone first, in a dedicated test file per unit (per `oc-conventions`). Find seams and break dependencies minimally before structural change.
  - WHEN the language is Java THEN use only APIs that the detected Java version supports, and keep checked-exception and public API contracts.
  - WHEN a brief gives `target=... lens=...` THEN use lens mode.
  - WHEN the question is local versus architectural THEN use impact mode.
  - WHEN a high or critical risk plan needs safety tooling THEN use tooling mode.
- **Done means:** catalog mode: the refactor is applied in small steps, tests pass after each step, and each change has a short reason. Other modes: only the output contract of that mode.
- **Quality needs:** evidence over opinion; smallest safe step.

## Method

### Lens mode

Input line: `target=<path> target_slug=<slug> unit=<slug> lens=<lens> lenses=<csv|none> skills=<csv|none> focus=<text> max=7`. A missing field returns `BLOCK plan/analyze <reason>`. Lens ids: `srp`, `dry`, `kiss`, `ocp`, `dip`, `coupling`, `big-o`, `god-object`, `spaghetti`, `logging`, `preconditions`. An unknown lens id or a skill outside the allowlist (`oc-conventions`, `oc-java`, `oc-refactor`) continues with `nf=<reason>`. Maximum seven findings. Output exactly:

```text
OK plan/analyze target=<path> target_slug=<slug> unit=<slug> lens=<lens>
<file:line> <high|medium|low> <recommendation>; technique=<canonical|none> confidence=<0..1>
TOTAL findings=<n> [nf=<reason>]
```

### Impact mode

Give a verdict: `local` or `architectural`, with coupling, cycles, and boundary crossings cited as `file:line`. Modularization inside the current deployable is local. Extraction of a deployable is architectural: route it to `oc-arch`. When nobody can predict if the restructure will work, recommend `oc-plan` deep mode (Wayfinder discovery), not an executable change.

### Tooling mode

Read-only detection. Do not fetch versions. Prefer existing project tooling. Output:

```yaml
tooling_audit:
  language: ""            # version and evidence file:line
  build_tool: ""
  present: {test_framework: {}, assertion_lib: {}, coverage: {}, mutation: {}}
  gaps: []                # max 5, by safety impact
  install_tasks:
    - {tool: "", build_file: "file:line", snippet: "", verify_command: "", verify_latest_at_execution: true}
  compatibility_checks: []  # for example "PIT >=1.15 requires Java 11+; detected Java 17: OK"
```

Each gap has an install task with an exact verify command. Mark a version without evidence, or an uncertain compatibility, as `hypothesis`.
