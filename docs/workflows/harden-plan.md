# OpenCode Harden Plan Workflow

`/harden-plan` builds the plan that makes legacy or critical code safe to change before any refactor (Characterization-Driven Development, per Working Effectively with Legacy Code): characterization tests, unit tests, coverage, and mutation — without altering logic or observable behavior. It produces ready-for-sdd OpenSpec bundles executed later by the sdd `orchestraitor` (see `docs/plan-handoff.md`).

## Quick path

```bash
opencode run "/harden-plan src/main/java/com/acme/billing/InvoiceService.java"
# then, in an sdd session:
#   "ejecuta el plan harden-invoice-service"
# after archive, refactor on top of the safety net:
opencode run "/refactor-plan src/main/java/com/acme/billing/InvoiceService.java"
```

Bundles are saved to:

```text
.ai/refactor-planner/changes/<change>/{proposal.md, design.md, specs/<capability>/spec.md, tasks.md}
```

## What it does

- Same planner and machinery as `/refactor-plan` (target lock, inline scope + risk, analyzer fan-out, reducer, self-check), with plan kind `hardening`.
- Always runs the `behavior-safety`, `test-safety-net`, and `tooling` lenses; skips all structural lenses regardless of risk.
- Inspects test readiness in the build files: test framework, coverage reporter (e.g. JaCoCo), mutation tool (e.g. PIT/Stryker/mutmut per `tooling-compatibility-matrix`). Missing tooling becomes explicit group-1 enablement tasks with verify commands.
- Asks coverage/mutation thresholds at kickoff (risk-derived suggestion; "baseline only" available) and records them in `design.md` under "Verification gates".
- Fixed CDD task order: 1 tooling enablement → 2 minimal behavior-preserving seams (extract interface, parameterize constructor, wrap statics) → 3 characterization + unit tests → 4 coverage/mutation baseline vs thresholds.
- Spec deltas are ADDED characterization requirements; on archive they merge into canonical specs, so hardening progressively documents the system.

## What it does not do

- It does not refactor or restructure; structural findings go to Scope Out marked "candidate for /refactor-plan".
- It does not modify production paths, build files, source files, or tests — it only plans those edits; sdd executes them.
- It does not decide Mode/TDD/Judgment; the orchestraitor asks at adoption.

## Architecture

| Part | Role |
|---|---|
| Command | `domains/refactor/commands/harden-plan.md` routes `$ARGUMENTS` to `refactor-planner` with plan kind `hardening`. |
| Primary agent | `domains/refactor/agents/refactor-planner.md` — see its "Plan kinds" section for the hardening overrides. |
| Analysis subagent | `domains/refactor/agents/refactor-analyzer.md` — one generic read-only instance per unit × lens brief. |
| Tooling knowledge | `skills/tooling-audit` (gap detection with install tasks) + `skills/tooling-compatibility-matrix` (JaCoCo/PIT, Stryker, coverage.py/mutmut baselines and snippets). |
| Handoff | `docs/plan-handoff.md` — `Status: ready-for-sdd` marker + orchestraitor adoption. |
