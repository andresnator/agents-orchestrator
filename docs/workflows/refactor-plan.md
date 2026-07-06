# OpenCode Refactor Plan Harness

This project-local OpenCode harness adds `/refactor-plan`, a plan-only workflow that analyzes a code class, package, or module and writes one OpenSpec-style Markdown refactor plan.

## Quick path

```bash
opencode run "/refactor-plan src/main/java/com/acme/billing/InvoiceService.java"
opencode run "/refactor-plan src/main/java/com/acme/billing"
opencode run "/refactor-plan src/main/java/com/acme"
opencode run "/legacy-safety-plan src/main/java/com/acme/billing/LegacyOrderProcessor.java"
opencode run "/legacy-safety-plan mode=smoke src/main/java/com/acme/billing/LegacyOrderProcessor.java"
```

The `mode=smoke` (or `--smoke`) flag skips the full worker/reviewer fan-out and writes a stub 12-section plan straight through lint, for fast harness validation.

The generated plan is saved to:

```text
.ia-refactor/plan/YYYYMMDD/<target-name>.md
```

For a class, `<target-name>` is usually the class name. For a package or module, it is the last meaningful path segment. If names collide, the planner must include more sanitized path context.

## What it does

- Detects target type: class, package, or module.
- Finds relevant source files, collaborators, callers, and tests.
- Runs specialized review subagents for refactor findings.
- Consolidates findings into one OpenSpec-style plan with proposal, design, spec, and tasks sections.
- Runs a safety gate review before saving.

## What it does not do

- It does not refactor code.
- It does not modify production paths such as `src/**`, `app/**`, `lib/**`, `domain/**`, `infrastructure/**`, or build files.
- It does not create real `openspec/changes/**` artifacts.
- It does not mix functional changes into refactoring tasks.

## Architecture

| Part | Role |
|---|---|
| Command | `domains/refactor/commands/{refactor-plan,legacy-safety-plan}.md` receives `$ARGUMENTS` and routes to the matching planner. |
| Primary agent | `domains/refactor/agents/{refactor-planner,legacy-safety-planner}.md` orchestrates review, composition, safety, and saving for its workflow. |
| Reviewer subagents | Focused analysis agents load a shared `reviewer-output-contract` skill and return compact YAML findings or `nf: "<reason>"`, with max-5-findings noise caps and short enums to reduce token usage without dropping composer/safety data. |
| Legacy analysis workers | `scope-analyzer`, `behavior-characterizer`, `dependency-seam-finder`, `risk-assessor`, `test-planner`, `architecture-reviewer`, and `tooling-auditor` run read-only legacy-risk analysis under `/legacy-safety-plan`, locked to a single frozen target for the whole run. |
| Tooling matrix | `tooling-audit` and `tooling-compatibility-matrix` skills give `tooling-auditor` an offline Java/JS-TS/Python baseline for test, coverage, and mutation tooling (JaCoCo/PIT, Stryker, coverage.py/mutmut/cosmic-ray) with install snippets and verify commands. |
| Composer subagent | `refactor-openspec-composer` creates either the standard 14-section refactor plan or the 12-section legacy-safety template. |
| Safety subagent | `refactor-safety-gate-reviewer` blocks unsafe, speculative, or non-evidence-based plans. |
| Runtime plugin | `domains/refactor/plugins/write-guard.ts` hard-denies writes outside `.ia-refactor/plan/YYYYMMDD/<target>.md` before tool execution. |
| Skills | `skills/*/SKILL.md` provides reusable single-responsibility review instructions; `domains/refactor/skills/*` and `domains/common/skills/*` declare domain usage by symlink. |

## Parallelizable and sequential phases

Parallelizable under `/refactor-plan`, when the OpenCode runtime supports concurrent subagents:

- `naming-readability-reviewer`
- `function-size-responsibility-reviewer`
- `solid-design-reviewer`
- `duplication-simplicity-reviewer`
- `cohesion-coupling-reviewer`
- `type-contract-nullability-reviewer`
- `complexity-performance-reviewer`
- `antipattern-reviewer`
- `logging-observability-reviewer`

Parallelizable under `/legacy-safety-plan`, after `scope-analyzer` resolves units:

- `behavior-characterizer`
- `dependency-seam-finder`
- `risk-assessor`
- `test-planner`
- `architecture-reviewer`
- `tooling-auditor`

Sequential phases:

1. Consolidate and deduplicate findings.
2. Resolve contradictions.
3. Prioritize findings.
4. Compose the OpenSpec-style Markdown.
5. Run the safety gate review.
6. Save the final plan.

## Skills

Skills are not workers. They are reusable instructions loaded by reviewers and composers. Each skill has one responsibility and should stay concise, evidence-based, and plan-only.

## Extending the system

To add a new review lens:

1. Add one `skills/<skill-name>/SKILL.md` file and symlink it from the domains that use it.
2. Add one fused `domains/refactor/agents/<reviewer-name>.md` file for the subagent that loads that skill.
3. Allow that subagent in `refactor-planner.md` task permissions.
4. Add a category to the composer if the final plan needs a new findings section.

## `/legacy-safety-plan` vs `/refactor-plan`

This repository now includes both commands. Keep the distinction clear:

- `/legacy-safety-plan`: focuses on baseline safety, characterization coverage, seams, containment, rollback, and tooling provisioning before touching legacy code. It fans out seven read-only workers under a single frozen `plan_target` lock, enumerates units (blocking above 8), conditionally runs a deep code-quality lens pass only when risk is `high`/`critical`, and folds a tooling-gap audit into the plan. Output is a single 12-section Markdown file.
- `/refactor-plan`: focuses on an evidence-based sequence of behavior-preserving refactors up to OpenSpec-style `tasks.md`. Output is a single 14-section Markdown file.

Both commands share the composer, the safety gate, the write-guard plugin, and `plan-lint.sh` — only the template, section count, and analysis pipeline differ.

### Limitation: external targets

Both commands can analyze a target outside this repository (an absolute path elsewhere on disk), but the generated plan always saves inside this repository's `.ia-refactor/plan/**` — the write-guard denies writes to any other directory tree, including the target's own repository.

## Layout and syntax decision

This harness uses the official project-local OpenCode layout:

- `domains/refactor/commands/*.md` for commands.
- `domains/refactor/agents/*.md` for primary agents and subagents.
- `domains/refactor/plugins/*.ts` for runtime plugins installed by `installers/opencode.sh`.
- `skills/<name>/SKILL.md` for skill bodies and `domains/<domain>/skills/<name>` symlinks for domain usage.

Markdown command files use YAML frontmatter and `$ARGUMENTS`. Agent files use YAML frontmatter with `mode`, `description`, and `permission`. Permission keys use the verified OpenCode permission keys from the implementation prompt. A dedicated write probe on 2026-07-03 confirmed that the active runtime write boundary is enforced by the scoped permissions plus `domains/refactor/plugins/write-guard.ts`: writes under `.ia-refactor/plan/**` were allowed and a root-level write was blocked before mutation.

## Dry-run status

Real runs executed on 2026-07-03 produced current evidence for the hardened harness, before the legacy-safety pipeline below was unified with a second harness (`evaluate-coverage`):

- `.ia-refactor/plan/20260703/price-utils.md` — JavaScript target, lint-clean, safety approved.
- `.ia-refactor/plan/20260703/LegacyOrderProcessor-legacy-safety.md` — legacy-safety target, lint-clean under the prior 10-section template (superseded by the 12-section template below).
- `.ia-refactor/plan/20260703/NoteService.md` — adversarial prompt-injection target, lint-clean, write boundary held.
- `.ia-refactor/plan/20260703/InvoiceService-opencode-test-fixtures.md` — refined InvoiceService plan with pointer spam removed and the same 2 in-scope items / 7 follow-ups preserved from the earlier baseline.

### Legacy-safety pipeline unification (2026-07-03)

`/legacy-safety-plan` absorbed a second OpenCode harness (`evaluate-coverage`): seven analysis workers, a file-less target lock (`plan_target` echoed through every payload instead of a handoff file), unit enumeration with an 8-unit cap, a conditional deep-lens pass gated on risk level, and the tooling-audit/tooling-compatibility-matrix capability. The legacy template grew from 10 to 12 sections (added Unit Breakdown and Tooling Audit and Provisioning); `plan-lint.sh`, the composer, and the safety gate were updated together to stay in lock-step. See the verification run below for post-merge evidence.

## Known limitations

- Reviewer fan-out is now instructed as a single-message batch and was observed overlapping in the local OpenCode session store on 2026-07-03. Runtime scheduling still depends on OpenCode/model support, so overlap should be treated as verified behavior for this environment, not a universal guarantee for every runtime.

## Catalog Notes

The OpenCode plugin is stored under `domains/refactor/plugins/write-guard.ts` and is installed with the refactor domain. The plan linter travels with the `refactor-plan-safety-gates` skill under `assets/plan-lint.sh`.
