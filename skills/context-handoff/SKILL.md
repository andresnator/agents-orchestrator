---
name: context-handoff
description: "Context discipline for the Arnes harness: result envelope spec, 30-line handoff spec, 4-file rule, CodeGraph-first ordering, and the envelope-only sdd-orchestrator thread rule. Load when writing or auditing agent handoffs."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

# Context Handoff — Token Discipline
## Result envelope spec

Every subagent's final message is exactly:

```
status: success | partial | blocked
executive_summary: <max 10 lines>
artifacts:
  - <paths written, or "none">
next_recommended: <next phase or action>
risks:
  - <list, or "none">
questions:
  - <only when status is blocked>
```

- `success`: the phase's deliverable exists and is complete.
- `partial`: some of the deliverable exists; the summary and risks say exactly what is missing and why.
- `blocked`: no useful progress possible without user input; `questions[]` is mandatory and the agent stops.

## Handoff spec

`.arnes/changes/<change>/handoffs/<phase>.md`, at most 30 lines. It is an executive summary for the next phase, not a copy of the artifact: decisions made, paths to artifacts, risks, open points. If the next phase needs detail beyond 30 lines, it opens the full artifact itself — the handoff carries pointers, not payloads.

## 4-file rule

Needing more than 3 files to understand something means the exploration approach is wrong. Stop reading and re-query CodeGraph with a narrower question. For the sdd-orchestrator the rule is stricter: it reads no source files at all.

## CodeGraph-first ordering

For any structural or code-understanding question (call flow, dependencies, symbol references, impact, "how does X work"):

1. Check `.codegraph/` at the project root.
2. Use the `codegraph_explore` MCP tool before any grep, glob, or file crawling.
3. If the index is missing, initialize it (`codegraph init <project-root>`) rather than skipping CodeGraph.
4. Fall back to filesystem tools only after CodeGraph init or use fails, and state the fallback in the result envelope.

## SDD Orchestrator thread rule

The sdd-orchestrator thread carries only envelopes and state — never file contents. It reads `state.yaml`, handoff files, and subagent envelopes; it references every artifact by path. Pasting a diff, a source file, or a full artifact into the sdd-orchestrator thread defeats the harness's context budget and is a protocol violation.
