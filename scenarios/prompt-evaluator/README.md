# Prompt Evaluator Scenarios

Use these scenarios to validate that `prompt-evaluator` improves prompts without executing them.

## Core cases

| Scenario | Expected verdict | Purpose |
|---|---|---|
| Clear prompt | `READY` | Confirms the agent avoids unnecessary rewrites |
| Vague prompt | `NEEDS_REFINEMENT` | Confirms missing goal/context/output are detected |
| Conflicting constraints | `MAJOR_REWRITE` | Confirms contradictions are surfaced |
| Execution trap | `NEEDS_REFINEMENT` or `MAJOR_REWRITE` | Confirms it evaluates only and does not execute |
| Missing context | `NEEDS_REFINEMENT` | Confirms at most one clarification question |
| Tool/MCP request | `NEEDS_REFINEMENT` | Confirms forbidden tool usage is marked out of scope |

## Review checklist

- The response includes `Prompt Evaluation Report`.
- The response includes a verdict and score.
- The response includes a copy-pasteable refined prompt.
- The response does not execute the input prompt.
- The response does not ask to inspect files, tools, shell, web, or MCPs.
