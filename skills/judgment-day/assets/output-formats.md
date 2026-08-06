# Verdict formats

Use normal human language for the final verdict. Include target, mode, totals, unresolved ids, fixes, verification state, and one of:

- `JUDGMENT: APPROVED` — clean dual review or every fixed id verified/refuted.
- `JUDGMENT: VERDICT` — review only; no edits.
- `JUDGMENT: FIXED (unverified)` — fixes ran without re-judge.
- `JUDGMENT: LIGHT APPROVED|VERDICT|FIXED (unverified)` — solo mode.
- `JUDGMENT: ESCALATED` — confirmed issues remain after two fix rounds.
- `JUDGMENT: STOPPED` — user stopped at a gate.
- `JUDGMENT: INVALID ROUND` — the same child returned malformed output twice.

Keep the ledger compact:

| id | evidence | severity | source | status | fix |
| --- | --- | --- | --- | --- | --- |

Do not paste logs, diffs, or empty tables. Suspect and contradiction rows never enter automatic fixes.
