# OpenCode Refactor Plan Harness

This project-local OpenCode harness adds `/refactor-plan`, a plan-only workflow that analyzes a code class, package, or module and writes one risk-gated OpenSpec-style Markdown refactor plan.

## Quick path

```bash
opencode run "/refactor-plan src/main/java/com/acme/billing/InvoiceService.java"
opencode run "/refactor-plan src/main/java/com/acme/billing"
opencode run "/refactor-plan mode=smoke src/main/java/com/acme/billing/LegacyOrderProcessor.java"
```

The `mode=smoke` flag writes a stub 17-section plan through lint for fast harness validation. Smoke output is not executable by `/refactor-execute`.

The generated plan is saved to:

```text
.ia-refactor/plan/YYYYMMDD/<target-name>.md
```

## What it does

- Freezes a single `plan_target` lock for the whole run.
- Runs `scope-analyzer`, caps the target at 8 units, then runs `risk-assessor`.
- Selects depth from risk: `low -> light`, `medium -> standard`, `high|critical -> deep`.
- Uses reviewer lenses only when depth requires them.
- Produces one 17-section plan with `Risk:`, `Depth:`, OpenSpec-style change sections, and `## 15. Execution Contract`.
- Runs `plan-lint.sh` and `refactor-safety-gate-reviewer` before completion.

## What it does not do

- It does not refactor code.
- It does not modify production paths, build files, source files, or tests.
- It does not create real `openspec/changes/**` artifacts.
- It does not mix functional changes into refactoring tasks.

## Architecture

| Part | Role |
|---|---|
| Command | `domains/refactor/commands/refactor-plan.md` receives `$ARGUMENTS` and routes to `refactor-planner`. |
| Primary agent | `domains/refactor/agents/refactor-planner.md` orchestrates scope, risk, reviewer fan-out, composition, safety, lint, and saving. |
| Analysis workers | `scope-analyzer`, `risk-assessor`, `behavior-characterizer`, `dependency-seam-finder`, `test-planner`, `architecture-reviewer`, and `tooling-auditor` provide locked, read-only safety analysis. |
| Reviewer subagents | Nine focused lenses load `reviewer-output-contract` and return compact YAML findings or `nf: "<reason>"`. |
| Composer subagent | `refactor-openspec-composer` creates the unified 17-section plan. |
| Safety subagent | `refactor-safety-gate-reviewer` blocks unsafe, speculative, or non-evidence-based plans. |
| Skills | `skills/*/SKILL.md` provides reusable single-responsibility review instructions; `domains/*/skills/*` declare domain usage by symlink. |

## Depths

| Risk | Depth | Behavior |
|---|---|---|
| `low` | `light` | No reviewer panel; the planner writes minimal findings from scope and risk evidence. |
| `medium` | `standard` | Runs selected reviewer lenses. Naming and type-contract lenses always run; other lenses follow target-size and collaborator heuristics. |
| `high` or `critical` | `deep` | Runs behavior, seam, test, architecture, tooling workers plus all nine reviewer lenses. |

Sections 8 and 9 always exist. When characterization or tooling is not required at the selected depth, the section contains exactly:

```text
Not required at depth: <depth>.
```

## Required Plan Shape

Every plan uses one title/prelude plus exactly 17 sections:

```text
# Refactor Plan: <target-name>
Generated at: <YYYY-MM-DD>
Target: `<target>`
Output file: `.ia-refactor/plan/YYYYMMDD/<target-name>.md`
Risk: <low | medium | high | critical>
Depth: <light | standard | deep | smoke>
```

Sections:

1. Executive Summary
2. Target and Scope
3. Risk and Depth Assessment
4. Observations
5. Goals
6. Non-Goals
7. Findings by Category
8. Characterization Coverage Plan
9. Tooling Audit
10. Backlog
11. Sequence
12. OpenSpec-Style Change
13. Validation
14. Risk & Rollback
15. Execution Contract
16. Follow-up
17. Safety Gate Result

## Execution Contract

Section 15 is the producer-to-executor handoff. It must tell a future executor how to:

- confirm Section 17 has `safety_review.status: "approved"`;
- establish the baseline validation from Section 13;
- execute Section 12 `tasks.md` in order;
- re-check evidence before each task;
- log deviations as `{task, status, reason, evidence}`;
- use TCR: commit green task validations and revert red validations;
- stop after repeated reverts, baseline failure, or target drift.

## Validation

Use the portable linter:

```bash
sh skills/refactor-plan-safety-gates/assets/plan-lint.sh .ia-refactor/plan/YYYYMMDD/<target-name>.md
```

The planner must run the linter before safety review and again before finishing.

## Layout

- `domains/refactor/commands/*.md` for commands.
- `domains/refactor/agents/*.md` for primary agents and subagents.
- `domains/refactor/plugins/*.ts` for OpenCode plugins installed by `installers/opencode.sh`.
- `skills/<name>/SKILL.md` for skill bodies and `domains/<domain>/skills/<name>` symlinks for domain usage.

## Catalog Notes

The plan linter travels with the `refactor-plan-safety-gates` skill under `assets/plan-lint.sh`.
