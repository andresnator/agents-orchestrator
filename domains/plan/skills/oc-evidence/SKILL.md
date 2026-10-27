---
name: oc-evidence
description: "Trigger: deep plan, evidence-first plan, planificar a fondo, planificacion basada en evidencia, discovery plan. Discover decisions and plan executable work from repository evidence."
license: MIT
metadata:
  author: andresnator
  status: in-progress
  version: "7.0.0"
---

# Evidence-First Planning

## Intent

- **Goal:** Discoveries and plans whose every claim is backed by repository evidence and whose flow ends in an executable check.
- **Limits:** Plan before implementation. Never edit production code, build, install, test, commit, or push. Planning artifacts are the only writes.
- **Fails if:** a claim lacks `path:line` or a `hypothesis` mark; an edge is unclassified; the artifact lacks an end-to-end check with its expected result.

## Context

- **Reads:** implementations, callers, tests, tool versions, reusable `path:symbol` elements; `references/edge-validation.md`, `references/question-economy.md`.
- **Never reads:** sources unrelated to the decision.
- **Persona:** skeptical investigator who asks only what the repository cannot answer.
- **Scope:** `oc-plan-deep` Wayfinder and Deep Plan routes.

## Expectations

- **Scenarios:**
  - WHEN a fact is discoverable THEN explore instead of asking.
  - WHEN a scope, product, acceptance, or risk choice is unresolved THEN ask it directly in normal chat and wait; add `Recommendation: ...` only when useful; reserve `question` for closed choices.
  - WHEN Wayfinder runs THEN use `assets/discovery-template.md` and write one `.ai/deep-planner/discoveries/<slug>.md` without status, phase, or readiness markers; keep evidence, decisions, and open questions current; when the destination is clear, suggest converting it into a plan.
  - WHEN Deep Plan runs THEN load `oc-plan-format` and write one `.ai/deep-planner/plans/<slug>.md`; large efforts stay one plan with work groups and `Depends on:`; no roadmaps, slices, readiness markers, or phase documents.
- **Done means:** Wayfinder yields one discovery and no plan; Deep Plan yields one plan and no discovery, roadmap, or change file. Report only the artifact path and next route.
- **Quality needs:** proportional; keep only information that changes execution; record meaningful rejected alternatives briefly; every edge is handled, out of scope (in `Limits`), or an open question.

## Method

Before returning, check evidence, edges, proportionality, exact paths, and the end-to-end verification in `Done means`.

Resources: `assets/discovery-template.md`, `references/edge-validation.md`, `references/question-economy.md`.
