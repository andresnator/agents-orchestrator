# Proposal: Service Boundary Analysis

## Intent

Create a v1 heuristic, evidence-backed harness that helps agents identify backend microservice inputs and outputs across common languages/frameworks without running or modifying the analyzed application.

## Scope

### In Scope
- Reusable skill defining multilingual boundary taxonomy, heuristics, report format, and confidence rubric.
- One bounded subagent inspector that applies the skill and emits a report with mandatory `Inputs` and `Outputs` tables.
- Scenario/golden-case validation for HTTP ingress, consumers/listeners, scheduled work, DB writes, external calls, cache writes, publishing, and config-loaded boundaries.
- README inventory updates for added skill, subagent, and scenarios.

### Out of Scope
- New primary agent for v1 unless later design proves coordination is needed.
- Deep AST parsers, application execution, code modification, or complete certainty claims for dynamic framework behavior.

## Capabilities

### New Capabilities
- `service-boundary-analysis`: Heuristic backend microservice boundary inspection, evidence/confidence reporting, and scenario validation contract.

### Modified Capabilities
- None.

## Approach

Implement the smallest composable v1: skill + one inspector subagent + golden scenarios. The skill defines input/output categories, multilingual framework signals, mandatory report tables, and per-finding evidence fields: location, excerpt, confidence, confidence reason, and discovery method. The subagent performs read-only inspection and explicitly labels uncertainty.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `skills/` | New | Service boundary analysis method contract. |
| `agents/subagents/` | New | Bounded read-only boundary inspector. |
| `scenarios/` | New | Golden cases for classification and report shape. |
| `README.md`, nested READMEs | Modified | Inventory updates only; root entry points stay curated. |
| `openspec/specs/service-boundary-analysis/spec.md` | New | Capability spec created by spec phase. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| False positives/negatives across stacks | High | Require evidence, confidence, and discovery method per finding. |
| Confidence scoring drift | Medium | Centralize rubric in the skill and validate with scenarios. |
| Report noise from observability/internal calls | Medium | Scope output categories and mark boundary relevance explicitly. |

## Rollback Plan

Remove the new skill, subagent, scenarios, README inventory entries, and `service-boundary-analysis` spec/change artifacts. No runtime state or analyzed application code is touched.

## Dependencies

- Existing repository conventions for skills, subagents, READMEs, and scenario/golden-case validation.
- Source issue: https://github.com/andresnator/agents-orchestrator/issues/3

## Success Criteria

- [ ] Report contract includes mandatory `Inputs` and `Outputs` tables.
- [ ] Every finding includes where it was found plus evidence/confidence fields.
- [ ] Scenario/golden cases validate representative input/output categories.
- [ ] No primary agent is introduced in v1 without documented coordination need.
