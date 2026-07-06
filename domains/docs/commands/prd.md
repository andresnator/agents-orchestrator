---
description: Select the right PRD skill before starting requirements work
argument-hint: "[what product or feature needs requirements]"
license: MIT
metadata:
  author: andresnator
  version: "1.0.1"
  status: done
---
# /prd

## Purpose

Route PRD requests to the right requirements skill before drafting. This command owns the choice between a rigorous full PRD and a faster PRD Light flow.

## Invocation

```text
/prd <what product or feature needs requirements?>
```

If the subject is missing or unclear, ask one simple triage question before recommending a skill.

## Selection Flow

1. If the user clearly asks for light, quick, simple, MVP, early idea, internal tool, or small/medium feature requirements, recommend `prd-light` and ask for confirmation before loading it.
2. If the user clearly asks for formal, full, cross-team, security-sensitive, compliance-heavy, API-heavy, regulated, or approval-heavy requirements, recommend `prd` and ask for confirmation before loading it.
3. If intent is ambiguous, ask one low-jargon question such as: "Is this a quick/simple plan, or does it need formal review?"
4. After the user confirms, load and follow the selected skill.

## Uses

| Request shape | Recommend | Why |
| --- | --- | --- |
| MVP, internal tool, quick plan, rough requirements | `prd-light` | Fast alignment without ceremony |
| Formal review, cross-team work, regulated/security-sensitive work, complex APIs | `prd` | More rigor, traceability, and review coverage |
| Unclear requirements request | Ask one triage question | The document shape changes the workflow materially |

## Output

Return:

- the recommended skill;
- the reason for the recommendation in one sentence;
- a confirmation question before loading or starting the skill.

Example:

```text
I recommend `prd-light` because this sounds like a quick MVP alignment doc. Want me to start PRD Light?
```

## Boundaries

- Do not duplicate `prd` or `prd-light` skill instructions here.
- Do not start drafting until the user confirms the recommended skill.
- Do not make `prd` and `prd-light` hand off to each other; this selector owns the choice.
- Keep triage language simple and non-jargony.
