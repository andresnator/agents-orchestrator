---
name: oc-plan
description: "Trigger: light plan, quick plan, plan rápido, plan light, deep plan, plan profundo, planificar a fondo, evidence-first plan, planificacion basada en evidencia, discovery plan, wayfinder, explore an idea, convert this discovery into a plan, execution plan, executable plan. Planner with light and deep modes (Wayfinder discovery included) that drafts one neutral IDSD plan for direct or SDD execution from one shared template."
license: MIT
metadata:
  author: andresnator
  version: "5.3.0"
  status: testing
---

# Plan

## Intent

- **Goal:** Exactly one planning artifact: a light IDSD plan, a deep evidence-backed IDSD plan, or a Wayfinder discovery, always in the shape of `assets/plan-template.md` (plans) or `assets/discovery-template.md` (discoveries).
- **Limits:**
  - Planning artifacts under `.ai/**` are the only writes. Plan before implementation.
  - Never edit production code, tests, or build files. Never build, install, test, stage, commit, or push.
  - Never load implementation skill bodies.
  - A plan `Delivery:` line authorizes later execution only.
- **Fails if:**
  - a plan misses an ICE field (`Goal`, `Limits`, `Fails if`, `Reads`, `Never reads`, `Persona`, `Scope`, `Scenarios`, `Done means`, `Quality needs`) or `Method` → `Approach`, `Work groups`, `Execution guidance` (the plan is not ready: `BLOCK`);
  - a claim lacks `path:line` or a `hypothesis` mark;
  - more than one artifact is written, or a plan is overwritten implicitly;
  - delivery is inferred;
  - risky work is planned light instead of escalated to deep;
  - production files change.

## Context

- **Reads:** `oc-routing` for skill names; the exact destination path; only the repository evidence the mode allows; `references/deep.md` in deep mode.
- **Never reads:** web sources; modules and sources unrelated to the decision.
- **Scope:**

  | Mode | Triggers | Use for | Follow |
  | --- | --- | --- | --- |
  | light | `light plan`, `quick plan`, `plan rápido`, `plan light` | small or medium localized, reversible work | "Light mode" and "Plan format" below |
  | deep | `deep plan`, `plan profundo`, `planificar a fondo`, `evidence-first plan`, `planificacion basada en evidencia`, `discovery plan`, `wayfinder`, `explore an idea`, `convert this discovery into a plan` | large, risky, cross-cutting, or open-ended work; ideas whose destination is undecided | `references/deep.md` and "Plan format" below |
  | format | `execution plan`, `executable plan`; callers (`oc-grill` plan mode, planless SDD `run.md`) | drafting the plan file itself | "Plan format" below |

## Expectations

- **Scenarios:**
  - WHEN the mode is explicit THEN follow that mode only.
  - WHEN the mode is unstated THEN pick light for localized reversible work, deep otherwise.
  - WHEN a light run meets SDD-level risk (public contracts, migrations, dependent groups, high risk) THEN stop and switch to deep mode instead of writing a light plan.
- **Done means:**
  - Light: the plan in chat, plus the path when saved.
  - Deep: the `Done means` in `references/deep.md`.
  - Every saved plan: the artifact path and ``ejecuta el plan <path>``.
- **Quality needs:** proportional content; only information that changes execution; short complete English sentences; paths, symbols, commands, URLs, numbers, and Markdown exact; no cryptic A2A fragments.

## Method

### Route

The route is the execution path that a plan recommends in `Execution guidance`. Preserve the literal runtime trigger `"ejecuta el plan <change>"`.

| Route | Use for |
| --- | --- |
| `direct` | localized, reversible work that one session can verify |
| `SDD` | dependent groups, public contracts, migrations, high risk, durable resume, parallel coordination, or canonical specs |

### Light mode

- Read only `oc-routing` and the few files that change execution. No subagents and no refactor lenses.
- Show the plan in chat. Write `.ai/deep-planner/plans/<slug>.md` only when the user asks to save it or wants `ejecuta el plan`: create `.ai/deep-planner/plans` with `mkdir -p`, apply the collision rule below, write the plan, and show `ejecuta el plan <path>`.

### Plan format

Every plan fills `assets/plan-template.md`: light and deep plans, `oc-grill` plan mode, and planless SDD `run.md` contracts.

- **Collision:** when the destination exists, update it only when the user supplied its exact path or the active conversation created or selected it. Otherwise ask one closed choice: reuse the existing plan or generate a new slug.
- **Delivery:** when the user states explicit delivery intent, write one `Delivery:` line immediately after the title: no commits `working-tree`, commits `commit-per-unit`. Otherwise omit it (execution defaults to `working-tree`). Never infer delivery from a PR request, route, work group, or skill name. Contradictory, duplicated, or unknown delivery requests block plan creation until resolved.
- **Sections:** one file holds every template section; empty optional content is `none`, never filler. Every claim cites `path:line` or is marked `hypothesis`/open question.
- **Scenarios:** behavior changes live in `Scenarios`, not hidden in tasks. When canonical specs matter, qualify scenarios as `<capability>/<requirement>` with observable `WHEN` and `THEN`. SDD verification counts every scenario and every `Done means` item.
- **Work groups:** a work group is one ordered, verifiable part of the plan. Each has `Files:`, `Skills:` (the smallest set of names from `oc-routing`, or `none`, never paths), and acyclic `Depends on:`. Work groups and `Depends on:` replace roadmaps, slices, readiness markers, and phase documents. Delivery skills (`oc-commits` and other Git skills) never appear in work groups. Tasks are actionable and verifiable.
- **Risks and open questions:** only real rollback conditions or hazards.
- **Execution guidance:** `Route: direct | SDD`, `Reason:`, and ``Run: `ejecuta el plan <path>` ``.

Former section mapping: Outcome → Goal; Scope In → Scope, Scope Out → Limits; Evidence → Reads; Files → Scope; Behavior → Scenarios; Verify → Done means; Dependencies → `Depends on:` and Risks; Skills → per work group.

Resources: `references/deep.md`, `references/edge-validation.md`, `references/question-economy.md`, `assets/plan-template.md`, `assets/discovery-template.md`.
