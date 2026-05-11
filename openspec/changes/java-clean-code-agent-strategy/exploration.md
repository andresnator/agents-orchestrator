## Exploration: java-clean-code-agent-strategy

### Current State
Issue #7 asks for a design investigation into how this harness should represent Java Clean Code and best-practice guidance without creating overlapping, unmaintainable agents. The repository is a Markdown-first instruction harness with no build step; validation is documentation review plus scenario/golden-case checks.

The working tree already contains uncommitted implementation drafts for eight autonomous skills: one language-agnostic core skill, six Java-first specialized skills, and one pragmatic design-pattern skill. Those drafts follow the repository's skill-first convention: skills explain how to perform bounded capabilities, while agents decide when and whether to use them. They also explicitly state that they do not call other skills, which matches the self-contained/agnostic constraint.

Official Java guidance is represented in the drafts: `java-clean-code` treats Oracle Code Conventions as archived historical guidance and points to dev.java as current modern Java guidance; `java-secure-coding` uses Oracle Secure Coding Guidelines for Java SE themes.

### Affected Areas
- `skills/programming-practices-core/` — language-agnostic Clean Code/DRY/KISS/YAGNI baseline for multi-language-aware practice review.
- `skills/java-clean-code/` — Java readability, naming, structure, comments, constants, and maintainability guidance.
- `skills/java-solid-design/` — Java OO/SOLID design review with anti-ceremony boundaries.
- `skills/java-api-design/` — public API, visibility, mutability, modules, and compatibility boundaries.
- `skills/java-immutability-modeling/` — records, value objects, defensive copies, collection ownership, and invariants.
- `skills/java-exception-robustness/` — exception strategy, cleanup, recovery ownership, and failure boundaries.
- `skills/java-secure-coding/` — Java secure-coding review against Oracle guidance themes.
- `skills/design-patterns-pragmatic/` — multi-language-aware pattern selection with Java-specific notes when relevant.
- `skills/README.md` — inventory updated with the new skill set.
- `scenarios/programming-practices-skills/README.md` and `scenarios/README.md` — scenario coverage for self-contained skill behavior and cross-skill independence.
- `templates/skill.md` and `docs/skill-best-practices.md` — governing conventions used to validate the drafts.

### Approaches
1. **Single Java Clean Code mega-skill** — Put all Java practice guidance into one reusable skill.
   - Pros: easiest to discover; minimal inventory growth.
   - Cons: high context load; mixes style, design, API, security, exceptions, and modeling; harder to keep executable and scenario-testable.
   - Effort: Low initially, Medium/High to maintain.

2. **Skill-first modular practice set** — Keep several self-contained skills by coherent practice area, with no inter-skill dependencies.
   - Pros: aligns with repo conventions; keeps each `SKILL.md` compact; supports Java-first depth while preserving one language-agnostic core; matches issue granularity concerns without creating agents prematurely.
   - Cons: larger inventory; requires clear trigger boundaries and README/scenario upkeep.
   - Effort: Medium.

3. **Primary/subagent workflow for Java Clean Code** — Add a coordinating Java Clean Code agent or multi-agent workflow.
   - Pros: useful later for complex audits spanning style, design, security, testing, and refactoring gates.
   - Cons: premature for issue #7; adds coordination cost; violates the desire to avoid one agent per practice unless a decision framework justifies it.
   - Effort: High.

### Recommendation
Proceed with the skill-first modular practice set as the design direction, but treat the current uncommitted drafts as implementation candidates that still need proposal/spec/design validation before final acceptance. The current eight-skill set matches issue #7 better than a mega-skill or multi-agent workflow because each practice area is bounded, self-contained, and independently scenario-testable.

Suggested criteria for future granularity decisions:
- Use a skill when the practice is a reusable bounded workflow with clear triggers, negative triggers, decision gates, and output contract.
- Use a subagent only when the work needs isolated investigation, evidence gathering, or a narrow specialist role beyond reusable instructions.
- Use a primary agent only when coordination across multiple phases, gates, or specialists is the product.
- Use a recipe/doc when the content is mostly explanatory or procedural and does not need an activation contract.

### Risks
- The issue is explicitly an investigation/design chore, but implementation drafts already exist; downstream phases should either ratify them or reduce scope before treating them as complete.
- Skill overlap remains possible between `programming-practices-core`, `java-clean-code`, `java-solid-design`, and existing `refactor`/`refactor-java`; trigger and negative-trigger wording must stay sharp.
- Official-source wording should remain careful: Oracle Code Conventions are archived; dev.java and Oracle Secure Coding Guidelines are the relevant current sources, but the skills should avoid pretending to be exhaustive official compliance documents.
- Scenario coverage is currently README-level golden cases, not executable fixtures; this is acceptable for the repo, but manual review discipline matters.
- Adding eight skills may increase README and registry maintenance burden.

### Ready for Proposal
Yes. The orchestrator should proceed to `sdd-propose` to formalize the skill-first modular strategy, explicitly acknowledge the already-created draft skills, and define acceptance criteria around self-contained skills, official Java guidance treatment, README/scenario coverage, and no premature agent/workflow creation.
