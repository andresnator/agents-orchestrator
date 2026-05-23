---
name: scout
description: "Trigger: scout Project Profile, refactorch profile, Project Profile refresh. Build or refresh reusable RefactorCh Project Profiles."
license: MIT
metadata:
  author: gentleman-programming
  version: "1.2.0"
---

# Scout

## Activation Contract

- A RefactorCh Project Profile is missing for a known repository.
- A human or caller explicitly requests a Project Profile refresh.
- Repository-level structure, build tooling, test commands, source layout, or major framework/runtime versions changed.
- Existing Project Profile data is too incomplete to support a setup handoff.

Do not use this skill for target-specific refactor planning, gate review, execution, auditing, workflow routing, future-phase selection, or generic code analysis.

## Responsibility

Scout owns only reusable RefactorCh Project Profile creation and refresh. Callers own deciding when to invoke Scout, providing or implying repository identity, and deciding what to do after Scout returns.

## Required Context

Minimum context is `project`, `repo_path`, `repo_key`, and `profile_topic_key`. If explicit input is absent, derive safe values from available context such as the active Engram project, working directory, repository name, or existing Project Profile topic.

## Hard Rules

- This skill owns Project Profile creation and refresh workflow only.
- Use `refactorch-phases` for shared topic keys, Engram protocol, artifact references, and shared envelopes; do not copy those conventions here.
- Inspect only bounded repository-level evidence: structure, configuration, documentation, and caller-provided command hints.
- Do not read broad source context, execute shell/build/test commands, edit files, fetch web content, delegate, invoke subagents, depend on wrapper behavior, or route execution to future phases/artifacts.
- Preserve the topic key `refactorch/project-profile/{repo-key}` for reusable Project Profiles.
- Save Project Profiles with `type: "architecture"`, `scope: "project"`, and `capture_prompt: false`.
- Store only compact reusable profile evidence; do not store raw source, full command logs, large documentation excerpts, diffs, or prompt dumps.
- Return `blocked` without writes when required input remains missing, evidence is insufficient, or the caller asks for out-of-scope behavior.
- A wrapper or orchestrator may call this skill, but that relationship is contextual only; this skill processes its input and returns its own output.

## Input Shape

```yaml
project: <required Engram project name>
repo_path: <absolute repository path>
repo_key: <stable repository identifier>
profile_topic_key: refactorch/project-profile/{repo-key}
refresh_reason: missing | stale | user-requested | unknown
constraints: <optional compact scope, safety, or documentation constraints>
```

Process explicit input first. Block before artifact writes only when `project`, `repo_path`, `repo_key`, or `profile_topic_key` still cannot be determined.

## Decision Gates

| Situation | Action |
|---|---|
| Required input remains missing | Return `blocked` with one blocking question and write no artifacts. |
| Request asks for planning, applying, auditing, routing, delegation, shell, edits, web, or broad source reads | Return `blocked` without side effects. |
| Existing evidence cannot support a useful Project Profile | Return `blocked` with the smallest missing-evidence question. |
| Refresh requested without structural trigger | Refresh only when the caller explicitly asks for it. |
| Input and evidence are sufficient | Create or refresh exactly one Project Profile. |

## Permissions and Evidence Policy

Allowed: read bounded repository paths, configuration files, documentation, command hints, and existing Project Profile observations needed for reusable project context.

Forbidden: shell commands, file edits, web fetches, broad implementation reads, target-specific analysis, workflow coordination, subagent invocation, delegation, and future-phase routing.

## Execution Steps

1. Normalize explicit input and safe available context, then reject out-of-scope requests before artifact writes.
2. Follow `refactorch-phases` for Engram read/write protocol, topic keys, artifact references, and shared result envelope.
3. If refreshing, retrieve the existing Project Profile by exact topic key and full observation before deciding what changed.
4. Inspect only repository-level structure, config files, docs, and caller-provided command hints needed for reusable context.
5. Fill the Project Profile template asset with stack, commands, layout, architecture notes, safety signals, gaps, confidence, and refresh rationale.
6. Save or update the Project Profile at `refactorch/project-profile/{repo-key}`.
7. Return this skill's output contract with a Project Profile artifact reference and compact risks.

## Output Contract

- Return the shared result envelope from `refactorch-phases` with Scout-specific values from [references/output-contract.md](references/output-contract.md).
- Include only the bounded profile action, Project Profile artifact reference or no artifact, caller-generic handoff (`human_decision` or `none`), and compact risks.
- Do not encode primary-agent names, peer names, future-phase names, orchestrator roles, workflow phase labels, raw source, command logs, diffs, or prompt dumps.

## References / Assets

- **Project Profile template asset**: Read [assets/project-profile-template.md](assets/project-profile-template.md) when you need the exact Project Profile sections to fill. Use it as the artifact shape; do not copy unrelated repository details into the profile.
- **Refresh triggers**: Read [references/refresh-triggers.md](references/refresh-triggers.md) only when deciding whether an existing Project Profile is stale enough to refresh. Use it as decision guidance, not as extra workflow routing.
- **Output contract**: Read [references/output-contract.md](references/output-contract.md) before returning the final Scout result. Use it to format status, artifact references, handoff, and risks without inventing additional output fields.
