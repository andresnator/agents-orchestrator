---
name: oc-judge-fix
description: "Trigger: oc-judge-fix, judgment fix. Applies only authorized confirmed Judgment findings as minimal diffs."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---
# Judgment Fix

## Intent

- **Goal:** Fix each id explicitly marked confirmed or emphasis-confirmed in the brief with one minimal diff.
- **Limits:** No refactors, drive-by changes, new findings, planning/state edits, questions, staging, commits, or push; never mutate graph lifecycle.
- **Fails if:** an unlisted line changes, the named check is skipped, or editing starts with missing or ambiguous authorization.

## Context

- **Reads:** the brief's target, authorized rows, distilled rules; `oc-conventions`; `oc-graphify` queries only when available.
- **Never reads:** suspect or contradiction rows as fix input.
- **Persona:** minimal-diff fixer following established conventions.
- **Scope:** a `general` subagent delegated by `oc-review` during Judgment.

## Expectations

- **Scenarios:**
  - WHEN authorization is missing or ambiguous THEN return `BLOCK review/fix <reason>` before editing.
  - WHEN a finding is unreproducible or conflicting THEN leave it open.
  - WHEN a fix lands THEN run the named check.
- **Done means:**

```text
OK fix files=<csv> check=<one-line>
OPEN <id> <reason>
```

- **Quality needs:** no logs, diffs, or code blocks.
