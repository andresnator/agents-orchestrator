---
name: refactorch-phases
description: >
  Shared RefactorCh phase contracts for Engram topic keys, artifact references,
  handoff envelopes, and phase-to-phase persistence. Trigger: refactorch phase
  contract, refactorch Engram handoff, target brief, refactor plan, gate review.
license: MIT
metadata:
  author: andresnator
  version: "1.1.2"
---

# RefactorCh Phases

## When to Use

Use this skill for `refactorch` primary and workflow-private subagents when they exchange compact phase artifacts through Engram.

Do not use it for generic refactoring advice, code-smell analysis, Project Profile creation steps, or non-Engram workflows.

## Critical Patterns

- This skill owns shared phase transport contracts; agents own routing and phase behavior.
- The primary stays thin: route phases, pass artifact references, and summarize results.
- Subagents write compact Markdown artifacts to Engram and return only a small routing envelope.
- Pass topic-key references between agents; do not pass raw source, full command logs, diffs, or broad excerpts.
- Read Engram artifacts with exact topic-key search, then retrieve the full observation before using it.
- Write generated artifacts with exact `project`, exact `topic_key`, `scope: "project"`, `type: "architecture"`, and `capture_prompt: false`.
- Use topic-key upserts for reusable or evolving artifacts.

## Engram Read/Write Protocol

### Read

For each required artifact reference:

```txt
mem_search(query: "<exact topic_key>", project: "<project>", scope: "project")
mem_get_observation(id: <matched observation id>)
```

Block before phase work if a required artifact is missing or ambiguous. Do not proceed from search preview text.

After retrieving the full observation, block if it does not correspond to the exact requested `topic_key` and `project`.

### Write

For each generated artifact:

```txt
mem_save(
  title: "<topic_key>",
  topic_key: "<topic_key>",
  type: "architecture",
  project: "<project>",
  scope: "project",
  capture_prompt: false,
  content: "<full compact Markdown artifact>"
)
```

`topic_key` enables upserts. Saving the same reusable or evolving artifact again updates the latest artifact instead of creating a separate handoff contract.

## Topic Keys

```txt
refactorch/project-profile/{repo-key}
refactorch/runs/{run-id}/target-brief
refactorch/runs/{run-id}/refactor-plan
refactorch/runs/{run-id}/gate-review
```

`repo-key` should be a short stable repository identifier, such as the repository folder name or remote slug.

`target-brief`, `refactor-plan`, and `gate-review` are run-scoped. `project-profile` is reusable and repository-scoped.

## Target Brief Contract

The `refactorch` primary owns `target-brief`. It writes this artifact after identifying the requested refactor target and before launching later planning phases.

Minimal Markdown shape:

```markdown
# Target Brief: <target-name>

## Request
- User request:
- Target path or symbol:

## Scope
- In scope:
- Out of scope:

## Known Context
- Project Profile reference:
- Important caller/test hints, if already known:

## Open Questions
- <one question only, or None>
```

## Common Input

Every RefactorCh phase receives the smallest useful handoff:

```yaml
project: <required Engram project name>
repo_path: <absolute repository path>
repo_key: <stable repository identifier>
run_id: <optional for reusable project-profile, required for run-scoped artifacts>
read_artifacts:
  - kind: project-profile | target-brief | refactor-plan | gate-review
    topic_key: <exact Engram topic key>
write_artifact:
  kind: project-profile | target-brief | refactor-plan | gate-review
  topic_key: <exact Engram topic key>
phase_context: <optional compact phase-specific payload>
```

Block before Engram access when `project`, `repo_path`, `repo_key`, or a required `topic_key` is missing.

## Artifact Reference

Use artifact references instead of expanded documents when handing off between agents:

```yaml
artifact_ref:
  kind: project-profile | target-brief | refactor-plan | gate-review
  project: <Engram project name>
  topic_key: <exact Engram topic key>
  title: <document title>
```

If a document is short enough and useful for the next prompt, the caller may include it as context, but the durable handoff remains the Engram artifact reference.

## Shared Result Envelope

Every phase returns this SDD-style envelope:

```yaml
status: blocked | ready | complete | failed
project: <Engram project name>
executive_summary: <1-3 sentence human-readable summary>
artifacts:
  - kind: project-profile | target-brief | refactor-plan | gate-review
    project: <Engram project name>
    topic_key: <Engram topic key>
    title: <document title>
next_recommended: scout | planner | gatekeeper | human_decision | none
risks:
  - <compact risk, or "None">
skill_resolution: injected | fallback-registry | fallback-path | none
```

`skill_resolution` follows the SDD convention: `injected` means project standards were provided by the orchestrator, `fallback-registry` means the agent loaded them from the registry, `fallback-path` means the agent loaded explicit skill paths, and `none` means no extra skills were loaded.

`next_recommended` is v1-only. Future `executor` or `auditor` phases must extend this enum deliberately instead of overloading existing values.

Add phase-specific fields only when they are essential for routing. Do not include expanded peer artifacts or raw evidence in the envelope.

## Reference Protocol

- Keep reusable Project Profile details behind `refactorch/project-profile/{repo-key}`.
- Keep run-scoped documents behind `refactorch/runs/{run-id}/...` topic keys.
- Verify each artifact reference by full observation retrieval before deriving new phase output.
- Preserve compact Markdown artifacts and avoid prompt dumps, raw source, broad source excerpts, or full command logs.

## Agent Ownership Split

| Shared skill owns | Agent files and phase skills own |
|---|---|
| Topic keys | Responsibility |
| Engram read/write protocol | Permissions and forbidden actions |
| Common input shape | Related skills |
| Shared result envelope | Phase-specific behavior |
| Artifact reference format | Filled-in artifact content values |
| Target brief, refactor plan, and gate review handoff contracts | Project Profile creation workflow, templates, and refresh triggers |
