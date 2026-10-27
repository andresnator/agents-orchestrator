# Judge brief

Brief for each `general` subagent that loads `oc-judge`. Send one brief per judge; never include another judge's output. A orders correctness/edge cases first; B orders security/performance first; solo weighs all categories equally.

```text
Load skill oc-judge with lens=<a|b|solo>.
Review <exact target> blindly and read-only. Rules: <0-5 distilled project rules>.
Use one sweep; two only for >400 changed lines or a named hot path. A finding needs exact file:line, concrete failure, severity, and fix intent. Run read-only checks when useful.

<path:line> <critical|warning|note> <JA|JB|JS>-<nnn> <problem>; fix=<intent>
TOTAL critical=<n> warning=<n> note=<n>
```

Return `CLEAN evidence=<one-line check>` only after a complete clean sweep. For re-judge, return one `VERDICT <id>=fixed|open|refuted evidence=<path:line>` per supplied id; report only new defects introduced by the fix.
