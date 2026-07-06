---
name: refactor-plan-safety-gates
description: "Trigger: refactor safety gates, safe plan, evidence, rollback. Review refactor plans for safety and evidence."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.0.0"
  status: in-progress
---

## Activation Contract
Load this skill when reviewing code refactor plans for: refactor safety gates, safe plan, evidence, rollback.

## Hard Rules

- Block behavior changes disguised as refactors.
- Block plans that rename, merge, omit, or reorder the required 14 OpenSpec-style sections.
- Block plans that omit `proposal.md`, `design.md`, `specs/<capability>/spec.md`, or `tasks.md`.
- Block plans that use `Output:` instead of exact header label `Output file:`.
- Block plans whose `tasks.md` entries are not ordered Markdown checkbox tasks (`- [ ]`) through validation.
- Block untested risky legacy refactors.
- Block findings without evidence or explicit hypothesis labels, especially unsupported logging/audit/observability claims presented as facts.
- Mechanically reject any Section 13 `### Follow-up` block missing a literal `Evidence:` or `Hypothesis:` field.
- Block invented or unsupported concrete tools, libraries, frameworks, dependencies, plugins, and commands unless detected in repository evidence or explicitly supplied.
- Block missing validation, rollback, or oversized tasks.
- Block speculative abstractions and cosmetic-only changes without benefit.
- Preserve observable behavior; label functional changes as follow-up.
- Block in-scope public API changes unless explicit approval exists; otherwise require follow-up/deprecation planning.
- Block concrete follow-up/deferred/hypothesis/behavior-changing/public API/deprecation details outside `## 13. Follow-up Plans`; Section 13 is exclusive for those details, and Sections 1-12 may only use the generic pointer to Section 13.
- Block public/API/deprecation/follow-up rows in `## 7. Prioritized Refactor Backlog` or `tasks.md`.
- Block low-confidence, conditional, hypothesis, domain-terminology, or unverified rename rows in Section 7 or `tasks.md`.
- Block Section 7 content that is not current in-scope behavior-preserving executable work.
- Require evidence for every recommendation, or mark it as a hypothesis.
- For `template: legacy-safety`, block tooling gaps reported in `## 7. Tooling Audit and Provisioning` that lack a matching install task with a verify command.
- For `template: legacy-safety`, block any install task in Section 7 missing a verify command, a compatibility check, or the literal `verify-latest-at-execution: true`.
- For `template: legacy-safety`, block target-lock drift: any worker-echoed `target_path`/`target_slug`/`unit_slug` that does not match the `plan_target` block echoed in `## 2. Target and Safety Scope`.

## Decision Gates

| Signal | Action |
|---|---|
| Concrete evidence exists | Create a finding with file, lines, symbol, benefit, validation, and rollback. |
| Evidence is incomplete | Mark as hypothesis and lower confidence. |
| Section 13 `### Follow-up` block lacks literal `Evidence:` or `Hypothesis:` | Mechanically reject the plan. |
| Concrete tool/library/dependency lacks repo evidence | Block or replace with generic wording. |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |

## Execution Steps

1. Review the complete Markdown plan, not isolated findings.
2. Treat the existing `## 14. Safety Gate Review Result` block as provisional pipeline state. Judge the plan from Sections 1-13 and produce the final safety verdict the planner should write back into Section 14.
3. Stay scoped to the supplied Markdown artifact plus any directly cited repository evidence already present in that artifact or prompt. Do not search for helper scripts, build tools, or unrelated files unless the caller explicitly asked for that verification.
4. Check behavior preservation, evidence, hypothesis labels, validation, rollback, task size, and output path.
5. Verify Section 13 exclusivity: concrete follow-up/deferred/hypothesis/behavior-changing/public API/deprecation details appear only in `## 13. Follow-up Plans`, and outside Section 13 the plan uses only the generic pointer. Also mechanically verify every Section 13 `### Follow-up` block contains a literal `Evidence:` or `Hypothesis:` field.
6. Verify Section 7 and `tasks.md` contain only current in-scope behavior-preserving executable work, with no public/API/deprecation/follow-up rows and no low-confidence, conditional, hypothesis, domain-terminology, or unverified rename rows.
6a. For `template: legacy-safety`, verify `## 7. Tooling Audit and Provisioning` either states `No tooling gaps detected.` or lists install tasks that each carry a verify command, a compatibility check, and `verify-latest-at-execution: true`; verify tool names appear only in Section 7 or as install-task references elsewhere. Verify the `plan_target` block echoed in Section 2 matches every worker-echoed target/unit identifier in the plan body.
7. Return blockers and required fixes when any gate fails.
8. Validate safety YAML uses only `status`, `blockers`, `required_fixes`, and `final_safety_level`; status must be `approved` or `needs_changes`.
9. Block invented concrete tools, libraries, frameworks, dependencies, plugins, and commands unless detected in repository evidence or explicitly supplied.
10. Approve only when the plan is safe, incremental, verifiable, non-speculative, and free of Section 13 leakage into executable backlog or tasks.

## Output Contract

Return only `safety_review` YAML with exactly `status`, `blockers`, `required_fixes`, and `final_safety_level`. Do not return conditional approvals; use `needs_changes` until blockers are fixed, then `approved`. Name Section 13 leakage, Section 7/tasks exclusions, and low-confidence or hypothesis rename leakage explicitly in blockers when present.

## References

None.

## Assets

- `assets/plan-lint.sh` is the portable plan linter for generated refactor and legacy-safety plans.
