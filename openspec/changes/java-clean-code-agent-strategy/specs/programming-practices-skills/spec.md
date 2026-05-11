# Programming Practices Skills Specification

## Purpose

Define the programming-practice skill family as autonomous, Java-first, multi-language-aware guidance assets validated through documentation and scenario review.

## Requirements

### Requirement: Autonomous Skill Contracts

Each programming-practice skill MUST be self-contained and MUST NOT call, require, or defer to another skill. Skills MAY mention related repository tools only as boundary context, not as execution dependencies.

#### Scenario: Skill works alone

- GIVEN any proposed programming-practice skill
- WHEN a reviewer reads its contract
- THEN the skill includes its own triggers, negative triggers, workflow, and output contract
- AND it does not require another skill to complete its task

#### Scenario: Dependency is requested

- GIVEN a draft says to load or invoke a different skill
- WHEN the draft is reviewed
- THEN it fails validation until the needed guidance is embedded or the dependency is removed

### Requirement: Template and Best-Practices Compliance

Each skill MUST follow `templates/skill.md` and `docs/skill-best-practices.md`: clear purpose, bounded activation, forbidden actions, concise workflow, and expected output. Skills MUST NOT contain broad prompt dumps.

#### Scenario: Template review passes

- GIVEN a new skill in the family
- WHEN checked against the template and best practices
- THEN all required contract sections are present and compact

#### Scenario: Prompt dump detected

- GIVEN a skill mostly contains generic advice or unbounded instructions
- WHEN reviewed
- THEN it fails until rewritten as a focused reusable contract

### Requirement: Java-First, Multi-Language-Aware Coverage

The family MUST provide Java-first depth for clean code, SOLID, API design, immutability/modeling, exceptions/robustness, and secure coding, while the core and pattern skills SHOULD remain useful across languages without pretending Java rules are universal.

#### Scenario: Java practice request

- GIVEN a Java clean-code or design-practice request
- WHEN the relevant skill activates
- THEN it gives Java-specific guidance with idioms and caveats

#### Scenario: Non-Java practice request

- GIVEN a language-agnostic or non-Java practice request
- WHEN a general skill activates
- THEN it provides transferable principles and labels Java-only guidance as contextual

### Requirement: Official Java Guidance Boundaries

Java skills MUST represent official guidance accurately: archived Oracle Code Conventions as historical, dev.java as current platform guidance, and Oracle Secure Coding Guidelines as security themes. They MUST NOT claim exhaustive compliance, certification, or official endorsement.

#### Scenario: Source status is explicit

- GIVEN a Java skill cites official guidance
- WHEN reviewed
- THEN the status and limits of each source are stated precisely

#### Scenario: Overclaim is present

- GIVEN a skill promises certified Java compliance
- WHEN reviewed
- THEN it fails validation as an unsupported claim

### Requirement: README and Scenario Validation Updates

The change MUST update `skills/README.md`, `scenarios/README.md`, and `scenarios/programming-practices-skills/README.md` so discovery and golden-case validation cover every accepted skill.

#### Scenario: Skill inventory updated

- GIVEN a skill is added, renamed, or removed
- WHEN documentation is reviewed
- THEN the relevant README inventory reflects the final set

#### Scenario: Golden cases cover independence

- GIVEN scenario docs for this family
- WHEN reviewed
- THEN they include cases proving each skill behaves independently without cross-skill calls

### Requirement: No Hidden Agent Overlap

The family MUST remain skill-first and MUST NOT add primary agents, subagents, or hidden-agent behavior. Skill triggers and negative triggers MUST avoid overlap with existing refactoring skills.

#### Scenario: Agent behavior proposed

- GIVEN an implementation adds a primary agent or subagent for this change
- WHEN reviewed against the spec
- THEN it fails as out of scope

#### Scenario: Refactoring overlap found

- GIVEN a skill trigger duplicates `refactor` or `refactor-java` behavior
- WHEN reviewed
- THEN the trigger, negative trigger, or output boundary is narrowed before acceptance
