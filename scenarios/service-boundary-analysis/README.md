# Service Boundary Analysis Scenarios

Use these scenarios to validate that `service-boundary-analysis` and `service-boundary-inspector` identify backend inputs and outputs with evidence, confidence, uncertainty, and the required report shape.

Validation is documentation/golden-case review only. Do not run the analyzed application, install dependencies, or modify fixture code.

## Golden fixtures

Golden cases may be represented as code excerpts, compact pseudo-fixtures, or reviewed real files. Each case should record the inspected path/excerpt and expected classification.

## Core cases

| Scenario | Input evidence | Expected classification | Required confidence/evidence behavior |
|---|---|---|---|
| HTTP ingress | Route/controller annotation or router registration such as `POST /orders` | Input: `HTTP/API` | `high` when route and handler are directly visible; evidence includes route excerpt and file/line or `unavailable`. |
| Messaging consumer/listener | Queue/topic listener annotation, subscription registration, or handler binding | Input: `messaging consumers` | `high` for explicit topic/queue; `medium` when topic is config-backed and wiring is indirect. |
| Stream consumer | Kafka stream, Kinesis stream, Pub/Sub stream, or equivalent stream processing registration | Input: `stream consumers` | Evidence names stream mechanism and source when visible; unresolved source lowers confidence. |
| Scheduled job | Cron annotation, scheduler registration, timer worker, or job framework entrypoint | Input: `scheduled jobs` | Evidence includes schedule expression or registration when available. |
| Config-loaded boundary | Endpoint, queue, topic, bucket, cron, or connection value loaded from config and used for boundary wiring | Input: `config loading` | `medium` unless the config key and usage site are both directly connected. |
| CLI/batch/worker entrypoint | Command registration, `main`, batch job, worker bootstrap, or task handler | Input: `CLI/batch/worker entrypoints` | Confidence depends on visible invocation/registration evidence. |
| Database write | ORM save/update/delete, SQL write statement, repository mutation, or transaction write | Output: `database writes` | `high` for direct write calls or SQL; evidence names table/model/repository when visible. |
| External call | HTTP/gRPC client, SDK call, or service client invocation | Output: `external service calls` | `high` when destination/client is direct; `medium`/`low` when endpoint is hidden in config. |
| Cache write/invalidation | Redis/Memcached/cache manager `set`, `put`, `delete`, `evict`, or invalidation call | Output: `cache writes/invalidations` | Evidence includes operation and cache/key context when visible. |
| Event publishing | Broker/event bus `publish`, `send`, `emit`, or producer call | Output: `event publishing` | Evidence includes event/topic/queue when visible; unresolved topic is not `high`. |
| Job scheduling | Enqueue, delayed job, workflow, task queue, or scheduler client call | Output: `job scheduling` | Evidence distinguishes scheduling a future job from handling a scheduled input. |
| Scoped observability | Audit event, metric, trace, or telemetry emission intentionally leaving the process | Output: `scoped observability emissions` | Only classify boundary-relevant emissions; do not list incidental local debug logs. |

## Required report-shape checks

- The report includes exactly one `Inputs` table.
- The report includes exactly one `Outputs` table.
- Each table includes these columns exactly: `category`, `mechanism`, `source/destination`, `file`, `line/range`, `symbol`, `confidence`, `evidence`, `discovery method`, `notes`.
- Every finding uses one supported input or output category from the skill taxonomy.
- Every finding includes concise evidence and a discovery method.
- Missing line/range or symbol values are rendered as `unavailable`, not omitted.
- Confidence is one of `high`, `medium`, or `low`.
- Confidence notes explain indirect, inferred, or incomplete evidence.

## Uncertainty and limitation checks

- Dynamic route registration, reflection, generated wiring, unavailable config, or uninspected paths are listed under `Limitations`.
- Plausible but incomplete boundaries appear under `Uncertain Findings` or in the tables with `low` confidence and rationale.
- Categories without supporting evidence are listed under `Not-Found Categories`.
- The report does not claim completeness beyond the inspected scope.

## Must include

- Mandatory `Inputs` and `Outputs` tables.
- Evidence-backed classifications for representative HTTP/API, consumers/listeners, scheduled jobs, config-loaded boundaries, DB writes, external calls, cache writes, and event publishing.
- At least one golden case that demonstrates lowered confidence due to indirection or missing config.
- Manual review notes confirming no runtime execution or code modification occurred.

## Must not include

- Runtime traces, build/test output, dependency installation, or app execution as validation evidence.
- High-confidence findings based only on naming convention.
- Invented endpoints, topics, queues, clients, or destinations.
- A primary agent requirement for v1 validation.

## Review notes

- Prefer small, readable fixture excerpts over full application dumps.
- When reviewing real code, capture enough location evidence for another reviewer to verify the classification.
- If a case mixes input and output behavior, validate both sides separately in the two mandatory tables.
