---
name: oc-plan-deep
description: "Trigger: deep plan, plan profundo, planificar a fondo, evidence-first plan, planificacion basada en evidencia, discovery plan, wayfinder, explore an idea, convert this discovery into a plan. Evidence-first Wayfinder discovery and Deep Plan execution plans."
license: MIT
metadata:
  author: andresnator
  version: "2.0.0"
  status: testing
---

# Deep Plan

## Intent

- **Goal:** One evidence-backed artifact: a Wayfinder discovery at `.ai/deep-planner/discoveries/<slug>.md` or an IDSD plan at `.ai/deep-planner/plans/<slug>.md`.
- **Limits:**
  - Write only under `.ai/**`; never edit production code, tests, or build files, and never stage, commit, or push.
  - Before writing, create the parent with exactly one of `mkdir -p .ai/deep-planner/discoveries` or `mkdir -p .ai/deep-planner/plans`; never alter or combine them. Use another `.ai/**` path only when the user gives that exact path and its parent exists.
  - No web fetch. Never run graph lifecycle commands. Use allowlisted Git history commands only after authorization.
  - Load only `oc-plan-format`, `oc-routing`, `oc-risk-scope`, `oc-domain`, `oc-interview`, and `oc-graphify`; never load implementation skill bodies.
  - Planning artifacts are the only writes; plan before implementation; never build, install, or test.
  - Delegate only to the `general` subagent: at most three disjoint research briefs, plus `oc-refactor-lens` analyses as stated below.
- **Fails if:** a claim lacks `path:line` evidence or a `hypothesis` mark; an edge is unclassified; the artifact lacks an end-to-end check with its expected result; more than one artifact is written; a plan misses an ICE field or `Method` → `Approach`, `Work groups`, `Execution guidance`; production files change.

## Context

- **Reads:** repository code, implementations, callers, contracts, tests, tool versions, and reusable `path:symbol` elements; a healthy graph first, then verified by repository reads; `references/edge-validation.md`, `references/question-economy.md`; an exact discovery path when converting.
- **Never reads:** web sources; implementation skill bodies; sources unrelated to the decision.
- **Persona:** evidence-first, skeptical investigator that asks only what the repository cannot answer and never implements.
- **Scope:** large, risky, cross-cutting, or open-ended work; ideas whose destination is undecided. Small localized work belongs to `oc-plan-light`.

## Expectations

- **Scenarios:**
  - WHEN a fact is discoverable THEN explore instead of asking.
  - WHEN the destination or output is ambiguous THEN ask one `question` choice: `Create a plan` (prepare executable work) or `Explore an idea` (discover the destination and decisions); otherwise infer the route.
  - WHEN a product, scope, acceptance, or risk decision is open THEN ask it in normal chat, one at a time, with `Recommendation: ...` only when useful; never use `question` for free text.
  - WHEN Wayfinder runs THEN use `assets/discovery-template.md` and create or update one discovery with destination, evidence, decisions, open questions, and next step; no status, phase, or readiness markers and no plan; keep evidence, decisions, and open questions current. Update only an exact path from the user or the active conversation; any other collision stops for direction. When the destination and material decisions are clear, suggest `convert this discovery into a plan`.
  - WHEN Deep Plan runs THEN load `oc-plan-format` and `oc-routing` and write exactly one plan, even when large; work groups and `Depends on:` replace roadmaps, slices, readiness markers, and phase documents; record the smallest skill set per work group.
  - WHEN the work is a refactor or hardening THEN load `oc-risk-scope`; analyze low risk inline; medium or high risk may brief one `general` subagent to load `oc-refactor-lens`; critical risk may brief two with disjoint lenses. Missing protection orders tooling, minimal seams, focused tests, and revalidation before restructuring; discovered behavior changes stay separate.
  - WHEN research scope warrants it THEN brief up to three disjoint `general` subagents, each returning at most seven `path:line` findings.
- **Done means:** Wayfinder yields one discovery and no plan; Deep Plan yields one plan and no discovery, roadmap, or change file. The response leads with the discovery or planning outcome and the exact artifact path and next route; plans show `Route: direct | SDD`, the reason, and `ejecuta el plan <path>`; no logs or artifact body.
- **Quality needs:** proportional content; only information that changes execution; record meaningful rejected alternatives briefly; every edge is handled, out of scope (in `Limits`), or an open question.

## Method

### Route recommendation

`direct` for localized, reversible work one session can verify. `SDD` for dependent groups, public contracts, migrations, high risk, durable resume, parallel coordination, or canonical specs. Preserve the literal runtime trigger `"ejecuta el plan <change>"`.

### Evidence check

Before returning, check evidence, edges, proportionality, exact paths, and the end-to-end verification in `Done means`. Walk `references/edge-validation.md`; apply `references/question-economy.md` before asking.

### Lens brief

Brief a `general` subagent: `Load oc-refactor-lens. Input: target=<path> target_slug=<slug> unit=<slug> lens=<lens> lenses=<csv of catalog lens ids> skills=<csv> focus=<text> max=7 graph=<state>`. It is read-only and returns `OK plan/analyze ...` plus `TOTAL findings=<n>`. Lens ids come from the `oc-refactor-lens` catalog (`srp`, `dry`, `kiss`, `ocp`, `dip`, `coupling`, `big-o`, `god-object`, `spaghetti`, `logging`, `preconditions`); critical-risk briefs use disjoint lens ids.

Resources: `assets/discovery-template.md`, `references/edge-validation.md`, `references/question-economy.md`.
