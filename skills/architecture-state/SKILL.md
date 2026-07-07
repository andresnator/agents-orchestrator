---
name: architecture-state
description: >
  Trigger: architecture review, project state, toolchain detection,
  architecture style, architecture gaps, fitness functions. Detect
  language/toolchain with evidence, identify the architecture style, and
  produce a gap analysis with fitness-function proposals.
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

# Architecture State

## Activation Contract

Use this skill to establish the verified current state of a project's architecture: what it is built with, how it is shaped, and where the gaps are.

Do not use it for code-level findings (naming, method size, class design) — those belong to the refactor harness.

## Hard Rules

- Every claim carries `file:line` evidence. Build files, manifests, and configs beat READMEs; a README-only claim is `aspirational`, never `verified`.
- Style identification names the concrete evidence that justifies it, plus the strongest counter-evidence when the style is mixed.
- Gaps are architecture-level: boundaries, cycles, missing guardrails, missing CI/tests wiring — not style nits.

## Detection Checklist

Record, each with evidence:

- Languages and runtime versions (e.g. `java.version` in `pom.xml`, `engines` in `package.json`, `requires-python`).
- Build and dependency tooling (Maven/Gradle/npm/pnpm/pip/poetry), lockfile presence.
- Frameworks and platforms (from dependencies, not docs).
- Module layout: top-level modules/packages and their declared dependencies.
- Tests and CI: test frameworks present, CI workflows present, architecture checks present or absent.

## Style Identification

Classify the dominant style with evidence: `layered`, `hexagonal/ports-adapters`, `modular monolith`, `microservices`, `event-driven`, or `big-ball-of-mud` (no discernible boundaries). Mixed styles are stated as such — dominant plus deviations.

## Gap Analysis

One table, ranked by impact:

| Gap | Evidence | Why it matters | Proposed fitness function |
|---|---|---|---|

A gap without a viable fitness function states the manual check instead.

## Fitness Function Proposals

Propose automated guardrails matched to the detected toolchain — ArchUnit or Spring Modulith `verify()` (Java), dependency-cruiser (JS/TS), import-linter (Python). Propose `no cycles between modules` and `allowed dependencies only` first; they catch the most drift for the least setup. Per-ecosystem rule examples and verify commands live in `references/fitness-functions.md`.

## Output Contract

Return compact YAML plus the gap table:

```yaml
project_state:
  languages: [{name, version, evidence}]
  toolchain: [{tool, evidence}]
  frameworks: [{name, evidence}]
  modules: [{name, path, depends_on}]
  style: {dominant, evidence, deviations}
  tests_ci: {test_framework, ci, arch_checks}
gaps: [{id, gap, evidence, impact, fitness_function}]
```

## Verification

- No claim without evidence; README-only claims marked `aspirational`.
- Style has named evidence and counter-evidence when mixed.
- Every gap has a fitness function or an explicit manual check.
