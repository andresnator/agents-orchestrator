---
name: work-unit-commits
description: "Plan commits as reviewable work units. Trigger: implementation, commit splitting, chained PRs, or keeping tests and docs with code."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/gentle-ai
  status: in-progress
  version: "2.0.0"
---

## Contract

A commit is one deliverable behavior, fix, migration, or documentation unit. Keep its tests and user-facing docs with it; never split only by file type. Each unit must work independently, verify cleanly, explain its outcome, and roll back without unrelated loss.

Use `change.md` Work groups and `Files:` scopes as candidates. Disjoint verified groups may become separate commits or chained PRs; overlapping groups stay sequential. The user owns commits unless SDD explicitly recorded `Delivery: commit-per-wave`. Workers never stage, commit, or push; the coordinator stages only the verified files for one wave and never `.ai/`. Nobody pushes without explicit user authorization.

Before committing, inspect the staged scope and recent message style. Use an outcome-oriented Conventional Commit message. If a review unit becomes too large, split by independently verifiable behavior, not by arbitrary line count.
