# Proposal: Java Clean Code Agent Strategy

## Intent

Resolve issue #7 by defining how this harness represents Java Clean Code and programming-practice guidance without creating overlapping agents. The change should ratify a Java-first, multi-language-aware, skill-first strategy that keeps each skill autonomous and portable.

## Scope

### In Scope
- Ratify the existing uncommitted drafts as the proposed initial implementation scope: one language-agnostic core skill, six Java-first skills, and one pragmatic design-pattern skill.
- Require every skill to be self-contained: no calling, referencing, or depending on another skill.
- Align each skill with `templates/skill.md` and `docs/skill-best-practices.md`.
- Account for official Java guidance accurately: archived Oracle Code Conventions, current dev.java guidance, and Oracle Secure Coding Guidelines themes.
- Maintain `skills/README.md` and scenario/golden-case docs for independent behavior.

### Out of Scope
- Creating a primary agent or subagent for this issue.
- Claiming exhaustive Java compliance or security certification.
- Executable test automation; validation remains documentation and scenario review.

## Capabilities

### New Capabilities
- `programming-practices-skills`: Defines autonomous programming-practice skills, Java-first specialization, official-guidance boundaries, and scenario validation expectations.

### Modified Capabilities
- None.

## Approach

Proceed with a modular skill-first practice set. Treat the current drafts as implementation candidates to validate and ratify through specs/design: `programming-practices-core`, `java-clean-code`, `java-solid-design`, `java-api-design`, `java-immutability-modeling`, `java-exception-robustness`, `java-secure-coding`, and `design-patterns-pragmatic`. Use sharp activation/negative-trigger wording to avoid overlap with existing `refactor` and `refactor-java` skills.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `skills/programming-practices-core/` | New | Language-agnostic Clean Code/DRY/KISS/YAGNI baseline. |
| `skills/java-*/` | New | Java-first skills for clean code, SOLID, API design, immutability, exceptions, and security. |
| `skills/design-patterns-pragmatic/` | New | Pattern selection guidance with Java notes when relevant. |
| `skills/README.md` | Modified | Inventory includes the proposed skill set. |
| `scenarios/programming-practices-skills/README.md`, `scenarios/README.md` | Modified | Golden cases for autonomous, cross-skill-independent behavior. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Skill overlap with refactoring skills | Med | Keep triggers, negative triggers, and output contracts narrow. |
| Official Java source overclaiming | Med | State source status precisely and avoid compliance claims. |
| Inventory growth | Med | Require README and scenario upkeep for every accepted skill. |

## Rollback Plan

Remove the proposed skill directories, revert README/scenario updates, and drop the new `programming-practices-skills` spec before archive.

## Dependencies

- Issue #7 approved constraints.
- Existing repository skill template and best-practices document.

## Success Criteria

- [ ] Proposal/specs ratify skill-first strategy with no primary/subagent in v1.
- [ ] Each proposed skill is autonomous and template-aligned.
- [ ] Java guidance is accurate and non-overclaiming.
- [ ] README and scenario docs cover discovery and validation.
