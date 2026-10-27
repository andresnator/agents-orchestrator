---
name: oc-tcr
description: "Run Test && Commit || Revert as exact, attributable Direct microsteps. Trigger: TCR, test and commit, revert on red, or micro commits."
license: MIT
metadata:
  author: andresnator
  status: backlog
  version: "3.1.0"
---
# TCR

## Intent

- **Goal:** Apply `TCR = Test && Commit || Revert` one deliberately small change at a time.
- **Limits:** Direct only, after explicit `Delivery: tcr`; never SDD, never silently replaced with `commit-per-unit` or `working-tree`. The primary coordinator owns every inventory, rollback, stage, and commit; workers never use this skill or mutate Git. Never skip hooks, push, amend, `git reset`, rebase, squash, rewrite history, or use broad `git checkout`/`git restore`, `git clean`, globs, repository-wide deletion, or rollback by directory.
- **Fails if:** a commit includes a path outside the microstep or inside `.ai/`; unrelated tracked, staged, unstaged, or untracked state changes; a red step is committed; or rollback touches anything not provably created by the step.

## Context

- **Reads:** Git state, the baseline check set (plan `Done means` or full-scope check), exact commit message if supplied.
- **Never reads:** `.ai/` as target scope.
- **Persona:** Exact, attributable microstep deliverer.
- **Scope:** Frontmatter triggers.

## Expectations

- **Scenarios:**
  - WHEN a focused check is green THEN commit only the step's exact paths on the recorded parent.
  - WHEN this microstep turns a focused check red THEN roll back only that microstep exactly.
  - WHEN the failure is flaky, environmental, or ambiguous, the rollback set is unprovable, or a hook fails THEN delete or restore nothing; inspect `HEAD`, index, and working tree and stop.
- **Done means:** every green microstep is its own verified commit, and after the last one the complete baseline set is rerun green (a focused check does not replace it).
- **Quality needs:** Post-commit corrections are new microsteps and commits. Messages are the user's exact text or one outcome-oriented Conventional Commit message.

## Method

### Preflight

1. Require a Git repository, a valid `HEAD`, and an attached branch.
2. Resolve an exact target scope excluding `.ai/`; any dirty target path blocks TCR.
3. Inventory tracked, staged, unstaged, and untracked paths.
4. Run the complete baseline check set; it must be green or TCR does not start.
5. Record the full `HEAD` as the expected parent for the first microstep.

### One microstep

Declare one small intent; record the full `HEAD`, tracked paths it may modify, delete, or rename, each proposed new path and whether it exists, scoped Git state, and the focused check. Apply only that intent and run the check.

### Green: commit

1. Require `HEAD` to equal the recorded pre-step SHA.
2. Derive the exact changed paths; all must belong to the microstep and exclude `.ai/`.
3. Stage only those paths with `git add -- <paths>`; never a broad add.
4. Require no unstaged diff in them; inspect the staged set and diff, then run `git diff --cached --check -- <paths>`.
5. Commit with hooks enabled and an explicit pathspec.
6. Verify the commit parent, exact path set, `.ai/` exclusion, and clean microstep paths before the next step.

### Red: exact rollback

First confirm this microstep caused the failure. Then:

1. Restore only tracked paths changed by the step from its recorded pre-step `HEAD`.
2. Remove only untracked paths absent from the pre-step inventory and demonstrably created by this step, each named explicitly; remove a new directory only once empty.
3. Require the target scope to match the pre-step inventory exactly.
