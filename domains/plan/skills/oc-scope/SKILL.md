---
name: oc-scope
description: "Trigger: scope analysis, target boundary discovery. Delimit class/package/module scope."
license: Apache-2.0
metadata:
  author: gentle-ai
  adapted_by: andresnator
  source: gentle-ai/plan-refactor
  version: "2.1.0"
  status: in-progress
---

# Scope Analysis

## Intent

- **Goal:** Delimit whether the target is a class, package, or module, then keep the plan inside that boundary.
- **Limits:** Neighboring context is not in scope; record out-of-scope work explicitly.
- **Fails if:** In-scope files and neighboring context are mixed, or out-of-scope work goes unrecorded.

## Context

- **Reads:** Primary target file(s); callers/consumers via references, imports, routes, LSP, or a code-graph index (for example, Graphify MCP/CLI) when available; existing tests by naming, package, fixtures, integration suites, and build metadata.
- **Never reads:** Code unrelated to the target and its consumers.
- **Persona:** Scope analyst for refactor and plan work.
- **Scope:** Scope analysis and target boundary discovery.

## Expectations

- **Scenarios:**
  - WHEN inspecting a target THEN find public methods, exported APIs, public constructors, endpoints, and events, plus their callers and tests.
- **Done means:** Target level (class/package/module), in-scope files, neighboring context, and explicit out-of-scope work.
- **Quality needs:** Boundaries backed by references, not guesses.
