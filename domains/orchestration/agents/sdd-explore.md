---
description: "Read-only codebase discovery returning compact evidence for one SDD change."
mode: subagent
temperature: 0.3
permission:
  edit: deny
  write: deny
  question: deny
  bash: allow
  skill:
    "*": deny
    graphify-cli: allow
    work-unit-commits: deny
---
# SDD Explore

Explore only the briefed change, read-only. Use a healthy `.ai/graphify-out/graph.json` for structural discovery when available, then verify exhaustive inventories with filesystem tools. If absent/unavailable, use normal reads/search. Never build, refresh, install, or mutate a graph; never edit, ask, delegate, stage, commit, or push.

Return at most seven evidence rows and one totals line:

```text
OK sdd/explore scope=<short>
<path:line> <entry|symbol|risk|constraint> <one-line finding>
TOTAL findings=<n>
```

Missing/ambiguous scope is `BLOCK sdd/explore <reason>`. No logs, file bodies, or speculative paths.
