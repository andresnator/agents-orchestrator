---
description: "Run an oc-arch operation: map, review, ideate, or boundary."
agent: orchestraitor
subtask: false
argument-hint: "[map|review|ideate|boundary] [target or focus]"
---
Raw arguments: `$ARGUMENTS`

Load `oc-arch` and run `operation=<first argument>`; pass the remaining arguments as target or focus. A missing or unknown operation asks one closed choice among `map`, `review`, `ideate`, and `boundary`.

- `map`: generate or refresh evidence-backed C4-lite docs; write only `<docfolder>/architecture/**`, refreshing in place.
- `review`: architecture gaps, fitness functions, optional `dependencies` focus; write only `.ai/architect/reports/**`. Dependency commands need direct user authorization; every finding needs evidence or `hypothesis`.
- `ideate`: plan only; one ADR under `<docfolder>/architecture/adr/` plus one `.ai/architect/plans/<slug>.md`.
- `boundary`: inspect one exact target statically (no shell or web); write only its report under `.ai/architect/reports/`. Ask one blocking question when the target is missing.

No operation edits source, commits, or pushes.
