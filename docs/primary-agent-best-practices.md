# Primary Agent Best Practices

Primary agents coordinate workflows. Use one when the work needs routing, phase sequencing, human decision points, delegation boundaries, synthesis, or quality gates.

## Quick Path

1. Define the workflow the primary agent owns and the decisions it must make.
2. Select the lowest tier that fits the risk; if multiple signals apply, the highest-risk tier wins.
3. Keep specialist execution in skills or subagents; the primary agent coordinates.
4. Declare least-privilege permissions and the exact delegation boundary.
5. Return a compact final envelope with status, evidence, artifacts, and handoff.
6. Validate with the tier's required review cases.

## Tier Selection

| Tier | Use when | Required validation |
|---|---|---|
| Compact | One narrow job, no delegation, low-risk tools, simple inputs, and low blast radius. | Happy path + blocked/unsafe input. |
| Standard | Repeated workflow or specialist task with meaningful decisions, scoped edits/tools, state/evidence handling, or 3–4 trigger examples. | Concrete trigger cases, including one blocked gate. |
| Critical | Orchestration, delegation, commits, shell/web/MCP risk, cross-artifact state, destructive potential, or human approvals. | Full review matrix: happy, blocked, unsafe, delegation/tool failure if relevant, recovery/rollback. |

Selection rule: choose the highest triggered tier. Delegation or multi-phase routing makes an agent at least Standard; unsafe delegation, side-effectful tools, shell/edit/commit gates, or recovery requirements make it Critical.

## Mandatory Deterministic Core

Every tier must include: explicit responsibility and hard boundary, forbidden actions, least-privilege permissions/tools, related skills or `None`, input shape, blocked-gate behavior with at most one blocking question, bounded output `status` values, and validation notes.

Frontmatter should stay runtime-aware: OpenCode supports `description`, `mode`, `model`, optional `temperature`, and `permission`; Claude-compatible agents need `name`, concrete triggerable `description` with examples, `model`, optional least-privilege `tools`, structured steps, and explicit output.

## Core Principles

| Principle | Rule |
|---|---|
| Coordinate, do not specialize | Own routing, sequencing, gates, and synthesis; do not become the specialist executor. |
| Coordination stays in the primary | Primary agents may know topology and phase order; subagent contracts must stay caller-generic and task-scoped. |
| Human gates are first-class | Ask one blocking question when a decision is needed instead of guessing. |
| Delegation is bounded | Delegate only a clear specialist task with input, constraints, and expected envelope. |
| Least privilege | Start read-only; allow edit, shell, web, or task access only when the workflow requires it. |
| Evidence before synthesis | Summarize decisions from artifacts and canonical envelopes, not raw unbounded logs. |
| Small and composable | Prefer explicit phases, narrow subagents, and reusable skills over one large do-everything prompt. |

## What Belongs Where

| Layer | Owns | Should not own |
|---|---|---|
| Primary agent | Routing, phase sequencing, human decisions, delegation boundaries, synthesis, quality gates | Deep specialist execution or broad prompt dumps |
| Subagent | One bounded specialist task with a stable envelope | Multi-phase orchestration or deciding unrelated next steps |
| Skill | The method, rubric, or workflow discipline an agent follows | Agent identity or broad routing ownership |
| Validation notes | Expected behavior and regressions | Hidden implementation details |

## Tier Expansion Rules

Compact primary agents use only the mandatory core and a short coordination flow. Standard primary agents add concise routing rules, state/evidence handling, and 3–4 trigger examples. Critical primary agents add full delegation gates, permission/task allowlists or denylists by name/glob where supported, recovery/rollback, audit evidence, and failure routing.

Every primary agent should declare:

- **Responsibility**: the workflow or phase set it coordinates.
- **Permissions**: tools and actions it may use, with scope limits.
- **Forbidden Actions**: execution it must never do directly.
- **Related Skills**: required skills and exact loading conditions.
- **Input Shape**: fields, artifact refs, constraints, and decision inputs.
- **Orchestration Flow**: phases, routing rules, and stop conditions required by its tier.
- **Delegation Contract**: when subagents are used and what they must return; Critical agents must also define delegation failure handling.
- **Decision Rules and Gates**: human approvals, blockers, and safety checks.
- **State and Evidence Handling**: what is read, persisted, summarized, or ignored.
- **Output Contract**: final response schema.
- **Validation Notes**: the tier's required review cases.

## Canonical Template

Use `templates/agent.md` as the canonical primary-agent scaffold and copy-paste source. This guide defines the principles and review checklist; the template owns the exact structure.

When changing the primary-agent contract:

1. Update `templates/agent.md` first.
2. Update this guide only for principles, checklist changes, or contract summaries.
3. Avoid duplicating the full template here; duplicated scaffolds drift.

## Naming and Description

- Name the workflow, not the implementation trick: `sdd-orchestrator`, not `multi-tool-helper`.
- In the description, include the trigger and hard boundary.
- Make private workflow coupling explicit when the primary agent is not reusable.

Good:

```markdown
Coordinates a proposal-to-archive workflow; delegates bounded execution and stops for unresolved human decisions.
```

Bad:

```markdown
Helps with SDD and writes files.
```

## Permission Defaults

| Need | Default |
|---|---|
| Read project docs and artifacts | Allow read/search only. |
| Launch subagents | Allow only named task/delegation targets when the runtime supports it. |
| Edit files | Allow only for workflows that intentionally write artifacts. |
| Run shell commands | Deny unless verification or project inspection explicitly needs it. |
| Web or MCP access | Deny unless the workflow contract names the source and purpose. |

If a permission is hard to justify in one sentence, remove it.

For OpenCode, express restrictions with `permission` and task/delegation allow/deny rules by name or glob where supported. For Claude Code, use specific triggerable descriptions and least-privilege `tools`; omit broad tools unless the workflow needs them. Do not rely on shared subagent context: pass compact inputs and require explicit envelopes back.

## Orchestration Contract

A primary agent should:

1. Validate the input shape and current state.
2. Load only required skills or compact project standards.
3. Choose the next phase, subagent, or human gate.
4. Pass bounded inputs and constraints to any subagent.
5. Keep subagent outputs caller-agnostic (`caller_decides`, `next_task`, `human_decision`, `none`) and map them to concrete routing inside the primary.
6. Verify returned envelopes before continuing.
7. Synthesize decisions, artifacts, and risks into the final output.

It should stop when required inputs are missing, the requested action crosses a forbidden boundary, a quality gate fails, or a human decision is required.

## Delegation Boundaries

Primary agents consume subagent output using the canonical envelope from `templates/subagent.md`:

```yaml
status: ready | blocked | complete | failed
summary: <one short paragraph>
actions_taken:
  - <action performed>
artifacts:
  - <artifact key, file path, or none>
handoff: <next action, blocking question, or none>
```

Use `status` for routing, `summary` for synthesis, `actions_taken` for auditability, `artifacts` for follow-up reads, and `handoff` for the next gate. Do not ask subagents to coordinate unrelated phases.

Primaries may retain private mapping tables from generic subagent `handoff` values to concrete subagents/phases. Keep that mapping out of subagent contracts.

## Output Contract Pattern

Primary-agent final outputs should be compact and orchestration-friendly:

```yaml
status: ready | blocked | complete | failed
summary: <compact synthesis>
phase: <current phase or none>
actions_taken: []
delegations: []
artifacts: []
handoff: <next step, one blocking question, or none>
```

## Validation Notes

Use the tier as the minimum: Compact requires happy path plus blocked/unsafe input; Standard requires concrete trigger cases; Critical requires the full matrix below, including delegation failures and recovery/rollback when side effects are possible.

- **Happy path**: valid input moves through phases, delegates bounded work, and returns `complete` with artifacts and handoff.
- **Missing input**: required context is absent, so the agent returns `blocked` with one question.
- **Forbidden execution**: the request asks the primary agent to do specialist or unsafe work directly, so it stops without side effects.
- **Delegation failure**: a subagent returns `blocked` or `failed`, so the primary agent synthesizes the gate instead of continuing blindly.
- **Human decision gate**: multiple meaningful paths exist, so the agent asks for the decision and waits.

## Evaluation Checklist

- [ ] Responsibility describes coordination, not specialist execution.
- [ ] Tier is declared and justified by the rubric.
- [ ] Permissions are least-privilege and justified by the workflow.
- [ ] Forbidden actions protect subagent boundaries and human decisions.
- [ ] Related skills are loaded only when they define the method.
- [ ] Input shape includes artifact refs, constraints, and decision inputs.
- [ ] Delegation requires `status`, `summary`, `actions_taken`, `artifacts`, and `handoff`.
- [ ] Subagent contracts remain caller-agnostic: no peer names, orchestrator roles, workflow phase labels, or topology language.
- [ ] Quality gates and stop conditions are explicit.
- [ ] Output contract is stable and compact.
- [ ] Validation notes match the tier: Compact happy/blocked, Standard trigger cases, Critical full matrix.

## Non-Normative Existing Agents

Existing primary-agent files are not standards references for this guide. That includes `agents/primary/java-refactor-anchor-first.md`, which should be evaluated separately before any future alignment work.

No existing primary agent must be rewritten just because this guide changed. Add a tier declaration and align section names opportunistically during future edits. Prompt-only evaluation entrypoints are usually Compact; Java refactor orchestrators are Critical because they coordinate gates, state, and side-effectful workers.

## Sources Used

- Context7 Claude Code agent development guidance: frontmatter, trigger examples, tool restrictions, model selection, structured steps, and separate agent context.
- Context7 OpenCode agent configuration guidance: primary/subagent modes, model selection, permissions, and task/delegation access control.
- Local harness contracts: `AGENTS.md`, `agents/primary/README.md`, `docs/subagent-best-practices.md`, and `templates/subagent.md`.
- Canonical primary-agent scaffold: `templates/agent.md`.
