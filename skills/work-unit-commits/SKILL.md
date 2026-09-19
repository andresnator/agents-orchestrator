---
name: work-unit-commits
description: "Deliver verified implementation as cohesive commits. Trigger: explicit commit request, commit-per-unit, commit splitting, or keeping tests and docs with code."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/gentle-ai
  status: in-progress
  version: "3.0.3"
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

Use only the top-of-file `Commits:` control rows in `run.md` as the authoritative ledger. Keep these rows together in delivery order; repeat the complete `Commits: <unit-id> | <full SHA> | <message>` row for each commit. Use exactly one `Commits: none` only while the ledger is empty, never alongside commit rows. Do not create a `### Commits` section, execution-state commit list, mirror, or any alternative ledger representation.

Validate this single representation before delivery or any resume, including when no pending record exists. Missing, malformed, truncated, duplicate, conflicting, or alternative ledger representations block without mutation or inferred repair, even if a mirror agrees. Unit ids and commit SHAs must not repeat. Never select one representation over another, merge them, or remove a contradictory section to unblock recovery.

Before staging, persist a pending record in `run.md`: unit id, source work ids, declared scope and exact changed paths, focused check and result, intended message, expected parent SHA, and a pre-stage Git snapshot. Store snapshot evidence under the run root, outside commits. Include index paths, modes and blob IDs, plus working-tree paths, status, modes and content hashes for tracked and untracked changes, including unrelated state; mark absent paths and exclude `.ai/`.

After staging and validation, save a separate pre-hook snapshot of the same state before invoking `git commit`. Keep both snapshots and the pending record on failure; record the failure and observed state without replacing that evidence.

### Resume pending delivery

Recover using only the installed/loaded harness contract and the named project's run evidence and local Git state. Normal installed skill loading remains allowed. Do not search a harness source repository, sibling worktrees, controller data, or another run to fill evidence gaps or discover recovery rules. Missing or ambiguous required evidence blocks; report the gap without expanding access.

Resolve pending delivery before ordinary `HEAD`/ledger equality. Require the original complete pending metadata and pre-stage evidence; completed-commit recovery also requires the original pre-hook snapshot. Preserve all snapshots. Missing or incomplete evidence blocks; never regenerate it, reconstruct units from work groups, or search ancestry for a plausible commit. A known hook failure or unexpected hook mutation must not justify completed-commit adoption. After human remediation, precommit retry remains allowed only when the first route’s checks pass.

After validating the canonical ledger, choose one route below. With no pending record, require `HEAD` to equal its last SHA, or `Baseline` for `Commits: none`; do not perform recovery writes. For pending delivery, the preceding tip is its last SHA, or `Baseline` for no rows, excluding only an exact final row matching the pending unit id, current full `HEAD`, and intended message. Malformed, truncated, duplicate, or conflicting rows block without inferred repair.

| Observed state | Action |
|---|---|
| `HEAD` = pending parent = preceding tip; no row for the pending unit | Require Git state to match the original pre-stage or pre-hook snapshot, rerun the focused check, and recheck protected state before retrying the same unit through the normal staging/hook flow. |
| `HEAD` is the validated pending commit below; ledger ends at its parent with no pending-unit row | Append exactly one complete row, then clear pending; never recommit. |
| Same validated commit; its exact matching row is already final | Clear pending only; never append a duplicate or recommit. |
| Anything else | Stop without Git, index, source, or recovery-bookkeeping changes. |

For either completed-commit route, validate all of the following before bookkeeping:

- Current `HEAD` has exactly one parent, equal to both the pending parent and preceding tip. Its message matches the intended message. Extra commits or a merge block.
- Its changed paths against that parent, without rename folding, exactly equal the pending changed paths and exclude `.ai/`. Every target commit entry matches the pre-hook staged blob ID and mode, including absence for deletions; unsupported entries or incomplete evidence block.
- Target index and working tree are clean against that commit and consistent with the saved target evidence. Unrelated index entries and tracked/untracked working-tree inventory, modes, hashes, and absences remain invariant against pre-hook evidence, excluding `.ai/`. Compare target transitions separately: successful commit status changes are expected, so never require literal equality of full status snapshots.
- Rerun the focused check and require success, then recheck `HEAD`, target and unrelated protected state, and preserved snapshot evidence before completing recovery. A failed check or any drift blocks; recovery bookkeeping itself changes only the ledger and pending record, never Git, index, or source.

Completed-commit recovery may change only the canonical top control ledger and pending record: leave descriptive unit progress, status labels, summaries, and all other run content unchanged until normal execution resumes. The validated ledger, not stale descriptive status, determines delivered units; never reimplement or recommit a recorded unit because its description still says pending. Normal execution may reconcile descriptions after the recovery boundary, not as part of recovery.

Only after commit verification, record a missing row by replacing `Commits: none` or appending one complete row, then clear pending. If the exact final row already exists, clear pending only. Row format:

```text
Commits: <unit-id> | <full SHA> | <message>
```

No pending unit may remain at final verification or archive.

## Hooks, failures, and continuity

Never skip hooks. If a hook fails or changes `HEAD`, the index, or the working tree unexpectedly, inspect all three and stop. Do not retry through amend, reset, checkout, restore, rebase, squash, index clearing, or another destructive shortcut.

A correction after a commit is a new cohesive unit with a new focused check and a new commit. Never amend, reset, rebase, squash, or otherwise rewrite delivery history. If execution stops, preserve every green commit and report its full SHA plus the remaining scope.

Never push.
