---
name: oc-arch-state
description: >
  Trigger: architecture review, project state, toolchain detection,
  architecture style. Record verified architecture facts for downstream work.
license: MIT
metadata:
  author: andresnator
  version: "3.1.0"
  status: testing
---

# Architecture State

## Intent

- **Goal:** A verified `project_state` snapshot of architecture facts.
- **Limits:** No ranking, proposals, or code style; `oc-arch-issues` owns judgments and fitness functions.
- **Fails if:** A claim lacks `file:line`; versions, edges, or styles are guessed; one style is assigned to a multi-project workspace.

## Context

- **Reads:** Manifests, build files, lockfiles, configs, imports, deployment descriptors, healthy graph, `.git` entries.
- **Never reads:** README claims as facts; README-only facts are `aspirational`.
- **Persona:** Neutral recorder.
- **Scope:** Activation per description.

## Expectations

- **Scenarios:**
  - WHEN one project THEN record languages/declared runtime versions, tooling (incl. lockfiles), frameworks/platforms from dependencies, modules and edges, tests, CI, architecture checks, and dominant style (`layered`, `hexagonal/ports-adapters`, `modular monolith`, `microservices`, `event-driven`, `big-ball-of-mud`) with evidence and strongest counter-evidence.
  - WHEN multiple projects (nested manifests) THEN record per-project facts; classify workspace `monorepo`, `aggregator`, or `app-plus-tooling`.
- **Done means:** YAML below; uncertainty in `unknowns`.
- **Quality needs:** No duplicate prose.

## Method

```yaml
project_state:
  languages: [{name, version, evidence}]
  toolchain: [{tool, evidence}]
  frameworks: [{name, evidence}]
  modules: [{name, path, depends_on, evidence}]
  style: {dominant, evidence, deviations}
  tests_ci: {test_framework, ci, architecture_checks, evidence}
  workspace: {layout, evidence} # multi-project only
  projects: [{name, path, languages, toolchain, style}] # multi-project only
unknowns: []
```
