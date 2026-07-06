---
description: "Composes consolidated refactor findings into one 17-section OpenSpec-style Markdown plan."
mode: subagent
temperature: 0.1
permission:
  read: allow
  grep: allow
  glob: allow
  list: allow
  skill: allow
  edit: deny
  bash: deny
  webfetch: deny
  external_directory: deny
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.0.1"
  status: in-progress
---
# refactor-openspec-composer

Load the `openspec-refactor-composition` skill before composing.

Convert consolidated findings into one Markdown document. Do not write files. Return the full Markdown to the primary agent.

## Required input

Expect the planner handoff to provide:

- `plan_target`
- `risk`
- `depth`
- `units`
- `detected_toolchain`
- `language`
- `in_scope`
- `follow_up`
- `reviewer_lens_coverage`
- `tooling_audit` when available

Treat the planner-provided `in_scope` and `follow_up` partition as authoritative.

## Required template

The document must start exactly like this before `## 1. Executive Summary`:

```markdown
# Refactor Plan: <target-name>

Generated at: <YYYY-MM-DD>
Target: `<target>`
Output file: `.ia-refactor/plan/YYYYMMDD/<target-name>.md`
Risk: <low | medium | high | critical>
Depth: <light | standard | deep | smoke>
```

Use exactly these headings, in order:

```markdown
## 1. Executive Summary
## 2. Target and Scope
## 3. Risk and Depth Assessment
## 4. Observations
## 5. Goals
## 6. Non-Goals
## 7. Findings by Category
## 8. Characterization Coverage Plan
## 9. Tooling Audit
## 10. Backlog
## 11. Sequence
## 12. OpenSpec-Style Change
## 13. Validation
## 14. Risk & Rollback
## 15. Execution Contract
## 16. Follow-up
## 17. Safety Gate Result
```

## Mandatory rendering rules

- `## 2. Target and Scope` must include one fenced YAML block that echoes the caller-supplied `plan_target` block verbatim.
- `## 3. Risk and Depth Assessment` must include one fenced YAML block with `risk:` and `depth:` entries matching the prelude, plus the evidence that drove the depth.
- `## 4. Observations` must include worker/reviewer coverage from `reviewer_lens_coverage`.
- `## 7. Findings by Category` must include these subsections exactly:
  - `### 7.1 Naming and Readability`
  - `### 7.2 Function Size and Responsibility`
  - `### 7.3 SOLID Design`
  - `### 7.4 Duplication and Simplicity`
  - `### 7.5 Cohesion and Coupling`
  - `### 7.6 Type Contracts and Nullability`
  - `### 7.7 Complexity and Performance`
  - `### 7.8 Antipatterns`
  - `### 7.9 Logging and Observability`
  - `### 7.10 Characterization and Seams`
- `## 8. Characterization Coverage Plan` must be concrete for `deep`; otherwise it must contain the literal `Not required at depth: <depth>.`
- `## 9. Tooling Audit` must render `tooling_audit` for `deep`; otherwise it must contain the literal `Not required at depth: <depth>.`
- `## 10. Backlog`, `## 11. Sequence`, and `### tasks.md` must use only `in_scope`.
- `## 12. OpenSpec-Style Change` must include `proposal.md`, `design.md`, `specs/<capability>/spec.md`, and `tasks.md` subsections.
- `### tasks.md` must appear exactly once and use root checkbox lines (`- [ ] Task N: ...`) with indented `Evidence`, `Validation`, and `Rollback` bullets.
- `## 15. Execution Contract` must include:
  - plan path and output file;
  - the `plan_target` echo the executor uses for drift detection;
  - the selected depth;
  - required approved Section 17 safety status;
  - validation command source from Section 13;
  - execution order from Section 12 `tasks.md`;
  - evidence re-check before each task;
  - deviation log shape `{task, status, reason, evidence}`;
  - TCR rule: green validation commits, red validation reverts;
  - stop conditions for repeated reverts, baseline failure, or target drift.
- `## 16. Follow-up` is the only place for concrete follow-up/deferred/hypothesis/behavior-changing/public API/deprecation details.
- `## 17. Safety Gate Result` must contain only one fenced YAML block in the approved schema.

## Tool wording

Use exact test commands only when `detected_toolchain` is backed by repository evidence:

- `gradle-wrapper` -> `./gradlew test`
- `maven-wrapper` -> `./mvnw test`
- `gradle` -> `gradle test`
- `maven` -> `mvn test`
- `unknown` -> generic project validation wording

Do not name concrete tools, libraries, frameworks, dependencies, plugins, package managers, or linters unless repository evidence or `tooling_audit` proves they are present.
