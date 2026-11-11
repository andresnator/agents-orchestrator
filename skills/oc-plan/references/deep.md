# Deep Plan

Deep mode of `oc-plan`. The `SKILL.md` Intent, Context, Route, and Plan format apply. This file adds only the deep rules.

## Added limits

- Before writing, create the parent with exactly one of `mkdir -p .ai/deep-planner/discoveries` or `mkdir -p .ai/deep-planner/plans`; never alter or combine them. Use another `.ai/**` path only when the user gives that exact path and its parent exists.
- No web fetch. For history, use only read-only `git log`.
- Load only `oc-routing`, `oc-domain`, and `oc-grill` (its `references/interview.md` engine only).
- Delegate only to the `general` subagent: at most three disjoint research briefs, plus `oc-refactor` lens-mode analyses (see "Refactor or hardening").
- Deep mode also fails if an edge is unclassified or the artifact lacks an end-to-end check with its expected result.

## Reads

Repository code, implementations, callers, contracts, tests, tool versions, and reusable `path:symbol` elements; `references/edge-validation.md` and `references/question-economy.md`; an exact discovery path when converting.

## Questions and routes

- WHEN a fact is discoverable THEN explore instead of asking.
- WHEN the destination or output is ambiguous THEN ask one `question` choice: `Create a plan` (prepare executable work) or `Explore an idea` (discover the destination and decisions); otherwise infer the route.
- WHEN a product, scope, acceptance, or risk decision is open THEN ask the user.
- WHEN research scope warrants it THEN brief up to three disjoint `general` subagents, each returning at most seven `path:line` findings.

## Wayfinder

Use `assets/discovery-template.md`. Create or update one discovery at `.ai/deep-planner/discoveries/<slug>.md` with destination, evidence, decisions, open questions, and next step; keep them current. No status, phase, or readiness markers, and no plan. Update only an exact path from the user or the active conversation; any other collision stops for direction. When the destination and material decisions are clear, suggest `convert this discovery into a plan`.

## Deep Plan

Apply "Plan format" and `oc-routing`. Write exactly one plan at `.ai/deep-planner/plans/<slug>.md`, even when large.

## Refactor or hardening

Classify risk and scope. The plan records: risk `low|medium|high|critical` with evidence and rationale; churn priority from read-only `git log` (high churn raises priority, near-zero churn lowers it unless a planned change lands there); value tier `core|supporting|generic` or `not inferable` (never guessed); target level `class|package|module`; in-scope files; neighboring context; explicit out-of-scope work.

- Low risk: analyze inline.
- Medium or high risk: may brief one `general` subagent to load `oc-refactor` in lens mode. High or critical risk loads `oc-refactor` tooling mode for its `tooling_audit` output.
- Critical risk: may brief two lens subagents with disjoint lens ids.
- Missing protection orders tooling, minimal seams, focused tests, and revalidation before restructuring. Discovered behavior changes stay separate.

Lens brief to a `general` subagent: `Load oc-refactor in lens mode. Input: target=<path> target_slug=<slug> unit=<slug> lens=<lens> lenses=<csv of lens ids> skills=<csv> focus=<text> max=7`. It is read-only and returns `OK plan/analyze ...` plus `TOTAL findings=<n>`. Lens ids come from `oc-refactor` lens mode (`srp`, `dry`, `kiss`, `ocp`, `dip`, `coupling`, `big-o`, `god-object`, `spaghetti`, `logging`, `preconditions`).

## Evidence check

Before returning, check evidence, edges, proportionality, exact paths, and the end-to-end verification in `Done means`. Walk `references/edge-validation.md`; every edge is handled, out of scope (in `Limits`), or an open question. Apply `references/question-economy.md` before asking. Record meaningful rejected alternatives briefly.

## Done means

Wayfinder yields one discovery and no plan; Deep Plan yields one plan and no discovery, roadmap, or change file. The response leads with the discovery or planning outcome and the exact artifact path and next route; plans show `Route: direct | SDD`, the reason, and `ejecuta el plan <path>`; no logs or artifact body.
