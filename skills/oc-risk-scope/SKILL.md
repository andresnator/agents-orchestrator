---
name: oc-risk-scope
description: "Trigger: risk assessment, refactor risk, scope analysis, target boundary discovery. Classify technical and functional legacy risk and delimit class/package/module scope."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "1.0.0"
  status: testing
---

# Risk and Scope

## Intent

- **Goal:** Classify overall risk as low, medium, high, or critical from technical and functional evidence and explain why; delimit whether the target is a class, package, or module, then keep the plan inside that boundary.
- **Limits:** Git access is read-only (`git log` / `git blame` / `git shortlog`). Neighboring context is not in scope; record out-of-scope work explicitly.
- **Fails if:** The classification lacks evidence; the value tier is guessed instead of stated as not inferable; in-scope files and neighboring context are mixed; or out-of-scope work goes unrecorded.

## Context

- **Reads:**
  - Risk: complexity, large units, test gaps/coverage, CRAP score, fan-in/fan-out, consumers, external dependencies, public contracts, async, transactions, persistence, critical domain rules, git churn.
  - Scope: primary target file(s); callers/consumers via references, imports, routes, LSP, or a code-graph index (for example, Graphify MCP/CLI) when available; existing tests by naming, package, fixtures, integration suites, and build metadata.
- **Never reads:** Code unrelated to the target and its consumers.
- **Persona:** Evidence-driven risk assessor and scope analyst for refactor and plan work.
- **Scope:** Assessing refactor or legacy risk; scope analysis and target boundary discovery.

## Expectations

- **Scenarios:**
  - WHEN git history is available THEN rank files by change frequency; high churn on a risky unit raises priority; churn ≈ 0 lowers it (zero-interest debt) unless a planned change lands there.
  - WHEN sizing investment THEN follow the value tier: core domain justifies deep plans, supporting moderate ones, generic code is often better replaced; infer it from domain language, dependency direction, and test intensity.
  - WHEN inspecting a target THEN find public methods, exported APIs, public constructors, endpoints, and events, plus their callers and tests.
- **Done means:** Both outputs: (1) risk level, rationale, churn priority, value tier; (2) target level (class/package/module), in-scope files, neighboring context, and explicit out-of-scope work.
- **Quality needs:** Boundaries backed by references, not guesses; no claim beyond the evidence rules.
