# Design: Java Clean Code Agent Strategy

## Technical Approach

Ratify a skill-first programming-practice family: one general practice skill, six Java-first specialty skills, and one pragmatic pattern skill. This maps to the proposal and `programming-practices-skills` spec by keeping each capability portable, autonomous, compact, and validated through README/scenario review rather than runtime tests.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| v1 execution unit | Autonomous skills only | Primary agent, subagent, mega-skill | Skills match this repo's rule: a skill teaches how; agents decide when. A primary/subagent would add orchestration before there is evidence of multi-phase work. A mega-skill would inflate context and blur boundaries. |
| Granularity | Eight bounded skills | One Java Clean Code skill | Separate clean code, SOLID, API, immutability, exceptions, security, patterns, and general practices so each has sharp triggers, negative triggers, and output contracts. |
| Official Java guidance | Treat as source-aware guidance, not compliance | Claim official certification/compliance | Oracle Code Conventions are archived historical style guidance; dev.java is current platform guidance; Oracle Secure Coding Guidelines provide security themes. Skills must state limits and avoid endorsement/compliance claims. |
| Validation | Manual documentation review plus scenario/golden cases | Automated tests | This Markdown harness has no runtime. Scenarios are the project's default behavioral validation layer. |

## Data Flow

User request/code context
  └─ Agent activation judgment
       └─ One matching autonomous `skills/*/SKILL.md`
            ├─ Optional local `references/*.md`
            └─ Output contract response

No skill calls another skill. Related skills may be mentioned only as boundary context.

## File Changes

| File | Action | Description |
|---|---|---|
| `skills/programming-practices-core/SKILL.md` | Create/ratify | General Clean Code, DRY, KISS, YAGNI, cohesion/coupling review. |
| `skills/java-clean-code/SKILL.md` | Create/ratify | Java readability, naming, structure, comments, constants, maintainability. |
| `skills/java-solid-design/SKILL.md` | Create/ratify | Java OO/SOLID design tradeoffs without mechanical ceremony. |
| `skills/java-api-design/SKILL.md` | Create/ratify | Public/internal Java API surface, visibility, contracts, modules, compatibility. |
| `skills/java-immutability-modeling/SKILL.md` | Create/ratify | Records, value objects, defensive copies, invariants, ownership. |
| `skills/java-exception-robustness/SKILL.md` | Create/ratify | Exception strategy, cleanup, recovery ownership, failure boundaries. |
| `skills/java-secure-coding/SKILL.md` | Create/ratify | Java secure-coding review using Oracle guideline themes without certification claims. |
| `skills/design-patterns-pragmatic/SKILL.md` | Create/ratify | Pattern selection from design forces, with Java notes when relevant. |
| `skills/*/references/*.md` | Create/ratify | Longer guidance kept outside compact `SKILL.md` files. |
| `skills/README.md` | Modify/ratify | Inventory includes accepted skills. |
| `scenarios/programming-practices-skills/README.md` | Modify/ratify | Golden cases for every skill and cross-skill independence. |
| `scenarios/README.md` | Modify/ratify | Suite inventory includes programming-practices scenarios. |

## Interfaces / Contracts

Every skill contract must include: frontmatter with strict SemVer, activation/negative trigger, responsibility, required context, context budget, hard rules, decision gates, execution steps, output contract, validation scenarios, references/assets. Each contract must explicitly say it does not call other skills.

Boundaries:
- `programming-practices-core`: general maintainability; not security/testing/performance/framework setup.
- `java-clean-code`: Java clarity/style; not deep refactoring catalogs or architecture rewrite.
- `java-solid-design`: OO design pressure; not naming cleanup or pattern shopping.
- `java-api-design`: Java API boundaries; not REST product design.
- `java-immutability-modeling`: Java state modeling; not persistence/serialization-only config.
- `java-exception-robustness`: Java failure handling; not logging-only or business recovery invention.
- `java-secure-coding`: implementation security concerns; not formal threat modeling/compliance/crypto design.
- `design-patterns-pragmatic`: pattern selection; not catalog dumps or decoration-by-pattern.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Contract review | Template and best-practice compliance | Manually compare each skill to `templates/skill.md` and `docs/skill-best-practices.md`. |
| Scenario review | Activation, output, and negative triggers | Review `scenarios/programming-practices-skills/README.md` golden cases. |
| Regression review | Overlap with `refactor`/`refactor-java` | Check trigger wording and “must not” cases before acceptance. |

## Migration / Rollout

No migration required. Roll out by ratifying the current draft files, tightening wording where overlap appears, and keeping README/scenario inventories synchronized.

## Open Questions

- [ ] None blocking.

## Risks

- Overlap: `programming-practices-core`, `java-clean-code`, `java-solid-design`, and refactoring skills can collide; mitigate with narrow triggers and negative triggers.
- Drift: official Java guidance wording can age; keep source-status language explicit and conservative.
- Maintenance: eight skills increase inventory/scenario upkeep; require README and scenario updates with every accepted skill change.
