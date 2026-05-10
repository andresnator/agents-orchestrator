# Java Refactor Anchor-First Scenarios

Golden cases for the Java refactor anchor-first workflow. These scenarios validate prompt behavior and handoff discipline by manual review; this repository has no runtime test framework.

## Validation checklist

- The primary stays dumb: it routes, asks one blocking question, and passes Engram topic keys.
- Subagents own substantive reading, testing, refactoring, and evidence work.
- Missing or weak gate evidence blocks unsafe refactoring.
- Final evidence uses compact Engram summaries, not raw source or report content.
- Missing `project` or stale/mismatched `run_id` blocks before Engram access.
- Skill-loading contracts are imperative and owned by workflow-private subagents, not the primary.

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
| Missing project blocks | Any primary or subagent input omits `project`. | Agent returns `blocked` before any Engram read/write. | `status: blocked`, missing `project`, one question or next action. | Inferred cwd/session project, `mem_search`, `mem_save`. |
| Wrong or stale run_id blocks | A workflow-private subagent receives topics for a different `run_id` or namespace. | Subagent blocks before phase work and reports the expected namespace. | `run_id` mismatch, `java-refactor-anchor-first/{run_id}/...`, `status: blocked`. | Reading stale artifacts, writing under the wrong run namespace. |
| Baseline auditor remains skill-free | Baseline auditor starts with valid `project`, `run_id`, and baseline topic keys. | Auditor performs contract validation and baseline audit without loading skills. | “Load no skills” behavior, compact baseline/tooling evidence. | `java-testing`, `chained-pr`, any method skill load. |
| Test anchorer loads java-testing | Test anchorer starts with valid baseline and target-scope evidence. | Anchorer loads and follows `java-testing` before anchor selection, edits, validation, or documentation. | `java-testing` loaded first, anchor-strength evidence. | Anchor work before skill load, TCR/refactor execution. |
| TCR worker skill plan | TCR worker starts with valid gates and review-size evidence. | Worker loads `refactor-java` and `tcr`, never loads `work-unit-commits`, and loads `chained-pr` only when evidence shows size risk. | `refactor-java`, `tcr`, conditional `chained-pr` rationale. | `work-unit-commits`, unconditional `chained-pr`, edits before skill checks. |
| TCR worker blocks without valid diff evidence | TCR worker lacks `allowed_commands.diff_size` and lacks equivalent numeric additions+deletions evidence with source and timestamp. | Worker blocks before edits and requests measurable diff evidence. | `status: blocked`, `diff_size` or equivalent evidence requested. | Reading for edits, code changes, approximate-only size claims. |
| TCR worker blocks oversized unsliced work | TCR worker evidence shows more than 400 additions+deletions and no chained/stacked PR decision or size exception. | Worker blocks before edits and requests slicing decision or explicit exception. | Changed-line total, required review strategy decision. | Editing under unresolved review-size risk. |
| Evidence curator loads cognitive-doc-design | Evidence curator begins final reporting with valid compact topics. | Curator loads and follows `cognitive-doc-design` before writing or updating evidence reporting. | `cognitive-doc-design` loaded first, reviewer-facing gate matrix. | Raw report dumps, final curation before skill load. |

## Manual review notes

- Confirm every agent/subagent output uses the compact envelope shape from the strategy document.
- Confirm blockers ask at most one human question.
- Confirm any waiver is tied to a named gate and human decision.
- Confirm no new scenario file was added; therefore `scenarios/README.md` inventory does not need changes.
- Confirm root `README.md` remains unchanged unless the maintainer promotes this specialized workflow.
