# Apply Progress: Java Clean Code Agent Strategy

## Mode

- Execution mode: Standard documentation/scenario review.
- Strict TDD: disabled; this repository has no runtime build/test framework.
- Delivery: maintainer-approved `size:exception` in one apply despite high 400-line budget risk.

## Completed Tasks

- [x] 1.1 Review `skills/programming-practices-core/SKILL.md` for template sections, autonomy statement, and non-Java transferability.
- [x] 1.2 Review `skills/java-clean-code/SKILL.md`, `skills/java-solid-design/SKILL.md`, and `skills/java-api-design/SKILL.md` for Java-first depth and narrow negative triggers.
- [x] 1.3 Review `skills/java-immutability-modeling/SKILL.md`, `skills/java-exception-robustness/SKILL.md`, and `skills/java-secure-coding/SKILL.md` for official-source limits and no compliance claims.
- [x] 1.4 Review `skills/design-patterns-pragmatic/SKILL.md` for force-based pattern selection and no catalog-dump behavior.
- [x] 2.1 Verify each `skills/*/references/*.md` file embeds necessary guidance locally and does not require loading another skill.
- [x] 2.2 Update/verify `skills/README.md` lists all eight skills with concise purposes and strict SemVer reminder.
- [x] 2.3 Check all skill frontmatter `metadata.version` values use strict `MAJOR.MINOR.PATCH`.
- [x] 3.1 Update/verify `scenarios/programming-practices-skills/README.md` includes one golden case per accepted skill.
- [x] 3.2 Verify scenario cases cover “Skill works alone”, “Dependency is requested”, “Source status is explicit”, and “Refactoring overlap found”.
- [x] 3.3 Update/verify `scenarios/README.md` includes the programming-practices suite.
- [x] 4.1 Manually compare every `SKILL.md` against `templates/skill.md` and `docs/skill-best-practices.md`; fix prompt-dump or missing-section issues.
- [x] 4.2 Search the eight skill directories for “load/call/use another skill” dependency wording; replace with embedded guidance or boundary context.
- [x] 4.3 Review triggers against existing `skills/refactor/SKILL.md` and `skills/refactor-java/SKILL.md`; narrow overlapping activation/negative triggers.
- [x] 4.4 Confirm no primary agents or subagents were added for this change.

## Evidence

- Eight accepted skill contracts exist under `skills/` with strict SemVer `1.0.0`, explicit activation/negative triggers, hard rules, decision gates, output contracts, validation scenarios, local references, and an autonomy statement.
- Local references exist for all eight skills and contain embedded guidance rather than web-only links or cross-skill dependencies.
- `skills/README.md` lists all eight accepted skills and restates the strict SemVer rule.
- `scenarios/programming-practices-skills/README.md` includes one golden case per skill plus explicit independence, dependency-request, source-status, and refactoring-overlap validation cases.
- `scenarios/README.md` lists the programming-practices suite.
- No primary agents or subagents were added for this change.

## Deviations

None — implementation matches the design. The high review-budget risk is accepted by maintainer-approved `size:exception`.

## Remaining Tasks

None.
