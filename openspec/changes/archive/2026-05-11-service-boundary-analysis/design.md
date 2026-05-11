# Design: Service Boundary Analysis

## Technical Approach

Deliver v1 as a Markdown-first harness capability: one reusable skill defines the multilingual boundary-analysis method, one bounded subagent applies it read-only, and one scenario suite validates report shape and representative golden cases. This maps directly to the spec requirements for reusable taxonomy, bounded inspection, mandatory `Inputs`/`Outputs` tables, evidence/confidence fields, uncertainty reporting, and scenario validation.

Implementation should start from the repository templates for consistency: `templates/skill.md`, `templates/subagent.md`, and `templates/scenario.md`.

## Architecture Decisions

| Decision | Options considered | Tradeoff | Choice |
|---|---|---|---|
| Runtime shape | Primary + skill + subagent; skill + subagent only | A primary helps future multi-phase coordination but adds v1 overhead and duplicates existing SDD orchestration. | No primary agent in v1. Add one later only for multi-repo fan-out, gated phases, or approval workflows. |
| Analysis mechanism | Deep AST/parser execution; heuristic static inspection | Parsers improve precision per stack but are heavy and language-specific; heuristics are portable but must be honest about uncertainty. | Multilingual heuristic inspection with explicit evidence, discovery method, and confidence. |
| Validation | Unit tests; scenario/golden review | Repo has no runtime test framework; scenarios match existing harness validation. | Scenario suite with golden fixtures/cases and manual review checklist. |

## Data Flow

```text
User request + repo context
        │
        ▼
agents/subagents/service-boundary-inspector.md
        │ loads
        ▼
skills/service-boundary-analysis/SKILL.md
        │ applies taxonomy + heuristics
        ▼
Markdown report: Inputs table, Outputs table, uncertainty/not-found/limitations
        │ validated by
        ▼
scenarios/service-boundary-analysis/README.md
```

## File Changes

| File | Action | Description |
|---|---|---|
| `skills/service-boundary-analysis/SKILL.md` | Create | Defines activation, taxonomy, heuristics, report contract, confidence rubric, and false-certainty guardrails. |
| `agents/subagents/service-boundary-inspector.md` | Create | Bounded read-only inspector that loads the skill and returns the required report. Declares responsibility, permissions/forbidden actions, related skill, input shape, and output contract. |
| `scenarios/service-boundary-analysis/README.md` | Create | Golden-case validation for classification, evidence, confidence, uncertainty, and report shape. |
| `agents/README.md` | Modify | Add inventory row for the new subagent in the general agent inventory. |
| `skills/README.md` | Modify | Add inventory row for the new skill. |
| `agents/subagents/README.md` | Modify | Add inventory row for the new subagent. |
| `scenarios/README.md` | Modify | Add inventory row for the new scenario suite. |
| `README.md` | No change by default | Root recommended entry points remain curated; add only later if this becomes broadly used. |

## Interfaces / Contracts

The inspector report MUST include exactly one `Inputs` table and one `Outputs` table.

### Inputs

| category | mechanism | source/destination | file | line/range | symbol | confidence | evidence | discovery method | notes |
|---|---|---|---|---|---|---|---|---|---|

### Outputs

| category | mechanism | source/destination | file | line/range | symbol | confidence | evidence | discovery method | notes |
|---|---|---|---|---|---|---|---|---|---|

Input taxonomy: HTTP/API, RPC, messaging consumers, stream consumers, WebSocket/SSE, scheduled jobs, CLI/batch/worker entrypoints, file/object triggers, config loading.

Output taxonomy: database writes, external service calls, event publishing, cache writes/invalidations, filesystem/object writes, search/index writes, embeddings/vector writes, notification dispatch, job scheduling, scoped observability emissions.

Heuristics should combine filename/path signals, annotations/decorators, route/handler registration, framework keywords, client/SDK method names, configuration references, and cross-file wiring. Findings inferred only by naming or convention default to lower confidence.

Confidence rubric: `high` only when direct code evidence identifies the boundary and target; `medium` when evidence is indirect but supported by framework conventions or cross-file wiring; `low` when plausible but incomplete. Never upgrade confidence without evidence. Dynamic reflection, generated wiring, missing config, or unresolved indirection MUST be called out.

Reports MUST include sections for uncertain findings, not-found categories, and limitations. Use `unavailable` for missing line/symbol values rather than omitting fields.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Scenario/golden | HTTP ingress, consumers/listeners, scheduled jobs, DB writes, external calls, cache writes, event publishing, config-loaded boundaries | `scenarios/service-boundary-analysis/README.md` defines input snippets, expected classification, required evidence/confidence, and must-not-claim certainty checks. |
| Documentation review | Skill/subagent contracts and README inventory | Manual checklist confirms boundaries, permissions, forbidden actions, and exact report columns. |

## Migration / Rollout

No migration required. This adds Markdown harness assets only and does not modify analyzed applications.

## Open Questions

None blocking v1.
