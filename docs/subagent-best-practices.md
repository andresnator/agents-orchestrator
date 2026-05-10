# Subagent Best Practices

Subagents are bounded specialists. Create one when a repeated task needs isolation, a stable output contract, and stricter boundaries than a general-purpose agent can reliably provide.

## Quick Path

1. Define the single responsibility and what the subagent must never do.
2. Select the lowest tier that fits the risk; if multiple signals apply, the highest-risk tier wins.
3. Make it caller-agnostic but domain-specific when the job requires expertise.
4. Grant the minimum permissions and tools needed for the job.
5. Validate with the tier's required scenarios or golden cases.

## Tier Selection

| Tier | Use when | Required validation |
|---|---|---|
| Compact | One narrow job, no delegation, low-risk tools, simple inputs, and low blast radius. | 2 cases: happy path + blocked/unsafe input. |
| Standard | Repeated workflow or specialist task with meaningful decisions, scoped edits/tools, state/evidence handling, or 3–4 trigger examples. | 3–4 concrete trigger cases, including one blocked gate. |
| Critical | Orchestration, delegation, commits, shell/web/MCP risk, cross-artifact state, destructive potential, or human approvals. | Full matrix: happy, blocked, unsafe, delegation/tool failure if relevant, recovery/rollback. |

Selection rule: choose the highest triggered tier. Delegation or multi-phase routing makes an agent at least Standard; unsafe delegation, side-effectful tools, shell/edit/commit gates, or recovery requirements make it Critical.

## Mandatory Deterministic Core

Every tier must include: explicit responsibility and hard boundary, forbidden actions, least-privilege permissions/tools, related skills or `None`, input shape, blocked-gate behavior with at most one blocking question, bounded output `status` values, and validation scenarios.

Frontmatter should stay runtime-aware: OpenCode supports `description`, `mode`, `model`, optional `temperature`, and `permission`; Claude-compatible agents need `name`, concrete triggerable `description` with examples, `model`, optional least-privilege `tools`, structured steps, and explicit output.

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

## Tier Expansion Rules

Compact subagents use only the mandatory core plus minimal actions. Standard subagents add concise decision rules, evidence/state notes when relevant, and 3–4 concrete trigger examples. Critical subagents add complete guardrails: strict permission/tool allowlists, failure routing, recovery/rollback notes, audit evidence, and any runtime-specific denial rules.

All subagents should declare:

- **Responsibility**: the one job it performs.
- **Permissions**: tools and actions it may use.
- **Forbidden Actions**: actions it must never perform.
- **Related Skills**: required skills and when to load them.
- **Input Shape**: exact fields or artifact references expected.
- **Decision Rules**: deterministic gates, tier-specific stop rules, and blocking behavior.
- **Actions**: the happy-path execution steps.
- **Output Contract**: exact response schema.
- **Validation Scenarios**: the tier's required golden cases.

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

For OpenCode, prefer explicit `permission` allow/deny controls and deny delegation/task access unless the subagent's job truly needs it. For Claude Code, list only least-privilege `tools` when tools are needed; omit broad tools for prompt-only specialists. Subagents run with separate context, so pass compact artifact references instead of assuming caller state.

## Output Contract Pattern

Use compact machine-readable envelopes for orchestration-friendly subagents:

```yaml
status: ready | blocked | complete | failed
summary: <one short paragraph>
actions_taken:
  - <action performed>
artifacts:
  - <artifact key, file path, or none>
handoff: <next action, blocking question, or none>
```

Avoid returning raw logs, long reports, copied code, or expanded artifacts unless the subagent's whole purpose is to produce that artifact.

## Canonical Template

Use `templates/subagent.md` as the canonical scaffold. This guide defines the principles, required sections, and evaluation checklist; the template owns the exact copy-paste structure.

When changing the subagent contract:

1. Update `templates/subagent.md` first.
2. Update this guide only for principles, checklist changes, or contract summaries.
3. Avoid duplicating the full template here; duplicated scaffolds drift.

## Evaluation Checklist

- [ ] Responsibility is one sentence and one job.
- [ ] Tier is declared and justified by the rubric.
- [ ] Description includes trigger and hard boundary.
- [ ] The subagent is caller-agnostic unless intentionally private.
- [ ] Domain specificity is explicit where needed.
- [ ] Permissions follow least privilege.
- [ ] Required skills are named and justified.
- [ ] Decision rules define blocked and failed states.
- [ ] Output contract is stable and compact.
- [ ] Scenario count matches the tier: Compact 2, Standard 3–4, Critical full matrix.

## Migration Notes

No existing subagent must be rewritten just because this guide changed. Align section names and add a tier declaration opportunistically during future edits. Current prompt-only evaluators are usually Compact; Java evidence/test-anchor workers are usually Standard or Critical depending on side effects; TCR/code-writing workers are Critical.

## Sources Used

- Context7 Claude Code agent development guidance: frontmatter, examples, tool restrictions, model inheritance, and separate agent context.
- Context7 OpenCode agent configuration guidance: primary/subagent modes, model selection, prompts, permissions, and task access control.
- Local harness contracts: `AGENTS.md`, `agents/subagents/README.md`, and `templates/subagent.md`.
