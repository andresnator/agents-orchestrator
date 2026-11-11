---
name: oc-arch
description: "Trigger: architecture map, architecture review, architecture ideate, target architecture, ADR plus plan, service boundary inspection, operation=map|review|ideate|boundary, C4 diagram, container diagram, flow map, architecture docs, architecture drift, project state, toolchain detection, architecture style, repo issues, project problems, architecture issue shortlist, architecture refactor ideas, modular monolith, architecture patterns, restructure the system. Coordinate one evidence-backed architecture operation."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "3.0.3"
---

# Architecture Operations

## Intent

- **Goal:** Complete exactly one `operation=map|review|ideate|boundary` for one frozen target and return its real artifact paths.
- **Limits:**
  - Work at system/module boundaries, never code style.
  - Write only `.ai/architect/**` and `<docfolder>/architecture/**`; `<docfolder>` = existing `docs/`, else `doc/`.
  - Never edit production code, tests, or build files; never commit or push.
  - Load only the operation references and skills listed in Method; never load implementation skill bodies (`oc-conventions` and similar). Plans only name them.
  - Never run dependency audit commands or install tools.
  - When loaded inside a delegated `general` subagent: no questions and no Git; return blockers instead.
- **Fails if:** a claim lacks `path:line` evidence or a `hypothesis` label, a file outside the write limits changes, an operation invents a plan or execution handoff, or `boundary` writes without one exact target.

## Context

- **Reads:** the operation and raw arguments, read/search results, source evidence, and the `references/`, `assets/`, and skills each operation loads.
- **Scope:** `/arch map|review|ideate|boundary`, or any architecture request routed by `orchestraitor`.

## Expectations

- **Scenarios:**
  - WHEN scope or a material decision is missing THEN ask for it.
  - WHEN `review` has explicit dependency focus THEN inventory manifests with `path:line`; give no vulnerability or EOL verdicts.
  - WHEN `boundary` has no exact target THEN ask one blocking target question before writing.
- **Done means:**
  - `ideate`: lead with the architecture outcome, then the ADR path, plan path, and `ejecuta el plan <path>`.
  - `map`, `review`, `boundary`: return only the actual artifact paths.
  - Blockers are explained with evidence in user-facing language; omit logs and artifact bodies.
- **Quality needs:** compact, ranked, evidence-cited artifacts; no companion phase documents.

## Method

Freeze one target first. Load each operation's references (`references/<op>.md`, each keeping its own Intent/Context/Expectations) and skills in order:

| Operation | Load in order | Output |
|---|---|---|
| `map` | `references/state.md`, `references/map.md` (skeleton `assets/architecture-doc-set.md`) | Create or refresh C4-lite docs under `<docfolder>/architecture/` in place |
| `review` | `references/state.md`, `references/issues.md` (`references/fitness-functions.md`) | One ranked report under `.ai/architect/reports/` |
| `ideate` | `references/state.md`, `references/ideate.md`, `oc-plan`, `oc-routing` (`oc-adr` and the `oc-refactor` `kiss` lens as needed) | One ADR under `<docfolder>/architecture/adr/` and one `.ai/architect/plans/<slug>.md`; every work group records its routing result; group 1 establishes fitness-function guardrails |
| `boundary` | `references/boundary.md` | Require exact target and target-specific path under `.ai/architect/reports/`; write it, then confirm the report exists |
