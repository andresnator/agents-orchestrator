---
name: oc-arch
description: "Architecture map, review, ideate (ADR plus plan), or service boundary. Trigger: /arch, architecture map, architecture review, target architecture, C4 diagram."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "4.0.0"
---

# Architecture Operations

## Intent

- **Goal:** Complete exactly one `operation=map|review|ideate|boundary` for one frozen target and return its real artifact paths.
- **Limits:**
  - Work at system/module boundaries, never code style.
  - Write only `.ai/architect/reports/**`, `<docfolder>/architecture/**`, and for `ideate` one `<docfolder>/adr/NNNN-slug.md` and one `.ai/plans/<slug>.md`; `<docfolder>` = existing `docs/`, else `doc/`.
  - Never edit production code, tests, or build files; never commit or push.
  - Load only the operation references and skills listed in Method.
  - Never run dependency audit commands or install tools.
  - Inside a subagent: no questions and no Git. Assume, continue, and report the assumption.
- **Fails if:** a claim lacks `path:line` evidence or a `hypothesis` label, a file outside the write limits changes, an operation other than `ideate` writes a plan or an execution handoff, or `boundary` writes without one exact target.

## Context

- **Reads:** the operation and raw arguments, read/search results, source evidence, and the `references/`, `assets/`, and skills each operation loads.
- **Scope:** `/arch map|review|ideate|boundary`, or any architecture request routed by `orchestraitor`.

## Expectations

- **Scenarios:**
  - WHEN scope or a decision is missing THEN pick the most probable option, continue, and report the assumption.
  - WHEN `review` has explicit dependency focus THEN inventory manifests with `path:line`; give no vulnerability or EOL verdicts.
  - WHEN `boundary` has no exact target THEN use the only service of the repository. If there are two or more services, ask one target question before writing.
- **Done means:**
  - `ideate`: lead with the architecture outcome, then the ADR path, plan path, and `ejecuta el plan <path>`.
  - `map`, `review`, `boundary`: return only the actual artifact paths.
  - Blockers are explained with evidence in user-facing language; omit logs and artifact bodies.
- **Quality needs:** compact, ranked, evidence-cited artifacts; no companion phase documents. The `map` files use Mermaid diagrams. Chat output uses ASCII.

## Method

Freeze one target first. Load each operation's references (`references/<op>.md`, each keeping its own Intent/Context/Expectations) and skills in order:

| Operation | Load in order | Output |
|---|---|---|
| `map` | `references/state.md`, `references/map.md` (skeleton `assets/architecture-doc-set.md`) | Create or refresh C4-lite docs with Mermaid diagrams under `<docfolder>/architecture/` in place |
| `review` | `references/state.md`, `references/issues.md` (`references/fitness-functions.md`) | One ranked report under `.ai/architect/reports/` |
| `ideate` | `references/state.md`, `references/ideate.md`, `oc-plan` (plan format only), `oc-adr` (template only, no interview); the `oc-refactor` `kiss` lens as needed | One ADR at `<docfolder>/adr/NNNN-slug.md` (`oc-adr` template) and one plan at `.ai/plans/<slug>.md` (`oc-plan` template); group 1 establishes fitness-function guardrails |
| `boundary` | `references/boundary.md` | Require exact target and target-specific path under `.ai/architect/reports/`; write it, then confirm the report exists |
