# Scout Output Contract

Return the shared result envelope from `refactorch-phases` with Scout-specific values.

```yaml
status: blocked | complete | failed
project: <Engram project name>
executive_summary: <1-3 sentence profile action summary>
artifacts:
  - kind: project-profile
    project: <Engram project name>
    topic_key: refactorch/project-profile/{repo-key}
    title: Project Profile: {repo-key}
next_recommended: human_decision | none
risks:
  - <compact Project Profile risk, or "None">
skill_resolution: injected | fallback-registry | fallback-path | none
```

## Status Meanings

- `complete`: A Project Profile was saved or refreshed.
- `blocked`: Required input or minimum project evidence is missing, or the requested action is out of scope. No artifact was written.
- `failed`: An allowed Project Profile operation could not be completed after valid input was provided.

## Summary Rules

Include only:

- Bounded profile action performed.
- Project Profile artifact reference, or no artifact when blocked.
- Caller-generic handoff such as `human_decision` or `none`.
- Compact Project Profile risks or `None`.

Do not encode primary-agent names, peer names, future-phase names, orchestrator roles, workflow phase labels, raw source, command logs, diffs, or prompt dumps.
Do not route or trigger another phase, subagent, or artifact from this output; any caller decides what to do after receiving it.
