# Project Profile Template

Save this document at `refactorch/project-profile/{repo-key}`. Preserve the topic-key behavior unless a future RefactorCh design deliberately changes it.

```markdown
# Project Profile: <repo-key>

## Scope
- Repository:
- Profile freshness: new | refreshed | unchanged | unknown
- Refresh reason: missing | stale | user-requested | unknown
- Confidence: high | medium | low

## Stack
- Language and version:
- Framework/runtime:
- Build/package tool:

## Commands
- Test:
- Coverage:
- Mutation:
- Lint/format:

## Source Layout
- Production paths:
- Test paths:
- Important config files:

## Architecture Notes
- Main architectural shape:
- Boundaries or modules:
- Dependency direction notes:

## Refactor Safety
- Current safety level: high | medium | low | unknown
- Existing test signal:
- Missing safety signals:
- Risks:

## Evidence Read
- Structure/config/docs inspected:
- Existing profile reference:
- Caller-provided command hints:

## Refresh Triggers
- Refresh this profile when build tooling, test commands, source layout, or major framework/runtime versions change.
```

## Fill Rules

- Use compact bullets, not raw source excerpts or full command logs.
- Mark unknowns explicitly instead of inventing commands, architecture, or test coverage.
- Keep target-specific smells, implementation plans, diffs, and review judgments out of the Project Profile.
