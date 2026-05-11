# Tasks: Java Clean Code Agent Strategy

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 900-1,300 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 skills → PR 2 references/docs → PR 3 scenarios/validation |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Ratify eight autonomous `SKILL.md` contracts | PR 1 | Includes SemVer, triggers, boundaries, output contracts. |
| 2 | Ratify local references and discovery docs | PR 2 | Depends on final skill names from PR 1. |
| 3 | Ratify scenarios and validation evidence | PR 3 | Proves autonomy and no refactor overlap. |

## Phase 1: Skill Contract Ratification

- [ ] 1.1 Review `skills/programming-practices-core/SKILL.md` for template sections, autonomy statement, and non-Java transferability.
- [ ] 1.2 Review `skills/java-clean-code/SKILL.md`, `skills/java-solid-design/SKILL.md`, and `skills/java-api-design/SKILL.md` for Java-first depth and narrow negative triggers.
- [ ] 1.3 Review `skills/java-immutability-modeling/SKILL.md`, `skills/java-exception-robustness/SKILL.md`, and `skills/java-secure-coding/SKILL.md` for official-source limits and no compliance claims.
- [ ] 1.4 Review `skills/design-patterns-pragmatic/SKILL.md` for force-based pattern selection and no catalog-dump behavior.

## Phase 2: Reference and Documentation Alignment

- [ ] 2.1 Verify each `skills/*/references/*.md` file embeds necessary guidance locally and does not require loading another skill.
- [ ] 2.2 Update/verify `skills/README.md` lists all eight skills with concise purposes and strict SemVer reminder.
- [ ] 2.3 Check all skill frontmatter `metadata.version` values use strict `MAJOR.MINOR.PATCH`.

## Phase 3: Scenario Coverage

- [ ] 3.1 Update/verify `scenarios/programming-practices-skills/README.md` includes one golden case per accepted skill.
- [ ] 3.2 Verify scenario cases cover “Skill works alone”, “Dependency is requested”, “Source status is explicit”, and “Refactoring overlap found”.
- [ ] 3.3 Update/verify `scenarios/README.md` includes the programming-practices suite.

## Phase 4: Validation

- [ ] 4.1 Manually compare every `SKILL.md` against `templates/skill.md` and `docs/skill-best-practices.md`; fix prompt-dump or missing-section issues.
- [ ] 4.2 Search the eight skill directories for “load/call/use another skill” dependency wording; replace with embedded guidance or boundary context.
- [ ] 4.3 Review triggers against existing `skills/refactor/SKILL.md` and `skills/refactor-java/SKILL.md`; narrow overlapping activation/negative triggers.
- [ ] 4.4 Confirm no primary agents or subagents were added for this change.
