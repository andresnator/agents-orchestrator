---
name: oc-commits
description: "Deliver verified implementation as cohesive commits. Trigger: explicit commit request, commit-per-unit, commit splitting, or keeping tests and docs with code."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/gentle-ai
  status: in-progress
  version: "4.1.0"
---
# Work-unit commits

## Intent

- **Goal:** Deliver verified implementation as cohesive, serial commits, each keeping one behavior, fix, migration, or documentation outcome with its tests and user-facing docs.
- **Limits:** Only after explicit `Delivery: commit-per-unit`; loaded directly, outside `oc-routing`. The primary coordinator is the sole owner of the Git index; workers never stage, commit, or push. Review, Judgment, chained PRs, push, and merge remain separate workflows. Never use `git add .`, `git add -A`, or a repository-wide pathspec; never skip hooks, push, amend, reset, checkout, restore, clear the index, rebase, squash, or rewrite delivery history.
- **Fails if:** a commit has the wrong parent, contains an unrelated or `.ai/` path, or is empty; a failing unit is committed; unrelated state (including staged entries) changes; or a pending unit remains at final verification or archive.

## Context

- **Reads:** Git state, repository commit-message style, the plan's work groups (candidates, not mandatory commit boundaries), focused checks, and any explicit commit count, order, granularity, or message.
- **Never reads:** `.ai/` as target scope.
- **Persona:** Cohesive-commit deliverer.
- **Scope:** Frontmatter triggers; Direct and SDD.

## Expectations

- **Scenarios:**
  - WHEN a pre-existing target change exists THEN Direct asks whether to include it, switch to `working-tree`, or stop; SDD blocks without editing or changing delivery.
  - WHEN a hook fails or unexpectedly changes `HEAD`, index, or working tree THEN inspect all three and stop without destructive retry.
  - WHEN a correction is needed after a commit THEN it is a new cohesive unit with a new focused check and a new commit.
  - WHEN execution stops THEN every green commit is preserved and its full SHA plus remaining scope is reported.
- **Done means:** each unit is committed and verified on the expected parent; SDD `run.md` holds one ledger row per unit (see Method) and no pending record.
- **Quality needs:** Smallest independently useful, verifiable units; outcome-oriented Conventional Commit messages unless the user supplied exact messages.

## Method

### Preflight (before the first edit)

1. Require a Git repository, a valid `HEAD`, and an attached branch. Record the full `HEAD` as baseline.
2. Resolve the exact target scope and reject `.ai/` or any path inside it.
3. Inventory tracked, staged, unstaged, and untracked paths.
4. Treat any pre-existing target change as material ambiguity (see Scenarios).
5. Honor explicit commit constraints; otherwise define units per Quality needs.

### Commit one unit

1. Apply only the unit and run its focused check.
2. Require `HEAD` to equal the previous unit SHA (baseline first).
3. Derive the exact changed path list; it contains no unrelated or `.ai/` path. For SDD, persist the pending record before staging.
4. Stage only those paths with `git add -- <paths>`; require no unstaged diff in them.
5. Inspect staged paths and diff; reject empty or unexpected content, then run `git diff --cached --check -- <paths>`.
6. For SDD, save the pre-hook snapshot. Commit with hooks enabled and an explicit pathspec, such as `git commit -m <message> -- <paths>`.
7. Verify the parent, exact unit paths, `.ai/` exclusion, and clean unit paths.

### SDD pending delivery

Before staging, persist a pending record in `run.md`: unit id, source work ids, declared scope and exact changed paths, focused check and result, intended message, expected parent SHA, and a pre-stage Git snapshot. Store snapshot evidence under the run root, outside commits: index paths, modes and blob IDs, plus working-tree paths, status, modes and content hashes for tracked and untracked changes, including unrelated state; mark absent paths and exclude `.ai/`.

After staging and validation, save a separate pre-hook snapshot of the same state before `git commit`. On failure keep both snapshots and the pending record; record the failure and observed state without replacing that evidence.

On resume, require `HEAD` to match both the ledger tip (or `Baseline` when `Commits: none`) and the pending parent, and Git state to match the saved pre-stage or pre-hook snapshot; then rerun the focused check before retrying that same unit. Missing evidence or any mismatch blocks. Never reconstruct a split or combined unit from work groups or absorb new changes.

Only after commit verification, replace `Commits: none` or append one complete row, then clear the pending record:

```text
Commits: <unit-id> | <full SHA> | <message>
```
