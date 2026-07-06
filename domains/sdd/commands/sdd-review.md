---
description: "Manual review of the current diff: quality by default; 'risk', 'full', or 'jd' for other modes"
agent: sdd-orchestrator
argument-hint: "[quality|risk|full|jd or target]"
---
Run a manual review on the current diff. Mode argument: $ARGUMENTS
Mode selection:
- (empty) or `quality` — delegate `sdd-review-quality` on the current working-tree diff.
- `risk` — delegate `sdd-review-risk`.
- `full` — delegate `sdd-review-quality` and `sdd-review-risk` in parallel.
- `jd` — run the judgment-day protocol: load the `judgment-day` skill, launch `jd-judge-a` and `jd-judge-b` in parallel and blind (never reveal one judge's findings to the other), synthesize buckets (confirmed / suspect / contradiction), send confirmed findings to `jd-fix`, re-judge, maximum 2 fix rounds, then escalate to the user via the `question` tool.

Rules:
- Instruct each reviewer to review the current uncommitted diff (`git diff`; include staged changes) unless the arguments name a different target (a commit range or a change folder).
- Reviewers are read-only; findings arrive in their envelopes. Do not paste diffs into this thread.
- Report findings grouped by severity (blocker / major / minor) with file:line and the suggested fix, and state clearly whether anything is merge-blocking.
- This command does not modify state.yaml unless it runs as the review phase of an active change, in which case record the review outcome there.
