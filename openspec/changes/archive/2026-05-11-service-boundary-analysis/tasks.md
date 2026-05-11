# Tasks: Service Boundary Analysis

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 320-520 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 skill + docs, PR 2 subagent + docs, PR 3 scenario suite + docs |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Add reusable skill contract and inventory wiring | PR 1 | Includes `skills/service-boundary-analysis/SKILL.md` + `skills/README.md` |
| 2 | Add bounded inspector subagent and agent inventories | PR 2 | Includes `agents/subagents/service-boundary-inspector.md`, `agents/README.md`, `agents/subagents/README.md` |
| 3 | Add scenario/golden validation docs and scenario inventory | PR 3 | Includes `scenarios/service-boundary-analysis/README.md` + `scenarios/README.md` |

## Phase 1: Foundation

- [x] 1.1 Create `skills/service-boundary-analysis/SKILL.md` from `templates/skill.md`; define activation, scope, read-only behavior, and non-goals.
- [x] 1.2 Add boundary taxonomy and required report contract in the skill (exactly one `Inputs` table and one `Outputs` table).
- [x] 1.3 Add evidence/confidence model and rubric (`high|medium|low`), including uncertainty, not-found categories, and limitations rules.
- [x] 1.4 Update `skills/README.md` with one concise inventory row for the new skill.

## Phase 2: Core Implementation Assets

- [x] 2.1 Create `agents/subagents/service-boundary-inspector.md` from `templates/subagent.md` with responsibility and bounded scope.
- [x] 2.2 In the subagent, explicitly declare permissions/forbidden actions (read-only inspection; no code modification; no runtime execution).
- [x] 2.3 In the subagent, define related skill, input shape (analysis request + paths/context), and output contract (mandatory `Inputs`/`Outputs` tables + evidence fields).
- [x] 2.4 Update `agents/README.md` and `agents/subagents/README.md` with inventory entries for `service-boundary-inspector`.

## Phase 3: Scenario/Golden Validation

- [x] 3.1 Create `scenarios/service-boundary-analysis/README.md` from `templates/scenario.md` (or repo scenario conventions) as the validation artifact.
- [x] 3.2 Add representative input golden cases: HTTP/API, consumers/listeners, scheduled jobs, and config-loaded boundaries with expected classifications.
- [x] 3.3 Add representative output golden cases: DB writes, external calls, cache writes, and event publishing with expected classifications.
- [x] 3.4 Add scenario checks for required fields: category, mechanism, source/destination, file, line/range or `unavailable`, symbol or `unavailable`, confidence, evidence, discovery method, notes.
- [x] 3.5 Add scenario checks for uncertainty handling, not-found categories, and limitations disclosure.
- [x] 3.6 Update `scenarios/README.md` with one inventory row for the new scenario suite.

## Phase 4: Documentation Review Validation

- [x] 4.1 Run a documentation review pass verifying the skill and subagent contracts align with `openspec/changes/service-boundary-analysis/specs/service-boundary-analysis/spec.md` requirements.
- [x] 4.2 Run a scenario/golden-case review pass verifying `scenarios/service-boundary-analysis/README.md` covers all required representative categories and confidence/evidence behavior.
- [x] 4.3 Confirm root `README.md` is unchanged unless a specific broad-entry-point justification is documented.
