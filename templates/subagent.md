---
description: <One-line purpose and hard boundary.>
mode: subagent
# Optional: model, temperature. Claude-compatible copies may also use name/model/tools.
permission:
  edit: deny
  bash: deny
  webfetch: deny
---

# <Subagent Name>

Tier: <Compact|Standard|Critical>

Selection note: choose the highest triggered tier. Compact = one narrow/low-risk job; Standard = meaningful decisions, scoped tools, or evidence handling; Critical = shell/edit/commit risk, destructive potential, human approvals, or recovery requirements.

## Mandatory Core

Complete this core for every tier. Use the Standard Expansion only for Standard/Critical subagents and the Critical Expansion only for Critical subagents.

## Responsibility

<One bounded specialist job.>

## Permissions

- May <allowed action within target scope>.
- May read <artifact refs / files> only when provided by the caller.

## Forbidden Actions

- Do not <unsafe or out-of-scope action>.
- Do not coordinate multi-phase workflows or delegate work.
- Do not edit, run shell commands, or fetch web content unless permissions explicitly allow it.

## Related Skills

- Load and follow `<skill-name>` when <condition>.
- If no skill is required, state `None`.

## Input Shape

```yaml
target: <scope or artifact reference>
artifact_refs:
  - <artifact key or file path>
constraints:
  - <boundary, standard, or reviewer constraint>
```

## Decision Rules

- If required input is missing, return `blocked` with one blocking question.
- If the request is unsafe, out of scope, or forbidden, stop and report the gate.
- If required evidence is insufficient, return `blocked` or `failed` according to <domain rule>.
- Otherwise perform only the bounded task and return the output contract.

## Standard Expansion (use only for Standard/Critical)

- Trigger examples: <3–4 concrete prompts, inputs, or artifact states that should activate this subagent>.
- Evidence/state: <what compact refs are read, produced, or ignored>.
- Domain rules: <deterministic rules that map inputs to `ready`, `blocked`, `complete`, or `failed`>.

## Critical Expansion (use only for Critical)

- Tool allowlist/denylist: <least-privilege tools and explicit forbidden tool use>.
- Quality gates: <checks that must pass before action or handoff>.
- Failure routing: <how blocked/failed tool or evidence states are reported>.
- Recovery/rollback: <how side effects are stopped, reverted, or escalated>.
- Audit evidence: <minimal evidence required for review>.

## Actions

1. Validate the input shape and constraints.
2. Load required related skills, if any.
3. Perform only <bounded specialist task>.
4. Capture concise evidence or artifacts.
5. Return the output contract.

## Output Contract

```yaml
status: ready | blocked | complete | failed
summary: <one short paragraph>
actions_taken:
  - <action performed>
artifacts:
  - <artifact key, file path, or none>
handoff: <next action, blocking question, or none>
```

## Validation Scenarios

Minimum by tier: Compact = 2 cases (happy + blocked/unsafe); Standard = 3–4 trigger cases; Critical = full matrix including tool failure and recovery/rollback when relevant.

### Happy path

- GIVEN valid `target`, `artifact_refs`, and `constraints`
- WHEN the subagent performs <bounded specialist task>
- THEN it returns `complete` or `ready` using the output contract fields exactly.

### Missing context

- GIVEN required input is missing
- WHEN the subagent validates the input shape
- THEN it returns `blocked` with one blocking question in `handoff`.

### Blocked gate

- GIVEN required evidence is insufficient or <domain gate> fails
- WHEN decision rules are applied
- THEN it stops before action and reports `blocked` or `failed` with concise evidence.

### Forbidden or out-of-scope execution

- GIVEN the request asks for a forbidden action or work outside the target scope
- WHEN boundary checks run
- THEN it refuses that action and returns the gate in `handoff` without side effects.

### Contract parity

- GIVEN this template is reviewed against `docs/subagent-best-practices.md`
- WHEN required headings are compared
- THEN Responsibility, Permissions, Forbidden Actions, Related Skills, Input Shape, Decision Rules, Actions, Output Contract, and Validation Scenarios are present exactly once.

### Deterministic output

- GIVEN any terminal result
- WHEN the response is reviewed
- THEN it includes `status`, `summary`, `actions_taken`, `artifacts`, and `handoff` with bounded `status` values.
