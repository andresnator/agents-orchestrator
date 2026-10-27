---
name: oc-boundary
description: "Trigger: service boundary analysis, microservice inputs/outputs, API/consumer/output mapping. Map one backend boundary with evidence and confidence."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "3.1.0"
---

# Service Boundary Analysis

## Intent

- **Goal:** One compact report of a backend service's inputs and visible outputs with evidence and confidence.
- **Limits:** Static only: no execution, edits, security review, schema design, or certainty for dynamic wiring.
- **Fails if:** A row lacks `file:line` and discovery method; confidence is inflated; names are trusted without tracing cross-file wiring and each candidate to its peer/destination.

## Context

- **Reads:** Manifests and target files (language/framework); routes, annotations, registrations, imports, handlers, clients, repositories, publishers, schedulers, config, healthy graph edges.
- **Never reads:** Local debug logs as outputs.
- **Persona:** Static boundary tracer.
- **Scope:** One backend service, module, worker, or API; require target, scope, exclusions, report path. One report per service.

## Expectations

- **Scenarios:** WHEN reflection, generation, missing config, or indirection blocks resolution THEN list under `Uncertain`.
- **Done means:** One report below. Keep empty mandatory tables with `No evidence found in inspected scope.`; omit empty `Uncertain` and `Limitations`.
- **Quality needs:** Group equivalent boundaries; include symbol when available.

## Method

Inputs: HTTP/API, RPC, messages/streams, WebSocket/SSE, scheduled jobs, CLI/batch/workers, file/object triggers, config loading.
Outputs: database writes, external calls, event publishing, cache changes, file/object writes, search/vector writes, notifications, job scheduling, boundary-relevant telemetry.

Confidence: `high` direct mechanism and peer/destination evidence; `medium` corroborated registration, convention, or cross-file wiring; `low` plausible, incomplete, or dynamic.

```markdown
# Service Boundary Report

## Scope
<target, inspected paths, exclusions>

## Inputs
| Category | Mechanism | Source/peer | Evidence | Confidence | Notes |
|---|---|---|---|---|---|

## Outputs
| Category | Mechanism | Destination | Evidence | Confidence | Notes |
|---|---|---|---|---|---|

## Uncertain
- <finding, evidence, limit>

## Limitations
- <uninspected or runtime-only behavior>
```
