---
description: "Ship the active change: branch, work-unit conventional commits, PR; gate before push"
agent: sdd-orchestrator
argument-hint: "[change slug (optional)]"
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---
Ship the change: $ARGUMENTS (default: the active T2 change whose phase is `ship`, or the reviewed T1 change).
1. Resolve the change and read its `state.yaml`. Refuse to ship if the review phase has not completed or the review gate was not approved.
2. Branch: create a branch named after the change slug (e.g. `feat/<slug>` or `fix/<slug>` based on the change intent) unless already on it.
3. Commits: split the diff into work-unit commits following the work units in `.arnes/changes/<change>/tasks.md` — one commit per task or coherent task group, each leaving the tree green. Use conventional commit messages (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`). Never add AI attribution lines, Co-Authored-By trailers, or tool signatures.
4. PR body: compose from the proposal and spec summaries (use `handoffs/propose.md` and `handoffs/spec.md`): intent, what changed, how it was verified (verify-report result), rollback plan. Reference the change folder path.
5. GATE: before pushing anything, present the branch name, the commit list (messages only), and the PR title/body via the `question` tool with options: push and open PR / adjust / abort. Only push and create the PR (`gh pr create`) after approval.
6. On success, update `state.yaml` to `phase: archive` pending, record the PR URL under `artifacts`, and remind the user that archiving (per the `sdd-workflow` state contract reference) closes the change.

Git state commands (status, log, diff --stat) may run inline; anything that rewrites history requires the gate first.
