---
name: openspec-refactor-composition
description: "Trigger: OpenSpec refactor composition, proposal, design, spec, tasks. Compose the unified 17-section refactor plan document."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "3.0.0"
  status: in-progress
---

# OpenSpec Refactor Composition

## Activation Contract

Load this skill when composing a single OpenSpec-style Markdown refactor plan from consolidated findings.

## Hard Rules

- Create one Markdown file, not an openspec/changes directory.
- Use the unified 17-section template only.
- Include proposal.md, design.md, specs/<capability>/spec.md, and tasks.md equivalents in Section 12.
- Echo the planner-supplied `plan_target` block verbatim in Section 2.
- Include `Risk:` and `Depth:` in the prelude.
- Make tasks small, ordered, testable, reversible, and linked to evidence.
- Separate non-goals, follow-ups, and public API impacts.
- Preserve observable behavior; label functional changes as follow-up.
- Require evidence for every recommendation, or mark it as a hypothesis.
- Treat planner-provided `in_scope` and `follow_up` lists as authoritative.
- Treat planner-provided `detected_toolchain` as authoritative only when backed by repository evidence.
- Keep concrete follow-up/deferred/hypothesis/behavior-changing/public API/deprecation details only in Section 16.
- Keep Sections 10, 11, and `tasks.md` executable, behavior-preserving, and sourced only from `in_scope`.
- Keep Sections 8 and 9 present at all depths; when not required, render exactly `Not required at depth: <depth>.`

## Decision Gates

| Signal | Action |
|---|---|
| Item is in `in_scope` | It may inform Sections 1-15, backlog, sequence, and tasks. |
| Item is in `follow_up` | It may inform Section 16 only. |
| `detected_toolchain` is `unknown` | Keep validation and test-command wording generic. |
| Depth is `light` | Compose from scope and risk evidence only. |
| Depth is `standard` | Compose from scope, risk, and selected lens findings. |
| Depth is `deep` | Compose from analysis workers, full lenses, characterization, and tooling audit. |
| A Section 7 category has no in-scope findings | Write `No findings.` |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |

## Execution Steps

1. Start from `plan_target`, `risk`, `depth`, `in_scope`, `follow_up`, `detected_toolchain`, `reviewer_lens_coverage`, and safety constraints.
2. Create exactly the 17 top-level sections required by the planner.
3. Render Section 2 with the target lock YAML.
4. Render Section 3 with risk, depth, and evidence.
5. Render Section 4 with analysis and reviewer coverage.
6. Render Section 7 with all ten required subsections.
7. Render Sections 8 and 9 with concrete plans at `deep`, or the deterministic placeholder when not required.
8. Render Section 12 with proposal/design/spec/tasks subsections.
9. Render Section 15 as the producer-to-executor contract.
10. Render Section 16 only from `follow_up`.
11. Ensure Section 17 contains only one approved-schema YAML block and no prose.

## Output Contract

Return the complete Markdown document only. Do not write files and do not return reviewer YAML.

## References

None.
