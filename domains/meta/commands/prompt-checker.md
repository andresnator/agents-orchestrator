---
description: Evaluate and refine prompt text without executing it
argument-hint: "[prompt text or evaluation request]"
---
# /prompt-checker

## Purpose

Start a prompt evaluation and refinement turn. The command loads the `prompt-structure-writer` skill in Evaluation Mode, applies its rubric, and returns a Prompt Evaluation Report. It never executes the prompt.

## Invocation

```text
/prompt-checker <prompt text>
```

If no prompt text is provided, ask at most one clarifying question before continuing.

## Uses

| Agent/Skill | Purpose |
|---|---|
| `prompt-structure-writer` skill, Evaluation Mode | Applies the 7-dimension evaluation rubric, decision gates, and Prompt Evaluation Report contract |

## Output

Return exactly the Prompt Evaluation Report contract from `prompt-structure-writer` Evaluation Mode:

- **Overall Score** (0-100) and **Verdict** (READY / NEEDS_REFINEMENT / MAJOR_REWRITE)
- Dimension scores across 7 axes
- Issues detected (Critical / Important / Optional)
- Extracted requirements (Explicit / Implicit)
- Refined prompt in a copy-pasteable block
- Change log

## Boundaries

- Do not execute the user's prompt.
- Do not access files, shell commands, MCPs, tools, or web content.
- Do not validate external facts.
- Evaluate and rewrite prompt text only.
- Preserve the user's intent; do not add capabilities or context the user did not provide.
