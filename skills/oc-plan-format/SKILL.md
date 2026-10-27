---
name: oc-plan-format
description: "Trigger: execution plan, executable plan, light plan. Draft one neutral IDSD plan for direct or SDD execution."
license: MIT
metadata:
  author: andresnator
  version: "4.0.0"
  status: testing
---

# Plan Format

## Intent

- **Goal:** Exactly one IDSD plan (ICE + Method) for the requested outcome, small or large, from `assets/plan-template.md`.
- **Limits:** Only the plan file may change; never edit production code, stage, commit, or push during planning. `Delivery` authorizes later execution only.
- **Fails if:** an ICE field (`Goal`, `Limits`, `Fails if`, `Reads`, `Never reads`, `Persona`, `Scope`, `Scenarios`, `Done means`, `Quality needs`) or `Method` → `Approach`, `Work groups`, `Execution guidance` is missing (the plan is not ready: `BLOCK`); a plan is overwritten implicitly; delivery is inferred.

## Context

- **Reads:** the planner's evidence, `oc-routing` for skill names, the exact destination path.
- **Never reads:** implementation skill bodies.
- **Persona:** precise plan author writing for a human and an executor.
- **Scope:** `oc-plan-deep`, `oc-plan-light`, `oc-grill` plan mode, and planless SDD `run.md` contracts.

## Expectations

- **Scenarios:**
  - WHEN the destination exists THEN update it only when the user supplied its exact path or the active conversation created or selected it; otherwise ask one closed choice: reuse the existing plan or generate a new slug.
  - WHEN the user states explicit delivery intent THEN write one `Delivery:` line immediately after the title: no commits `working-tree`, commits `commit-per-unit`, TCR `tcr`; otherwise omit it (execution defaults to `working-tree`). Never infer delivery from a PR request, route, work group, or skill name.
  - WHEN delivery requests are contradictory, duplicated, or unknown THEN block plan creation until resolved.
  - WHEN canonical specs matter THEN qualify scenarios as `<capability>/<requirement>` with observable `WHEN` and `THEN`.
- **Done means:**
  - One file holds every template section; empty optional content is `none`, never filler.
  - Every claim cites `path:line` or is marked `hypothesis`/open question.
  - Ordered work groups each have `Files:`, `Skills:` (names from `oc-routing` or `none`, never paths), and acyclic `Depends on:`. Delivery skills (`oc-tcr`, `oc-commits`, other Git skills) never appear in work groups.
  - Tasks are actionable and verifiable; behavior changes live in `Scenarios`, not hidden in tasks.
  - `Risks and open questions` holds only real rollback conditions or hazards.
  - `Execution guidance` gives `Route: direct | SDD`, `Reason:`, and ``Run: `ejecuta el plan <path>` ``.
- **Quality needs:** short complete English sentences; paths, symbols, commands, URLs, numbers, and Markdown exact; no cryptic A2A fragments. SDD verification counts every scenario and every `Done means` item.

## Method

Former section mapping: Outcome → Goal; Scope In → Scope, Scope Out → Limits; Evidence → Reads; Files → Scope; Behavior → Scenarios; Verify → Done means; Dependencies → `Depends on:` and Risks; Skills → per work group.

Resource: `assets/plan-template.md`.
