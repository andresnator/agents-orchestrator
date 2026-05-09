# Java Refactor Anchor-First Scenarios

Golden cases for the Java refactor anchor-first workflow. These scenarios validate prompt behavior and handoff discipline by manual review; this repository has no runtime test framework.

## Validation checklist

- The primary stays dumb: it routes, asks one blocking question, and passes Engram topic keys.
- Subagents own substantive reading, testing, refactoring, and evidence work.
- Missing or weak gate evidence blocks unsafe refactoring.
- Final evidence uses compact Engram summaries, not raw source or report content.

## Golden cases

| Case | Input | Expected behavior | Must include | Must not include |
|---|---|---|---|---|
| Dumb primary refuses raw inspection | User asks the primary to inspect Java source or coverage reports directly. | Primary refuses deep analysis and routes to the correct phase subagent. | One next phase, relevant Engram topic keys, no raw-artifact analysis. | Source snippets, coverage report summaries, implementation advice. |
| Missing handoff blocks dependent phase | Test anchorer starts without `baseline-audit` or `target-scope`. | Subagent returns `blocked` and names the missing topic key. | `status: blocked`, missing key, one next action. | Guessing baseline state or target behavior. |
| Baseline unverified | Human has not verified build, tests, coverage, or mutation readiness. | Primary warns that refactoring on an unstable baseline is unsafe and asks one verification question. | One blocking question, baseline gate status. | Launching TCR or editing code. |
| Coverage tooling missing | Baseline auditor finds no coverage tooling evidence. | Auditor treats setup as blocker or human decision, not refactor work. | Coverage gate status, setup recommendation, human decision needed. | Silent waiver or build-file changes without approval. |
| Mutation tooling missing | Baseline auditor finds no mutation tooling evidence. | Auditor blocks or asks for a setup/exception decision. | Mutation gate status, tool uncertainty, one next action. | Pretending mutation passed. |
| Characterization exposes a bug | Test anchoring reveals behavior that looks wrong or ambiguous. | Anchorer documents the bug as follow-up and stops before refactor. | Bug evidence summary, `bug-fix work` recommendation. | Fixing the bug inside the refactor flow. |
| Coverage below target | Target-scope coverage is below 100% and no waiver exists. | Workflow keeps anchoring/testing and blocks TCR. | Coverage blocker, needed tests or decision. | Starting refactor. |
| Mutation below threshold | Mutation score is below the accepted 80-100% target range. | Workflow strengthens tests or requests a human decision before refactor. | Mutation blocker, next test-anchor action. | Treating weak mutation evidence as green. |
| Gates pass into TCR | Baseline, anchors, coverage, mutation, and review-size strategy are green. | TCR worker executes exactly one small refactor slice. | Slice id, technique, commands/results, rollback boundary. | Expanding into multiple slices or behavior changes. |
| Review-size risk | Planned or actual diff approaches the 400-line budget. | Workflow requires chained PRs or explicit size exception. | Review-size gate, chosen strategy, PR boundary. | Targeting main directly from child PRs in a feature-branch chain. |
| Evidence curation | Refactor slices are complete and evidence report is requested. | Evidence curator reads compact Engram summaries only and writes final report topic. | Gate matrix, topic-key references, rollback/risks. | Raw source, raw coverage, mutation report contents, full command logs. |

## Manual review notes

- Confirm every agent/subagent output uses the compact envelope shape from the strategy document.
- Confirm blockers ask at most one human question.
- Confirm any waiver is tied to a named gate and human decision.
- Confirm root `README.md` remains unchanged unless the maintainer promotes this specialized workflow.
