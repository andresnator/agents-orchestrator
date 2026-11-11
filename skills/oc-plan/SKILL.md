---
name: oc-plan
description: "Trigger: light plan, quick plan, plan rápido, plan light, deep plan, plan profundo, planificar a fondo, evidence-first plan, planificacion basada en evidencia, discovery plan, wayfinder, explore an idea, convert this discovery into a plan, execution plan, executable plan. Planner with light and deep modes (Wayfinder discovery included) that drafts one neutral IDSD plan for direct or SDD execution from one shared template."
license: MIT
metadata:
  author: andresnator
  version: "5.0.0"
  status: testing
---

# Plan

## Intent

- **Goal:** Exactly one planning artifact: a light IDSD plan, a deep evidence-backed IDSD plan, or a Wayfinder discovery, always in the shape of `assets/plan-template.md` (plans) or `assets/discovery-template.md` (discoveries).
- **Limits:** Write only under `.ai/**`; never edit production code, tests, or build files; never build, install, test, stage, commit, or push. Never load implementation skill bodies.
- **Fails if:** a plan misses an ICE field or `Method` → `Approach`, `Work groups`, `Execution guidance`; a claim lacks `path:line` or a `hypothesis` mark; more than one artifact is written; risky work is planned light instead of escalated to deep.

## Context

- **Reads:** the mode reference below, `references/format.md` for every plan, `oc-routing` for skill names, and only the repository evidence the mode allows.
- **Never reads:** implementation skill bodies; unrelated modules; web sources.
- **Persona:** pragmatic, evidence-first planner writing for a human and an executor.
- **Scope:**

  | Mode | Triggers | Use for | Follow |
  | --- | --- | --- | --- |
  | light | `light plan`, `quick plan`, `plan rápido`, `plan light` | small or medium localized, reversible work | `references/light.md` |
  | deep | `deep plan`, `plan profundo`, `planificar a fondo`, `evidence-first plan`, `planificacion basada en evidencia`, `discovery plan`, `wayfinder`, `explore an idea`, `convert this discovery into a plan` | large, risky, cross-cutting, or open-ended work | `references/deep.md` |
  | format | `execution plan`, `executable plan`; callers (`oc-grill` plan mode, planless SDD `run.md`) | drafting the plan file itself | `references/format.md` |

## Expectations

- **Scenarios:**
  - WHEN the mode is explicit THEN follow its reference only.
  - WHEN the mode is unstated THEN pick light for localized reversible work, deep otherwise; a light run that meets SDD-level risk stops and switches to deep.
  - WHEN any plan is written THEN apply `references/format.md` (collision, delivery, and section rules) and `assets/plan-template.md`.
- **Done means:** the mode reference's `Done means`, the artifact path when saved, and ``ejecuta el plan <path>`` for plans.
- **Quality needs:** proportional content; only information that changes execution.

## Method

Resources: `references/light.md`, `references/deep.md`, `references/format.md`, `references/edge-validation.md`, `references/question-economy.md`, `assets/plan-template.md`, `assets/discovery-template.md`.
