# Scout Refresh Triggers

Refresh or create the Project Profile when any of these apply:

- The profile is missing at `refactorch/project-profile/{repo-key}`.
- The user explicitly requests a refresh.
- Build/package tooling changes.
- Test, coverage, mutation, lint, or format commands change.
- Source or test layout changes materially.
- Major language, framework, runtime, or module-boundary assumptions change.
- Existing profile confidence is low or important fields are unknown.

Do not refresh only because a target-specific refactor request arrived. The primary agent should reuse the existing profile unless the request includes one of the structural triggers above.
