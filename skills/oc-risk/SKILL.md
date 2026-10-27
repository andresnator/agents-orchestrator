---
name: oc-risk
description: "Trigger: risk assessment, refactor risk. Classify technical and functional legacy risk."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: testing
---

# Risk Assessment

## Intent

- **Goal:** Classify overall risk as low, medium, high, or critical from technical and functional evidence and explain why.
- **Limits:** Git access is read-only (`git log` / `git blame` / `git shortlog`).
- **Fails if:** The classification lacks evidence, or the value tier is guessed instead of stated as not inferable.

## Context

- **Reads:** complexity, large units, test gaps/coverage, CRAP score, fan-in/fan-out, consumers, external dependencies, public contracts, async, transactions, persistence, critical domain rules, git churn.
- **Never reads:** none.
- **Persona:** Evidence-driven risk assessor.
- **Scope:** Assessing refactor or legacy risk.

## Expectations

- **Scenarios:**
  - WHEN git history is available THEN rank files by change frequency; high churn on a risky unit raises priority; churn ≈ 0 lowers it (zero-interest debt) unless a planned change lands there.
  - WHEN sizing investment THEN follow the value tier: core domain justifies deep plans, supporting moderate ones, generic code is often better replaced; infer it from domain language, dependency direction, and test intensity.
- **Done means:** Level, rationale, churn priority, value tier.
- **Quality needs:** none beyond evidence rules.
