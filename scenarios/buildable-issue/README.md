# Scenario Suite: buildable-issue

Validates the renamed `buildable-issue` skill and its compatibility with legacy SDD-ready issue language.

## Scenario: New buildable issue

### Input

```text
Create a buildable issue for adding password reset emails.
```

### Expected Behavior

Create an agent-ready issue structure with intent, type, scope, acceptance scenarios, technical context, constraints, and priority.

### Must Include

- Duplicate issue search expectation.
- Complete issue template sections.
- Given/When/Then acceptance scenarios.

### Must Not Include

- Placeholder text left in the issue body.
- Implementation work.

### Review Notes

Manual review should confirm the issue can be picked up without guessing scope.

## Scenario: Existing issue enrichment

### Input

```text
Enrich issue #42 so it is ready to build.
```

### Expected Behavior

Fetch or reference the existing issue, preserve useful context, interview for missing fields, and update it with the structured template.

### Must Include

- Existing issue preservation.
- Gap-filling behavior.
- `sdd-ready` label when complete.

### Must Not Include

- Blind replacement of useful issue content.
- Creation of a duplicate issue.

### Review Notes

The skill should improve the existing issue rather than fork the workflow.

## Scenario: Preserved SDD-ready structure

### Input

```text
Write an implementation-ready ticket for adding audit logs.
```

### Expected Behavior

Preserve the original SDD-ready intake contract: intent, scope, constraints, acceptance scenarios, and technical context.

### Must Include

- In-scope and out-of-scope boundaries.
- Observable acceptance scenarios.
- Technical context section.

### Must Not Include

- A vague issue with only a title and description.

### Review Notes

The rename changes the public capability name, not the build-ready issue quality bar.

## Scenario: Legacy trigger compatibility

### Input

```text
Create an SDD-ready issue for this change.
```

### Expected Behavior

Resolve the request to `buildable-issue` and prefer the new name in the response while preserving the `sdd-ready` label when appropriate.

### Must Include

- `buildable-issue` as the preferred skill name.
- Compatibility with legacy SDD-ready wording.

### Must Not Include

- A separate `sdd-issue` alias file requirement.
- Conflicting skill names.

### Review Notes

Compatibility lives in trigger wording and docs, not duplicate skill files.
