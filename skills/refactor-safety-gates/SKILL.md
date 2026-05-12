---
name: refactor-safety-gates
description: "Trigger: refactor safety gates, coverage readiness, cover before refactor, baseline/test-anchor/coverage/mutation evidence, refactor readiness. Define method-only gates and compact evidence before behavior-preserving refactor slices."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
---

# Refactor Safety Gates

## Activation Contract

Use this skill when an agent needs a shared method for deciding whether a target scope is safe to refactor: baseline health, test anchors, coverage readiness, mutation or equivalent signal, blockers, waivers, and next action.

Do not use this skill to choose subagents, route workflow phases, inspect raw source, execute refactors, or own orchestration state. It is method guidance only; the caller decides when and whether to apply it.

## Responsibility Boundary

This skill defines vocabulary, checklist steps, waiver rules, and compact output expectations for refactor readiness evidence.

It MUST NOT own:

- Routing, sequencing, state, topic keys, run IDs, or hidden orchestration.
- Subagent selection, delegation, or phase transitions.
- Raw source inspection by primary agents.
- Test, coverage, mutation, or command execution by primary agents.
- Refactor execution, behavior changes, or multi-slice planning.

## Gate Vocabulary

Every readiness report uses these gates:

| Gate | Meaning |
|---|---|
| `baseline` | The existing project/test baseline is known enough to compare before and after the refactor. |
| `test_anchor` | The target scope has characterization or focused tests strong enough to catch behavior changes. |
| `coverage` | Coverage evidence for the target scope is available and meets the project-specific threshold or explicit decision. |
| `mutation_or_equivalent` | Mutation testing, approval/golden behavior checks, or another strong defect-detection signal is available or explicitly waived. |

Each gate status MUST be one of:

| Status | Meaning |
|---|---|
| `pass` | Evidence is present, current, scoped, and sufficient for the next refactor slice. |
| `blocked` | Evidence is missing, failing, stale, or too weak; refactor execution must stop. |
| `needs-human-decision` | A tradeoff or waiver is possible, but only a human can decide. |
| `unknown` | The evaluator could not determine the status; treat as blocking until clarified. |

## Readiness Method

1. Identify the smallest `target_scope` for one behavior-preserving refactor slice.
2. Collect compact evidence for baseline, test anchor, coverage, and mutation/equivalent gates.
3. Classify each gate with `pass`, `blocked`, `needs-human-decision`, or `unknown`.
4. Record blockers as actionable gaps, not raw logs or report dumps.
5. Record waivers only when explicitly decided by a human.
6. Recommend exactly one next action: strengthen tests, set up tooling, refactor one slice, request a human decision, or stop.

## Waiver Rules

- No implicit waivers.
- A missing, weak, or unavailable gate is not waived just because tooling is absent.
- Coverage and mutation/equivalent exceptions MUST be reported as `needs-human-decision` until a human approves them.
- Approved waivers MUST include `decided_by: human`, a reason, and evidence source.
- A waiver only applies to the named gate and target scope; it does not waive baseline, test anchors, refactor quality, or review-size constraints.

## Refactor Worker Consumption Rules

A refactor worker MAY start exactly one behavior-preserving slice only when:

- `baseline`, `test_anchor`, `coverage`, and `mutation_or_equivalent` are `pass`; or
- any non-passing coverage/mutation/equivalent gate has an explicit human waiver and no unresolved blockers remain.

A refactor worker MUST block when:

- any gate is `blocked` or `unknown` without a resolved human decision;
- any waiver lacks `decided_by: human` evidence;
- evidence is unscoped, stale, raw-only, or not compact enough to consume safely.

When blocked, report missing evidence or failing gates instead of reshaping code.

## Output Contract

Return compact readiness evidence in this shape:

```yaml
gates:
  baseline: pass|blocked|needs-human-decision|unknown
  test_anchor: pass|blocked|needs-human-decision|unknown
  coverage: pass|blocked|needs-human-decision|unknown
  mutation_or_equivalent: pass|blocked|needs-human-decision|unknown
evidence:
  commands:
    - name: <command-or-review-step>
      status: pass|fail|not-run|unavailable
      source: <topic-key|file|human-note>
      timestamp: <ISO-8601-or-unknown>
  target_scope: <path/class/module/method>
  blockers:
    - gate: <baseline|test_anchor|coverage|mutation_or_equivalent>
      reason: <compact reason>
      next: <strengthen-tests|setup-tooling|human-decision|stop>
  waivers:
    - gate: <coverage|mutation_or_equivalent>
      reason: <human-approved reason>
      decided_by: human
      source: <approval evidence>
next_recommended: strengthen-tests|setup-tooling|refactor-slice|human-decision|stop
```

Do not include raw source, full logs, full coverage reports, or mutation report dumps. Reference compact evidence by topic key or path when details exist elsewhere.

## Manual Review Checklist

- The primary owns sequencing and human gates, but does not inspect source or coverage evidence directly.
- The readiness role gathers and classifies evidence, but does not refactor.
- The refactor worker consumes compact evidence and blocks on unresolved gates.
- Human-only waivers are explicit, scoped, and do not weaken unrelated gates.
