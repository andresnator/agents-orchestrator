# OpenCode Refactor Plan Workflow

`/refactor-plan` analyzes a code class, package, or module and produces one or more ready-for-sdd OpenSpec change bundles. Execution is not part of this workflow: bundles are adopted and executed by the sdd `orchestraitor` (see `docs/plan-handoff.md`).

## Quick path

```bash
opencode run "/refactor-plan src/main/java/com/acme/billing/InvoiceService.java"
opencode run "/refactor-plan src/main/java/com/acme/billing"
# then, in an sdd session:
#   "ejecuta el plan refactor-invoice-service"
```

Bundles are saved to:

```text
.ai/refactor-planner/changes/<change>/{proposal.md, design.md, specs/<capability>/spec.md, tasks.md}
```

## What it does

- Freezes a `plan_target` lock for the whole run.
- Scopes units and classifies risk inline (`scope-analysis`, `risk-assessment` skills), then asks one kickoff round (depth override; bundle split when >1 unit).
- Risk-gates the analysis: low → no fan-out; medium → core lenses; high/critical → full lens catalog.
- Fans out the generic read-only `refactor-analyzer` subagent in parallel (unit × lens group, capped per message).
- Consolidates findings (dedupe, contradiction handling, priority) into `in_scope` vs `follow_up`.
- Composes the bundle(s) with the `sdd-draft-*` templates; spec deltas are mostly ADDED behavior-preservation requirements whose scenarios characterize current behavior.
- Self-checks the bundle (marker line, artifact completeness, task shape, evidence) before reporting.

## What it does not do

- It does not refactor or execute anything; `/refactor-execute` no longer exists.
- It does not modify production paths, build files, source files, or tests.
- It does not decide Mode/TDD/Judgment; the orchestraitor asks at adoption.
- It ignores legacy `.ia-refactor/**` plans (frozen history, not executable).

## Architecture

| Part | Role |
|---|---|
| Command | `domains/refactor/commands/refactor-plan.md` routes `$ARGUMENTS` to `refactor-planner`. |
| Primary agent | `domains/refactor/agents/refactor-planner.md` scopes, risk-gates, fans out, consolidates, composes, self-checks. |
| Analysis subagent | `domains/refactor/agents/refactor-analyzer.md` — one generic read-only instance per unit × lens brief. |
| Handoff | `docs/plan-handoff.md` — `Status: ready-for-sdd` marker + orchestraitor adoption. |
| Write boundary | Planner permissions allow writes only under `.ai/refactor-planner/changes/**`; the analyzer is read-only. |
