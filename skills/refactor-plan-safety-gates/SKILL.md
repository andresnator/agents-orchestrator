---
name: refactor-plan-safety-gates
description: "Trigger: refactor safety gates, safe plan, evidence, rollback. Review unified 17-section refactor plans for safety and evidence."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "3.0.1"
  status: in-progress
---

# Refactor Plan Safety Gates

## Activation Contract

Load this skill when reviewing code refactor plans for safety, evidence, rollback, and executor readiness.

## Hard Rules

- Block behavior changes disguised as refactors.
- Block plans that rename, merge, omit, or reorder the required 17 sections.
- Block plans that omit `Risk:`, `Depth:`, the `plan_target` lock, Section 15 execution contract, or Section 17 safety YAML.
- Block plans whose Section 3 omits `risk:` and `depth:` entries matching the prelude.
- Block plans that omit `proposal.md`, `design.md`, `specs/<capability>/spec.md`, or `tasks.md`.
- Block plans that use `Output:` instead of exact header label `Output file:`.
- Block plans whose `tasks.md` entries are not ordered checkbox tasks (`- [ ]`) with evidence, validation, and rollback.
- Block untested risky legacy refactors.
- Block findings without evidence or explicit hypothesis labels.
- Block invented or unsupported concrete tools, libraries, frameworks, dependencies, plugins, and commands unless detected in repository evidence or explicitly supplied.
- Block missing validation, rollback, or oversized tasks.
- Block speculative abstractions and cosmetic-only changes without benefit.
- Preserve observable behavior; label functional changes as follow-up.
- Block in-scope public API changes unless explicit approval exists; otherwise require follow-up/deprecation planning.
- Block concrete follow-up/deferred/hypothesis/behavior-changing/public API/deprecation details outside Section 16.
- Block public/API/deprecation/follow-up rows in Section 10 backlog, Section 11 sequence, or Section 12 `tasks.md`.
- Block low-confidence, conditional, hypothesis, domain-terminology, or unverified rename rows in executable backlog or tasks.
- Require Sections 8 and 9 to exist at every depth and use the exact placeholder `Not required at depth: <depth>.` when not required.
- Require Sections 8 and 9 to contain concrete content, never the placeholder, at depth `deep`.
- Block target-lock drift between Section 2 and worker-echoed target or unit identifiers.

## Decision Gates

| Signal | Action |
|---|---|
| Concrete evidence exists | Create a finding with file, lines, symbol, benefit, validation, and rollback. |
| Evidence is incomplete | Mark as hypothesis and move to Section 16. |
| Concrete tool/library/dependency lacks repo evidence | Block or replace with generic wording. |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |
| Depth is `light` or `standard` and Section 8/9 was not required | Require the deterministic placeholder. |

## Execution Steps

1. Review the complete Markdown plan, not isolated findings.
2. Treat existing Section 17 as provisional pipeline state. Judge Sections 1-16 and produce the final safety verdict the planner should write back into Section 17.
3. Stay scoped to the supplied Markdown artifact plus cited repository evidence already present in that artifact or prompt.
4. Check behavior preservation, evidence, hypothesis labels, validation, rollback, task size, and output path.
5. Verify Section 16 exclusivity.
6. Verify Sections 10, 11, and `tasks.md` contain only current in-scope behavior-preserving executable work.
7. Verify Section 15 gives the executor enough constraints to reject unsafe plans and execute tasks in order.
8. Return blockers and required fixes when any gate fails.
9. Validate safety YAML uses only `status`, `blockers`, `required_fixes`, and `final_safety_level`; status must be `approved` or `needs_changes`.

## Output Contract

Return only `safety_review` YAML with exactly `status`, `blockers`, `required_fixes`, and `final_safety_level`. Do not return conditional approvals; use `needs_changes` until blockers are fixed, then `approved`.

## Assets

- `assets/plan-lint.sh` is the portable plan linter for generated refactor plans.
