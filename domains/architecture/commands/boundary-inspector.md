---
description: Inspect backend service inputs and outputs with evidence
argument-hint: "[target path, service, module, or scope]"
---
# /boundary-inspector

## Purpose

Start a read-only static inspection of one backend service, module, or selected paths to identify boundary inputs and outputs with evidence and confidence.

## Invocation

```text
/boundary-inspector <target path, service, module, or scope>
```

If the target or inspectable context is missing, ask one blocking question before continuing.

## Uses

| Layer | Purpose |
|---|---|
| `boundary-inspector` subagent | Executes bounded read-only inspection and returns the command handoff contract |
| `service-boundary-analysis` skill | Method loaded by the subagent for taxonomy, heuristics, confidence scoring, and report format |

## Output

Return the `boundary-inspector` output contract:

- `status: ready | blocked | complete | failed`
- one short `summary`
- read-only `actions_taken`
- `artifacts` containing the Markdown Service Boundary Analysis Report when complete
- `handoff` with the next action, blocking question, or `none`

When complete, the Markdown report must include exactly one `Inputs` table and exactly one `Outputs` table, plus uncertain findings, not-found categories, and limitations.

## Boundaries

- Do not edit files, generate patches, or modify the analyzed repository.
- Do not run shell commands, tests, builds, package managers, servers, migrations, or application code.
- Do not fetch web content or external documentation.
- Delegate to the `boundary-inspector` subagent; do not duplicate the skill taxonomy or heuristics here.
- Preserve uncertainty for dynamic routing, generated wiring, missing config, or uninspected paths.
