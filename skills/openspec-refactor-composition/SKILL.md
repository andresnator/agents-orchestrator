---
name: openspec-refactor-composition
description: "Trigger: OpenSpec refactor composition, proposal, design, spec, tasks. Compose a single OpenSpec-style refactor plan document."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.0.0"
  status: in-progress
---

## Activation Contract
Load this skill when composing a single OpenSpec-style Markdown refactor plan from consolidated findings.

## Hard Rules

- Create one Markdown file, not an openspec/changes directory.
- Include proposal.md, design.md, specs/<capability>/spec.md, and tasks.md equivalents.
- Make tasks small, ordered, testable, reversible, and linked to evidence.
- Separate non-goals, follow-ups, and public API impacts.
- Preserve observable behavior; label functional changes as follow-up.
- Require evidence for every recommendation, or mark it as a hypothesis.
- Treat planner-provided `in_scope` and `follow_up` lists as authoritative.
- Treat planner-provided `detected_toolchain` as authoritative only when it is backed by repository evidence.
- Respect the requested `template`; do not mix the standard and legacy heading sets.
- Emit the title/metadata prelude exactly, including the `# ... Plan:` title line and a plain-text `Output file:` label followed by a backticked path value only.
- Keep all concrete follow-up/deferred/hypothesis/behavior-changing/public API/deprecation details only in Section 13 from `follow_up`.
- In Sections 1-12, use only the generic pointer: `Concrete follow-up/deferred/hypothesis details are excluded from Sections 1-12; see Section 13.`
- Keep Section 7 and tasks.md executable in-scope behavior-preserving work only from `in_scope`; never include concrete follow-up/deferred/hypothesis/behavior-changing/public API/deprecation details there.
- For `template: legacy-safety`, concrete tool names are permitted only in `## 7. Tooling Audit and Provisioning`, only when sourced from the supplied `tooling_audit` block with a `matrix_ref`, a compatibility check, a verify command, and `verify-latest-at-execution: true`; every other section must reference an install task by ID or name instead of independently naming a tool.

## Decision Gates

| Signal | Action |
|---|---|
| Item is in `in_scope` | It may inform Sections 1-12, backlog, sequence, and tasks. |
| Item is in `follow_up` | It may inform Section 13 only. |
| `detected_toolchain` is `unknown` | Keep validation and test-command wording generic. |
| `template` is `legacy-safety` | Use the reduced legacy heading set and focus on characterization coverage, seams, containment, and rollback. |
| Standard `tasks.md` is being written | Use one checkbox task per root line, then indented evidence/validation/rollback bullets. |
| A Section 6 category has no in-scope findings | Write `No findings.` instead of repeating the Section 13 pointer there. |
| Recommendation is cosmetic or speculative | Omit it unless maintainability benefit is clear. |

## Execution Steps

1. Start from `in_scope`, `follow_up`, `detected_toolchain`, target metadata, tests, prior plans, reviewer lens coverage, and safety constraints.
2. If `template` is standard, create exactly the 14 standard top-level sections and include `change-id`, `proposal.md`, `design.md`, `specs/<capability>/spec.md`, and `tasks.md`.
3. If `template` is `legacy-safety`, create exactly the 12 legacy top-level sections centered on target lock, unit breakdown, characterization coverage, seams, tooling provisioning, backlog, sequence, validation, rollback, and follow-up.
4. For the standard template, write Sections 1-12 only from `in_scope`.
5. For the standard template, write Section 13 only from `follow_up`; if an `in_scope` section had items moved out, leave at most one generic Section 13 pointer in that top-level section and never repeat it across multiple Section 6 subsections.
6. For the legacy template, write Sections 1-10 only from `in_scope` and Section 11 only from `follow_up`. Section 2 must echo the `plan_target` lock verbatim; Section 3 must enumerate one subsection per supplied unit; Section 7 must render the `tooling_audit` block or the literal `No tooling gaps detected.`
7. Keep executable backlog work behavior-preserving and sourced only from `in_scope`.
8. Link every task or sequence item to evidence, validation, and rollback.
9. Use exact test commands only when `detected_toolchain` is backed by repository evidence; otherwise keep validation wording generic.
10. For the standard template, verify the title/metadata prelude exists exactly, `Output file:` is not wrapped in backticks, `### tasks.md` appears exactly once, and `tasks.md` uses root checkbox lines plus indented support bullets only.
11. Ensure Section 14 contains only one approved-schema YAML block and no provisional safety prose.

## Output Contract

Return the complete Markdown document only. Do not write files and do not return reviewer YAML.

## References

None.
