---
name: sdd-cold-verification
description: "Trigger: cold verification, verify run.md, SDD verification, behavior acceptance. Verify scoped implementation independently against assigned behavior scenarios."
license: MIT
metadata:
  author: andresnator
  version: "1.0.1"
  status: testing
---

# SDD Cold Verification

## Activation Contract

Load for independent, read-only acceptance of exact SDD run scenarios. Not for implementation or open-ended review; Judgment owns broader correctness, security, performance, and maintainability.

## Required Brief

- Exact `.ai/orchestration/runs/<slug>/` root and its `run.md`.
- Immutable plan path when `run.md` references one.
- Exact scenario ids from the run contract.
- Declared implementation scope.
- Fresh validation command or observable check.
- `working-tree` or an explicit diff range.

Missing or contradictory input blocks verification. Never infer a run root, plan, scope, scenario, or baseline.

## Method

1. Build a checklist containing every assigned scenario exactly once.
2. Inspect only the declared diff and scoped files, independently of the implementer's summary.
3. Trace each `WHEN` through its stimulus to the observable `THEN`; cite scoped `path:line` evidence or a focused check.
4. Run the named read-only validation fresh. Additional read-only probes may narrow a failure but never replace the required check.
5. For hardening or characterization, setup, stimulus, and assertion must independently detect the named regression. A green but tautological test is a failure. Run mutation or coverage only when the change names an available command.
6. Count every scenario. One unsupported or contradicted scenario makes the result fail.

## Boundaries

- Ignore unrelated working-tree changes and paths outside the brief.
- Do not turn conventions, security, performance, or design preferences into acceptance failures unless an assigned scenario or check requires them.
- Never edit, write state, ask, delegate, stage, commit, push, or mutate graph lifecycle.

## Output Contract

The caller's output contract wins. Return each failed scenario with evidence and final passed/total counts; clean results still cite exact evidence. Never return logs, code, diffs, or praise.
