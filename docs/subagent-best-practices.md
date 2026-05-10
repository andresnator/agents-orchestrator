# Subagent Best Practices

Subagents are bounded specialists. Create one when a repeated task needs isolation, a stable output contract, and stricter boundaries than a general-purpose agent can reliably provide.

## Quick Path

1. Define the single responsibility and what the subagent must never do.
2. Make it caller-agnostic but domain-specific when the job requires expertise.
3. Maximize operational determinism with explicit gates, inputs, and outputs.
4. Grant the minimum permissions and tools needed for the job.
5. Load only the skills that define the subagent's required method.
6. Validate with scenarios or golden cases.

## Core Principles

| Principle | Rule |
|---|---|
| Single responsibility | A subagent should do one job well, not coordinate a workflow. |
| Caller agnostic | Do not depend on a specific primary agent unless the subagent is explicitly workflow-private. |
| Domain specific | Be specific about the domain when that expertise is the value, such as Java refactoring or prompt evaluation. |
| Deterministic by contract | Use explicit decision rules, blocking conditions, and output schemas. |
| Least privilege | Deny editing, shell, web, or MCP access unless the task truly needs them. |
| Skill intentionality | Load required skills deliberately; never load skills “just in case”. |
| Context discipline | Receive compact inputs and artifact references, not large copied context. |

## What Belongs Where

| Layer | Owns | Should not own |
|---|---|---|
| Primary agent | Routing, phase sequencing, human decisions, synthesis | Deep implementation, raw evidence analysis |
| Subagent | One bounded specialist task | Multi-phase orchestration |
| Skill | The method or rubric the agent follows | Agent identity, routing, broad workflow ownership |
| Scenario | Expected behavior examples and regressions | Hidden implementation details |

## Required Sections

Every subagent should declare:

- **Responsibility**: the one job it performs.
- **Permissions**: tools and actions it may use.
- **Forbidden Actions**: actions it must never perform.
- **Related Skills**: required skills and when to load them.
- **Input Shape**: exact fields or artifact references expected.
- **Decision Rules**: deterministic gates and blocking behavior.
- **Actions**: the happy-path execution steps.
- **Output Contract**: exact response schema.
- **Validation Scenarios**: happy path, missing context, blocked gate, and out-of-scope input.

## Agnostic but Not Generic

Prefer integration agnosticism, not vague generality.

Good:

```markdown
This subagent accepts a target scope and evidence topic keys from any caller. It validates Java test-anchor strength and returns a compact gate result.
```

Bad:

```markdown
This subagent helps with Java projects and testing.
```

The first version is reusable because it does not care who called it. It is still domain-specific because Java test anchoring is the actual job.

## Determinism Checklist

- [ ] Same input should produce the same `status` category.
- [ ] Missing required input returns `blocked`, not best-effort improvisation.
- [ ] Red tests, weak evidence, or unsafe state have explicit stop rules.
- [ ] The output schema is stable enough for a primary agent to parse.
- [ ] The subagent asks at most one blocking question when human input is required.
- [ ] It records waivers or exceptions explicitly instead of silently continuing.

## Skill Loading Rules

Load a skill when it defines the method the subagent must follow.

| Case | Load skill? | Reason |
|---|---:|---|
| Prompt evaluator applying a prompt rubric | Yes | The skill is the core method. |
| Java TCR refactor worker | Yes | `refactor-java` and `tcr` define execution discipline. |
| Simple formatter with a fixed output schema | Usually no | The subagent contract may be enough. |
| Optional background knowledge | No | Avoid unnecessary context and nondeterminism. |

Declare skill usage directly:

```markdown
Load and follow the `refactor-java` and `tcr` skills before taking action.
```

## Permission Patterns

| Subagent type | Suggested permissions |
|---|---|
| Prompt-only reviewer | `edit: deny`, `bash: deny`, `webfetch: deny` |
| Read-only auditor | editing denied; allow only read/search capabilities in runtimes that support tool lists |
| Code worker | allow edit/write only for the target scope; allow shell only for required verification |
| Evidence curator | deny raw source reads when it should consume compact artifacts only |

If a permission is hard to justify in one sentence, remove it.

## Output Contract Pattern

Use compact machine-readable envelopes for orchestration-friendly subagents:

```yaml
status: ready | blocked | complete | failed
gate: <current gate or decision point>
summary: <one short paragraph>
inputs_read:
  - <artifact key or file path>
outputs_written:
  - <artifact key or file path>
blocking_question: <one question, only when blocked>
risk: low | medium | high
```

Avoid returning raw logs, long reports, copied code, or expanded artifacts unless the subagent's whole purpose is to produce that artifact.

## Template

````markdown
---
description: <Specific trigger, job, and hard boundary.>
mode: subagent
permission:
  edit: deny
  bash: deny
  webfetch: deny
license: MIT
metadata:
  author: andresnator
  version: "1.0"
---

# <Subagent Name>

## Responsibility

<One bounded specialist job.>

## Permissions

- May <allowed action>.

## Forbidden Actions

- Do not <unsafe or out-of-scope action>.

## Related Skills

- Load and follow `<skill-name>` when <condition>.

## Input Shape

```yaml
target: <scope>
artifact_refs: []
constraints: []
```

## Decision Rules

- If <required input missing>, return `blocked`.
- If <unsafe condition>, stop and report the gate.

## Actions

1. Validate input.
2. Load required skills.
3. Perform only the bounded task.
4. Return the output contract.

## Output Contract

```yaml
status: ready | blocked | complete | failed
summary: <compact result>
evidence: []
next_recommended: <action or none>
```
````

## Evaluation Checklist

- [ ] Responsibility is one sentence and one job.
- [ ] Description includes trigger and hard boundary.
- [ ] The subagent is caller-agnostic unless intentionally private.
- [ ] Domain specificity is explicit where needed.
- [ ] Permissions follow least privilege.
- [ ] Required skills are named and justified.
- [ ] Decision rules define blocked and failed states.
- [ ] Output contract is stable and compact.
- [ ] Scenarios cover happy path, ambiguity, blocked input, and forbidden execution.

## Sources Used

- Context7 Claude Code agent development guidance: frontmatter, examples, tool restrictions, model inheritance, and separate agent context.
- Context7 OpenCode agent configuration guidance: primary/subagent modes, model selection, prompts, permissions, and task access control.
- Local harness contracts: `agents/subagents/README.md`, `templates/subagent.md`, and `agents/primary/java-refactor-anchor-first.md`.
