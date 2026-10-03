---
name: work-unit-commits
description: "Deliver verified implementation as cohesive commits. Trigger: explicit commit request, commit-per-unit, commit splitting, or keeping tests and docs with code."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/gentle-ai
  status: in-progress
  version: "3.0.6"
---

# Work-unit commits

## Activation

Load this skill only after `Delivery: commit-per-unit` has been resolved from an explicit execution instruction or plan. Load it directly, outside `implementation-skill-routing`; delivery and Git are not implementation skills.

The primary coordinator is the sole owner of the Git index. Workers never stage, commit, or push. Review, Judgment, chained PRs, push, and merge remain separate workflows.

## Preflight

Complete this before the first implementation edit:

1. Require a Git repository, a valid `HEAD`, and an attached branch. Record the full `HEAD` as the delivery baseline and expected parent of the first commit.
2. Resolve the exact target scope and reject `.ai/` or any path inside it.
3. Inventory tracked, staged, unstaged, and untracked paths. Preserve every path outside the target scope, including unrelated staged entries.
4. Treat any pre-existing target change as material ambiguity. Direct execution asks whether to include it, switch to `working-tree`, or stop. SDD blocks without editing or changing delivery.
5. Honor an explicit commit count, order, granularity, or message. Otherwise define the smallest cohesive units that are independently useful and verifiable.

Never use `git add .`, `git add -A`, a repository-wide pathspec, or a command that clears the index.

## Commit one unit

A unit keeps one behavior, fix, migration, or documentation outcome with its tests and user-facing docs. Work groups are candidates, not mandatory commit boundaries.

Deliver units serially:

1. Apply only the unit and run its focused check. A failing unit is not committed.
2. Require the current full `HEAD` to equal the previous unit SHA, or the baseline for the first unit.
3. Derive the exact changed path list for the unit and ensure it contains no unrelated or `.ai/` path. For SDD, persist the pending record below before staging.
4. Stage only those paths with `git add -- <paths>`. Require no unstaged diff in them.
5. Inspect the staged path set and staged diff for those paths. Reject empty, missing, or unexpected content, then run `git diff --cached --check -- <paths>`.
6. For SDD, save the pre-hook snapshot below. Commit with hooks enabled and an explicit pathspec, such as `git commit -m <message> -- <paths>`. Preserve unrelated staged entries.
7. Verify that the new commit has the recorded pre-commit `HEAD` as parent, contains exactly the unit paths, excludes `.ai/`, and leaves the unit paths without staged or unstaged changes.

Use outcome-oriented Conventional Commit messages unless the user supplied exact messages. Inspect repository message style before choosing them.

## SDD pending delivery

### Validate the ledger

Use only the top control block in `run.md`. Keep complete rows together in delivery order:

```text
Commits: <unit-id> | <full SHA> | <message>
```

An empty ledger contains exactly one `Commits: none`, never mixed with commit rows. Before delivery or any resume, including without pending delivery, validate:

- **Format:** unit ids and SHAs are unique. Missing, malformed, truncated, duplicate, conflicting, or alternative representations block. This includes a `### Commits` section, execution-state list, or mirror, even if it agrees. Never select, merge, remove, or infer rows to repair the ledger.
- **History:** every SHA names an existing commit with exactly one parent: `Baseline` for the first row, the preceding row's SHA thereafter. Validate every row before trusting any unit as delivered; a matching final `HEAD` alone is insufficient.

Validation failures block without recovery mutations or inferred repair.

### Save pending evidence

Before the unit's first focused check, declare its generated output paths from the project/check configuration. Record `Check outputs: none` or literal repository-relative file/directory paths in the pending record and both snapshots. Keep that declaration fixed for the unit, including resume; never infer exclusions after observing drift.

Only untracked generated outputs qualify, such as Maven's `target/` in the Java fixture. Never exclude tracked paths, source, unrelated user files, or all ignored files. Reject paths outside the project, `.git/`, `.ai/`, or a directory mixing generated and protected content; narrow the declaration before the first check or block. Only focused checks may change declared outputs; hook failures or unexpected hook mutations still block.

Use one **protected state** definition for capture and validation: the full Git index and every working-tree path outside `.git/`, `.ai/`, and the declared check outputs. Include clean tracked files and unrelated untracked/ignored files, their inventory, modes, hashes, and absences. Record symlinks as links without traversing outside the project.

Before staging, persist a pending record in `run.md`: unit id, source work ids, declared scope and exact changed paths, focused check and result, check outputs, intended message, expected parent SHA, and a pre-stage Git snapshot of that complete protected state. Include all index paths, modes, stage numbers, and blob IDs. Store snapshots under the run root, outside commits.

After staging and validation, save a separate pre-hook snapshot of the same state before invoking `git commit`. Keep both snapshots and the pending record on failure; record the failure and observed state without replacing that evidence.

### Resume pending delivery

Use only the installed/loaded harness, the named project's run evidence, and local Git state. Normal installed skill loading is allowed. Keep coordinator and worker searches inside those read boundaries, including shell commands and symlink traversal. An external evidence path or missing local evidence blocks before lookup; never search parent directories, harness source repositories, sibling worktrees, controller data, or other runs to fill a gap.

With no pending record, validate the ledger and require `HEAD` to equal its last SHA, or `Baseline` for `Commits: none`. Skip pending-evidence checks and recovery writes; normal execution can resume.

Only when pending exists, resolve it before ordinary `HEAD`/ledger equality. Require complete original pending metadata and pre-stage evidence; completed-commit recovery also requires the original pre-hook snapshot. Both snapshots must cover the complete protected state and agree with the pending record's check-output declaration. Missing, incomplete, or ambiguous evidence blocks without mutation. Preserve snapshots; never regenerate evidence, reconstruct units from work groups, or search ancestry for a plausible commit. A hook failure or unexpected hook mutation cannot justify commit adoption. After human remediation, retry only through the precommit route below.

After validating the ledger, choose one route. Its **preceding tip** is the last SHA, or `Baseline` for an empty ledger, excluding only an exact final row matching the pending unit id, current full `HEAD`, and intended message.

| Observed state | Action |
|---|---|
| No pending record | Require `HEAD` = last ledger SHA, or `Baseline` for `Commits: none`. Make no recovery writes. |
| `HEAD` = pending parent = preceding tip; no row for the pending unit | Require Git state to match the original pre-stage or pre-hook snapshot, rerun the focused check, and recheck protected state before retrying the same unit through the normal staging/hook flow. |
| `HEAD` is the validated pending commit below; ledger ends at its parent with no pending-unit row | Append exactly one complete row, then clear pending; never recommit. |
| Same validated commit; its exact matching row is already final | Clear pending only; never append a duplicate or recommit. |
| Anything else | Stop without Git, index, source, or recovery-bookkeeping changes. |

For either completed-commit route, validate all of the following before bookkeeping:

- Current `HEAD` has exactly one parent, equal to both the pending parent and preceding tip. Its message matches the intended message. Extra commits or a merge block.
- Its changed paths against that parent, without rename folding, exactly equal the pending changed paths and exclude `.ai/`. Every target commit entry matches the pre-hook staged blob ID and mode, including absence for deletions; unsupported entries or incomplete evidence block.
- Target index and working tree are clean against that commit and consistent with the saved target evidence. The remaining protected state stays invariant against pre-hook evidence. Compare target transitions separately: successful commit status changes are expected, so never require literal equality of full status snapshots.
- Rerun the focused check and require success, then recheck `HEAD`, target and unrelated protected state, and preserved snapshot evidence before completing recovery. A failed check or any drift blocks; recovery bookkeeping itself changes only the ledger and pending record, never Git, index, or source.

Completed-commit recovery changes only the top ledger and pending record. Leave descriptions, status labels, summaries, and all other run content unchanged. The validated ledger determines delivered units: stale descriptions never authorize reimplementation or recommit. Reconcile descriptions only when normal execution resumes.

### Record a verified commit

After normal commit verification or completed-commit recovery validation:

1. If the row is missing, replace `Commits: none` or append one complete row using the full SHA returned by local Git. Finish the write and verify the persisted row matches the validated commit and pending metadata while pending remains present.
2. In a separate, subsequent write, replace the pending label and fields with `Pending delivery: none`; preserve enclosing section headings. If the exact final row already existed, perform only this step.

No pending unit may remain at final verification or archive.

## Hooks, failures, and continuity

Never skip hooks. If a hook fails or changes `HEAD`, the index, or the working tree unexpectedly, inspect all three and stop. Do not retry through amend, reset, checkout, restore, rebase, squash, index clearing, or another destructive shortcut.

A correction after a commit is a new cohesive unit with a new focused check and a new commit. Never amend, reset, rebase, squash, or otherwise rewrite delivery history. If execution stops, preserve every green commit and report its full SHA plus the remaining scope.

Never push.
