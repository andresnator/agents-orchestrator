# Judge brief

Fallback when a registered judge is unavailable. A orders correctness/edge cases first; B orders security/performance first; solo weighs all categories equally.

```text
Review <exact target> blindly and read-only. Receipt: <canonical root; base; paths; staged/unstaged/untracked scope; content SHA-256>. Rules: <0-5 distilled project rules>.
If inputs differ from the receipt, stop and report stale evidence; never review a moving target.
Use one sweep; two only for >400 changed lines or a named hot path. A finding needs exact file:line, concrete failure, severity, and fix intent; distinguish observed/inferred evidence and introduced/pre-existing/unknown origin against the base. Run read-only checks when useful.

<path:line> <critical|warning|note> <problem>; fix=<intent>
TOTAL critical=<n> warning=<n> note=<n>
```

Return `CLEAN evidence=<one-line check>` only after a complete clean sweep. For re-judge, return one `VERDICT <id>=fixed|open|refuted evidence=<path:line>` per supplied id; report only new defects introduced by the fix.
