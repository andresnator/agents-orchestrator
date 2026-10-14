---
name: judgment-day
description: "Trigger: judgment day, judgment-day, adversarial review, dual review, doble review, juzgar. Blind review with synthesis, bounded fixes, and escalation."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "2.0.1"
  status: in-progress
---

## Contract

The coordinator scopes and synthesizes; judges review blindly; the fixer edits only authorized findings. Missing target is `ASK`, never a partial review. Load at most 3-5 relevant project rules and inject the same distilled rules into every child brief.

## Intake and routing

`light` and `full` select review shape, never edit permission; `verdict-only` forbids edits. Without a selector, use Light for a small, bounded, low-risk target and Full for >400 changed lines, security-sensitive behavior, public contracts, migrations, or cross-component risk. Ask when target or risk is unclear. Explicit Light remains solo; recommend Full when its evidence exceeds that scope.

Before dispatch, record canonical root, base SHA/range, exact included paths, staged/unstaged/untracked selection, and SHA-256 of a sorted unambiguous manifest of path, kind, mode and content (symlinks: link target). Include evidence inputs, not just filenames or diff stats. Give every judge the same target receipt. Recompute it before synthesis and final verdict; a mismatch makes affected results stale. Refresh the receipt and repeat only affected review, or report a blocked verdict. An authorized fix creates a new content receipt; retain the before/after evidence and check unrelated scope stayed unchanged. Do not create durable state unless requested.

## Full protocol

1. Launch `jd-judge-a` and `jd-judge-b` independently, preferably in parallel. A emphasizes correctness/edge cases; B emphasizes security/performance. Each gets one sweep, or two only for >400 changed lines or a hot path.
2. A valid result is clean or contains evidence-backed findings with stable ids and failure scenarios. Retry one malformed child once; a second malformed return is `JUDGMENT: INVALID ROUND`.
3. Synthesize: both judges = confirmed; one judge's CRITICAL/WARNING inside its emphasis = emphasis-confirmed; other single findings = suspect; disagreement = contradiction. Keep ids and lifecycle `open | fixed | verified | refuted | wont-fix`.
4. Without explicit fix authorization, ask whether to fix/re-judge, fix only, or stop. Authorize an exact scope and eligible ids; mode selection alone never authorizes edits. `verdict-only` stops.
5. `jd-fix` touches explicitly authorized confirmed and emphasis-confirmed rows only. Re-judge affected ids and dependencies, not the entire original target, with fresh A/B judges and the post-fix receipt. Any open verdict stays open; both fixed = verified; both refuted = refuted. Defects introduced by the fix are new findings.
6. Maximum two fix rounds. Each later fix/re-judge needs a continue gate. Remaining confirmed issues escalate; never loop forever.

## Light protocol

Use one `jd-solo` sweep, read-only by default. Retry malformed output once. Only after separate explicit fix authorization, fix authorized CRITICAL rows once and run their named checks; no re-judge. Report fixes as unverified by re-judge, not approved. Report other findings and recommend Full if evidence is severe or contradictory. Never upgrade or edit silently.

## A2A

Judges return one line per finding:

`<path:line> <critical|warning|note> <problem>; fix=<intent>`

Then `TOTAL critical=<n> warning=<n> note=<n>` or `CLEAN evidence=<one-line check>`. Re-judge uses `VERDICT <id>=fixed|open|refuted evidence=<path:line>`. Fixer returns `OK fix files=<csv> check=<one-line>` plus one `OPEN <id> <reason>` per unresolved row. No logs, diffs, praise, or empty fields.

User questions, security warnings, irreversible actions, ambiguity, and the final human verdict use normal language. Persist an SDD ledger at the active change root when requested.

## Assets

- `assets/judge-prompt.md`
- `assets/fix-prompt.md`
- `assets/output-formats.md`
