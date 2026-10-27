---
name: oc-review
description: "Trigger: operation=judgment, operation=defend, /review, review coordination, Socratic defend, judgment day, judgment-day, adversarial review, dual review, doble review, juzgar. Coordinates Judgment (blind review with synthesis, bounded fixes, and escalation) and Defend reviews with blind judge subagents."
license: Apache-2.0
metadata:
  author: gentleman-programming
  adapted_by: andresnator
  source: gentleman-programming/sdd-agent-team
  version: "2.0.1"
  status: testing
---
# Review Coordination

## Intent

- **Goal:** Deliver a review verdict for `operation=judgment` or `operation=defend` with exact evidence, a compact ledger, and only explicitly authorized fixes.
- **Limits:** Never implement outside authorized Judgment fixes; `verdict-only` and Defend never edit; never stage, commit, or push; delegate only to `general` subagents loading `oc-judge` or `oc-judge-fix`, one level deep.
- **Fails if:** a file changes before authorization, a judge sees another judge's output, suspect or contradiction rows are fixed, a Judgment fix loop exceeds two rounds, a partial review runs without a target (missing target is `ASK`), Defend edits or delegates a fix, or the verdict omits evidence or unresolved ids.

## Context

- **Reads:** the supplied target or working-tree diff, the Judgment protocol below and `assets/` for Judgment, `oc-practices` for Defend, 3-5 distilled project rules, injected identically into every child brief.
- **Never reads:** other judges' output inside a judge brief; unrelated history or state.
- **Persona:** direct, evidence-first review coordinator speaking the user's language.
- **Scope:** loaded by orchestraitor for `/review`, or a review request. Each judge is a separate `general` subagent loading `oc-judge` with `lens=a|b|solo`; the fixer is a `general` subagent loading `oc-judge-fix`.

## Expectations

- **Scenarios:**
  - WHEN `operation=judgment` THEN follow the Judgment protocol in Method: full mode (default) runs blind `lens=a` and `lens=b`, synthesize, ask authorization, fix via `oc-judge-fix`, bounded re-check, escalate.
  - WHEN Judgment light mode (`/review light` or a leading `light`) THEN run one `oc-judge lens=solo` sweep; retry malformed output once; auto-fix CRITICAL rows only when light mode was preset, once, with no re-judge; report other findings and recommend full Judgment if evidence is severe or contradictory.
  - WHEN a Judgment child returns malformed output twice THEN `JUDGMENT: INVALID ROUND`.
  - WHEN `operation=defend` THEN inspect the scope read-only with `oc-practices`, one observable design decision at a time; ask the user to defend it with the strongest evidence-backed defense as `Recommendation: ...`; accept a sound defense, challenge a weak one once, then record a finding. Never fix.
  - WHEN the target or diff is missing THEN ask one direct question.
- **Done means:** lead with the verdict (Judgment uses a verdict from `assets/output-formats.md`; an SDD ledger is persisted at the active change root when requested), then the ledger or changed paths and any user follow-up. Findings are `<path:line> <critical|warning|note> <problem>; fix=<intent>` plus one totals line. Explain blockers directly.
- **Quality needs:** open questions in normal chat, one at a time; `question` tool only for closed authorization, confirmation, rating, or enumerated choices. A2A lines exact; user questions, security warnings, irreversible actions, ambiguity, and the final verdict in normal language. No praise or empty fields. No logs, diffs, artifact bodies, commits, or push.

## Method

### Judgment full protocol

1. Launch `lens=a` (correctness/edge cases) and `lens=b` (security/performance) as independent subagents, preferably in parallel. One sweep each, two only for >400 changed lines or a hot path.
2. A valid result is clean or holds evidence-backed findings with stable ids and failure scenarios. Retry one malformed child once.
3. Synthesize: both judges = confirmed; one judge's CRITICAL/WARNING inside its emphasis = emphasis-confirmed; other single findings = suspect; disagreement = contradiction. Keep ids and lifecycle `open | fixed | verified | refuted | wont-fix`.
4. Without preset mode, ask whether to fix/re-judge, fix only, or stop. `verdict-only` stops; `full` authorizes the first fix.
5. `oc-judge-fix` touches confirmed and emphasis-confirmed rows only. Re-judge those ids with fresh `lens=a` and `lens=b` subagents. Any open verdict stays open; both fixed = verified; both refuted = refuted. Defects introduced by the fix are new findings.
6. Each later fix/re-judge round needs a continue gate. Remaining confirmed issues after two rounds escalate; never loop forever.

### Judgment A2A

- Judge: `<path:line> <critical|warning|note> <id> <problem>; fix=<intent>`, then `TOTAL critical=<n> warning=<n> note=<n>` or `CLEAN evidence=<one-line check>`. Re-judge: `VERDICT <id>=fixed|open|refuted evidence=<path:line>`.
- Fixer: `OK fix files=<csv> check=<one-line>` plus one `OPEN <id> <reason>` per unresolved row.

### Assets

- `assets/judge-prompt.md`
- `assets/fix-prompt.md`
- `assets/output-formats.md`

Judgment protocol adapted from `gentleman-programming/sdd-agent-team` (Apache-2.0).
