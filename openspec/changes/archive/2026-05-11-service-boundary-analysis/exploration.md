## Exploration: service-boundary-analysis

### Current State
Issue #3 defines a broad "service boundary scanner" capability, but the repository currently has no boundary-analysis artifacts or OpenSpec structure. The harness is intentionally lightweight (Markdown-first, no runtime/build/test framework), and existing patterns favor small composable pieces (skill + subagent + scenarios) over heavy orchestration unless real cross-phase coordination is required.

#### Proposed v1 boundary taxonomy (multilingual microservice focus)

**Input categories to recognize**

| Input Category | Typical Signals (language-agnostic heuristics) | Discovery Fields (required in report) | Confidence Guidance |
|---|---|---|---|
| HTTP/API ingress | route/controller/handler declarations, endpoint decorators, router maps | category, mechanism, symbol/hint, file, line, evidence_excerpt, confidence | High when direct route declaration; Medium when inferred by naming only |
| RPC ingress | gRPC/protobuf service bindings, RPC registration | same fields | High when explicit service registration |
| Message/event consumers | consumer/subscriber/handler registration (Kafka, RabbitMQ, SQS, pub/sub) | same fields | High when topic/queue binding is explicit |
| Stream processors | stream topology/processor registration | same fields | Medium–High depending on explicit binding |
| WebSocket/socket ingress | websocket gateway registration, socket event handler mapping | same fields | High when event names and handlers are co-located |
| Scheduled/cron jobs | cron annotations, scheduler registration, interval job wiring | same fields | High when schedule expression is explicit |
| CLI/worker entrypoints | command registration, worker bootstraps, job runner entry files | same fields | Medium–High depending on framework conventions |
| File/object storage ingress | inbound file watcher, object-created triggers, import pipelines | same fields | Medium if trigger inferred indirectly |
| Config-driven dynamic ingress | dynamic route/consumer creation from config | same fields + config_source | Medium by default unless wiring is explicit |

**Output categories to recognize**

| Output Category | Typical Signals (language-agnostic heuristics) | Discovery Fields (required in report) | Confidence Guidance |
|---|---|---|---|
| Database writes | insert/update/delete/upsert/repository save/unit-of-work commit | category, mechanism, target_hint, file, line, evidence_excerpt, confidence | High with explicit write method call |
| External service calls | HTTP/gRPC client calls, SDK/API invocations | same fields | High with explicit client invocation |
| Event/message publishing | producer/publisher/emit/send to topic/queue/stream | same fields | High with explicit topic/queue |
| Cache writes/invalidations | set/put/write/evict/invalidate operations | same fields | High with explicit cache API |
| Filesystem/object writes | file write/upload/storage put operations | same fields | High with explicit write/upload call |
| Search/index writes | indexing, document upserts (search engines) | same fields | Medium–High based on explicit index target |
| Embedding/vector writes | embedding generation + vector DB/store upsert | same fields | High when both generation + persistence signals exist |
| Notifications/outbound messaging | email/SMS/push/webhook dispatch | same fields | High with explicit dispatch API |
| Observability emissions | audit/event logs/metrics/traces as system outputs | same fields | Medium; include only if configured as boundary-relevant |

#### Evidence and confidence model (required)

Every finding SHOULD include:

1. `evidence_location` = `file_path:line_start[-line_end]`
2. `evidence_excerpt` = short literal snippet proving the classification
3. `confidence` = `high | medium | low`
4. `confidence_reason` = one sentence explaining certainty level
5. `discovery_method` = heuristic used (name/keyword/registration-flow/cross-file inference)

### Affected Areas
- `openspec/config.yaml` — initializes OpenSpec mode for this repository.
- `openspec/changes/service-boundary-analysis/exploration.md` — exploration artifact for this change.
- `agents/primary/` — potentially affected only if a coordinating primary agent is justified later.
- `agents/subagents/` — likely home for the boundary-analysis executor subagent.
- `skills/` — likely home for reusable multilingual boundary-analysis method contract.
- `scenarios/` — required for golden-case validation of classification and evidence output shape.

### Approaches
1. **Primary agent + skill + subagent (full coordination)** — Keep issue #3’s original coordinated architecture.
   - Pros: Explicit orchestration, extensible for multi-phase pipelines, easier future DAG growth.
   - Cons: Overhead for v1, duplicates orchestration already available in SDD flows, adds maintenance without clear current need.
   - Effort: Medium

2. **Skill + bounded subagent + scenarios (no new primary in v1)** — Deliver heuristic evidence-backed analysis as a reusable execution unit.
   - Pros: Matches repo preference for composability, minimal surface area, faster iteration on taxonomy/evidence quality, aligns with user refinement (likely no primary in v1).
   - Cons: If future workflow adds many gated phases, a primary may need to be introduced later.
   - Effort: Low/Medium

### Recommendation
Choose **Approach 2** for v1.

Proposal direction in OpenSpec:
- Frame v1 as a **heuristic multilingual service boundary analysis harness** (explicitly not a magical scanner or deep AST parser).
- Specify a **mandatory two-table output contract** (Inputs table + Outputs table) with discovery fields (`file`, `line`, `evidence_excerpt`, `confidence`, `confidence_reason`, `discovery_method`).
- Require a **configuration-loading section** with the same evidence/confidence model.
- Implement as:
  1) one reusable skill defining taxonomy + heuristics + confidence rubric,
  2) one bounded subagent executing the method and producing the report,
  3) scenario/golden cases validating at least HTTP ingress, listener/consumer, DB write, external request, cache write, and config loading evidence.
- Defer introducing a primary agent unless a concrete coordination need appears (e.g., multi-repo fan-out, gating, or chained phases with human approvals).

### Risks
- Heuristic false positives/negatives across diverse stacks.
- Confidence scoring drift if rubric language is vague.
- Boundary between "business logic internals" vs "external/system boundary" may be inconsistently applied.
- Observability outputs can flood results unless explicitly scoped.

### Ready for Proposal
Yes — proceed to `sdd-propose` with a v1 scope centered on skill + subagent + scenarios, mandatory evidence/confidence fields, multilingual heuristics, and explicit non-goals excluding deep AST parsing.
