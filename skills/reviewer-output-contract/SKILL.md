---
name: reviewer-output-contract
description: "Trigger: reviewer output, compact YAML findings, nf. Enforce the shared refactor-plan reviewer schema and noise caps."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: in-progress
---

## Activation Contract
Load this skill in any `/refactor-plan` reviewer agent before lens-specific analysis.

## Hard Rules

- Stay plan-only. Never modify files.
- Return only YAML.
- Do not invent issues. Anchor findings in concrete file, line, symbol, and code evidence.
- Do not propose functional behavior changes as refactors.
- Emit at most 5 findings. Keep the highest-priority findings and add one `overflow:` line when more relevant findings exist.
- On code under 30 lines, do not emit cosmetic-only `P3` findings unless `conf >= 0.9`.
- Use confidence anchors: `0.9+` direct evidence, `0.5-0.8` structural inference, `<0.5` only with `hypothesis:` evidence text.

## Decision Gates

| Situation | Action |
|---|---|
| Lens does not apply | Return `nf: "<reason>"` |
| Evidence is incomplete | Prefix `ev` with `hypothesis:` and lower `conf` |
| Validation or rollback is obvious mechanical default | Omit the field; planner may expand it during consolidation |

## Execution Steps

1. Analyze only the assigned lens.
2. Keep findings compact and non-lossy.
3. Use this schema:

```yaml
findings:
  - id: "<lens>-<n>"
    loc: "path:line-line#symbol"
    ev: "<=120 chars"
    prob: "<=80 chars"
    rec: "<=80 chars"
    ben: "<=80 chars"
    risk: "L|M|H|C"
    effort: "S|M|L"
    pri: "P1|P2|P3"
    conf: 0.0
    tests_first: true
    validation: "optional concise step"
    rollback: "optional concise step"
    safe: "T|M|F"
overflow: "<optional summary of omitted lower-priority findings>"
```

4. Map `safe` as `T=test-first`, `M=mechanical`, `F=follow-up`.

## Output Contract

Return exactly one YAML document using either:

```yaml
findings:
  - id: "<lens>-<n>"
    loc: "path:line-line#symbol"
    ev: "concise evidence"
    prob: "concise issue"
    rec: "concise recommendation"
    ben: "concise benefit"
    risk: "L|M|H|C"
    effort: "S|M|L"
    pri: "P1|P2|P3"
    conf: 0.0
    tests_first: true
    safe: "T|M|F"
```

with actual finding items, or:

```yaml
nf: "<reason>"
```

## References

- the refactor-planner agent
- the refactor-safety-gate-reviewer agent
