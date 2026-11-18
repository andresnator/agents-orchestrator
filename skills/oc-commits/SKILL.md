---
name: oc-commits
description: "Commit finished work as one commit per outcome with explicit paths. Trigger: commit request, plan line Delivery: commits, split commits."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/gentle-ai
  status: in-progress
  version: "5.0.0"
---
# Commits

## Intent

- **Goal:** Put finished work into commits, one commit per outcome, each with its tests and docs.
- **Limits:** `orchestraitor` makes the commits in the main working tree. This skill does not push, amend, or rewrite history.
- **Fails if:**
  - A commit contains a `.ai/` path or a path that is not part of its outcome.
  - A commit was made with `git add .`, `git add -A`, or `--no-verify`.

## Context

- **Reads:** `git status`, the diff of the changed paths, and the recent `git log` for the message style.
- **Scope:** the current request asks for commits, or the plan has the line `Delivery: commits`. In all other cases, do not commit.

## Expectations

- **Done means:** each outcome is one commit, and the report lists each short SHA with its message.

## Method

1. Group the changed paths by outcome: one behavior, fix, or document, with its tests and docs. Use the messages or the number of commits that the user gave, if any.
2. For each outcome, stage its paths: `git add -- <paths>`. Never stage `.ai/`.
3. Read `git diff --cached --stat`. Remove a path that is not part of the outcome: `git restore --staged -- <path>`.
4. Commit with a conventional message, for example `fix(cart): keep items after reload`. Keep the hooks on.
5. If a hook fails, fix the cause and commit again, one time. If it fails again, make no more commits, leave the changes in the working tree, and report the hook output.

A target file can have changes from before the work. Keep them out of the commit when they are separable (`git add -p -- <path>`). If they are not separable, include them and say so in the report.
