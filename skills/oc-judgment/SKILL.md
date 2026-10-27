---
name: oc-judgment
description: "Trigger: judgment day, judgment-day, adversarial review, dual review, doble review, juzgar. Blind review with synthesis, bounded fixes, and escalation."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "4.0.0"
  status: in-progress
---
# Judgment Protocol

## Intent

- **Goal:** Produce a Judgment verdict from blind judges, synthesis, bounded authorized fixes, and escalation.
- **Limits:** The coordinator scopes and synthesizes; judges review blindly; the fixer edits only authorized findings. Never edit before authorization; maximum two fix rounds; never loop forever.
- **Fails if:** a judge sees another judge's output, suspect or contradiction rows are fixed, or a partial review runs without a target (missing target is `ASK`).

## Context

- **Reads:** the exact target; 3-5 relevant project rules, injected identically into every child brief; `assets/`.
- **Never reads:** one judge's output inside another judge's brief.
- **Persona:** adversarial review coordinator.
- **Scope:** loaded by `oc-review` for `operation=judgment`. Each judge is a separate `general` subagent loading `oc-judge` with `lens=a|b|solo`; the fixer is a `general` subagent loading `oc-judge-fix`.

## Expectations

- **Scenarios:**
  - WHEN full mode THEN follow the full protocol below.
  - WHEN light mode THEN run one `oc-judge lens=solo` sweep; retry malformed output once; auto-fix CRITICAL rows only when light mode was preset, once, with no re-judge; report other findings and recommend full Judgment if evidence is severe or contradictory.
  - WHEN a child returns malformed output twice THEN `JUDGMENT: INVALID ROUND`.
- **Done means:** a verdict from `assets/output-formats.md`; an SDD ledger persisted at the active change root when requested.
- **Quality needs:** A2A lines exact; user questions, security warnings, irreversible actions, ambiguity, and the final verdict in normal language. No logs, diffs, praise, or empty fields.

## Method

### Full protocol

1. Launch `lens=a` (correctness/edge cases) and `lens=b` (security/performance) as independent subagents, preferably in parallel. One sweep each, two only for >400 changed lines or a hot path.
2. A valid result is clean or holds evidence-backed findings with stable ids and failure scenarios. Retry one malformed child once.
3. Synthesize: both judges = confirmed; one judge's CRITICAL/WARNING inside its emphasis = emphasis-confirmed; other single findings = suspect; disagreement = contradiction. Keep ids and lifecycle `open | fixed | verified | refuted | wont-fix`.
4. Without preset mode, ask whether to fix/re-judge, fix only, or stop. `verdict-only` stops; `full` authorizes the first fix.
5. `oc-judge-fix` touches confirmed and emphasis-confirmed rows only. Re-judge those ids with fresh `lens=a` and `lens=b` subagents. Any open verdict stays open; both fixed = verified; both refuted = refuted. Defects introduced by the fix are new findings.
6. Each later fix/re-judge round needs a continue gate. Remaining confirmed issues after two rounds escalate.

### A2A

- Judge: `<path:line> <critical|warning|note> <id> <problem>; fix=<intent>`, then `TOTAL critical=<n> warning=<n> note=<n>` or `CLEAN evidence=<one-line check>`. Re-judge: `VERDICT <id>=fixed|open|refuted evidence=<path:line>`.
- Fixer: `OK fix files=<csv> check=<one-line>` plus one `OPEN <id> <reason>` per unresolved row.

### Assets

- `assets/judge-prompt.md`
- `assets/fix-prompt.md`
- `assets/output-formats.md`
