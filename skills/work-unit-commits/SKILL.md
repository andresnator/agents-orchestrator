---
name: work-unit-commits
description: "Deliver verified implementation as cohesive commits. Trigger: explicit commit request, commit-per-unit, commit splitting, or keeping tests and docs with code."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/gentle-ai
  status: in-progress
  version: "3.0.0"
---

# Work-unit commits

## Activation

Load this skill only for delivery: Direct work with an explicit user request for commits, or an SDD run whose durable contract says `Delivery: commit-per-unit`. Load it directly, outside `implementation-skill-routing`; delivery and Git are not implementation-skill selection.

The coordinator is the sole owner of the Git index. Workers never stage, commit, or push. Never push. Review, chained PRs, and TCR remain separate workflows and require their own explicit decisions.

## Build units

A unit is one independently useful behavior, fix, migration, or documentation outcome. Keep its implementation, tests, and user-facing documentation together. Every unit must be cohesive, independently verifiable, green before commit, and reversible without unrelated loss.

Honor an explicit commit count, order, granularity, or message exactly. Otherwise form the smallest cohesive verified units and write outcome-oriented Conventional Commit messages. In SDD, Work groups and their `Files:` scopes are candidates: split or combine them into `unit-01`, `unit-02`, and so on when independence, cohesion, or verification requires it.

Before editing, inspect tracked, staged, unstaged, and untracked state. A pre-existing change in a target path is material ambiguity. Direct work asks before including it. SDD with `commit-per-unit` blocks before any implementation edit, leaves the run active, and changes to `working-tree` only on an explicit user instruction. Preserve every staged or unstaged path outside the unit.

## Commit one unit

Deliver units serially, even when disjoint implementation work ran in parallel:

1. Run the unit's focused verification and require it to pass.
2. Record the expected current full `HEAD`; it must equal the previous delivered unit's `HEAD`, or the run `Baseline` for the first unit.
3. Stage only the unit's exact paths with `git add -- <paths>`; never use a broad add.
4. Require no unstaged diff in those paths. Inspect their staged name set and staged diff, and reject an empty unit, an unexpected path, or any `.ai/` path.
5. Commit with an explicit pathspec: `git commit -m <message> -- <paths>`. Unrelated staged entries remain staged and excluded.
6. Verify the new commit's parent is the recorded pre-commit `HEAD`, its committed paths stay inside the unit and exclude `.ai/`, and the committed unit paths now have no staged or unstaged changes.
7. For SDD, replace `Commits: none` with `Commits: <unit-id> | <full SHA> | <message>` after the first commit and append the same complete `Commits:` row for each later commit.

Inspect with commands scoped to the exact paths, including `git diff -- <paths>`, `git diff --cached -- <paths>`, `git diff --cached --check -- <paths>`, `git status --short -- <paths>`, and the new commit's path list. Do not disturb unrelated index entries while checking them.

## Failure and fixes

Never amend, reset, rebase, squash, or otherwise rewrite commits automatically. A correction after a recorded commit or cold verification becomes a new verified unit and, under `commit-per-unit`, a new commit.

If execution stops, preserve every green commit already created. Keep an incomplete SDD run active and report the recorded full SHAs plus the remaining scope. Never push as recovery.
