---
description: <One-line purpose and hard boundary.>
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
