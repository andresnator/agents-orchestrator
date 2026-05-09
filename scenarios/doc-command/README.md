# Scenario Suite: doc-command

Validates `/doc` as a thin shortcut for documentation work. It should select or suggest the smallest matching documentation capability without becoming a heavy router.

## Scenario: Technical documentation request

### Input

```text
/doc Document the auth architecture
```

### Expected Behavior

Treat the request as technical documentation work and prepare it using existing documentation conventions.

### Must Include

- A documentation-focused next action.
- A matching skill when one clearly applies.

### Must Not Include

- Build, test, or implementation steps.
- A multi-step orchestration plan.

### Review Notes

Manual review should confirm the response stays documentation-focused and lightweight.

## Scenario: Missing subject

### Input

```text
/doc
```

### Expected Behavior

Ask at most one clarifying question for what the user wants documented.

### Must Include

- One question.

### Must Not Include

- Multiple option menus.
- Assumed document content.

### Review Notes

The command captures intent; it does not guess the subject.

## Scenario: Matching documentation skill exists

### Input

```text
/doc Write an RFC for replacing our queue provider
```

### Expected Behavior

Select `rfc` and leave detailed execution to that skill.

### Must Include

- `rfc` as the selected skill or next action.
- A concise handoff.

### Must Not Include

- Embedded RFC workflow instructions copied into the command response.

### Review Notes

The command may name the skill, but the skill owns the interview and output contract.

## Scenario: No exact skill match

### Input

```text
/doc Write a short contributor note for how we name folders
```

### Expected Behavior

Produce a concise documentation plan or draft using project standards.

### Must Include

- A small documentation shape.
- Clear scope.

### Must Not Include

- A fabricated specialized skill.
- Heavy orchestration.

### Review Notes

When no exact skill applies, smallest useful documentation wins.

## Scenario: ADR/RFC ambiguity

### Input

```text
/doc Document why we are moving from REST to GraphQL
```

### Expected Behavior

If the distinction affects the output, ask one clarifying question; otherwise choose the smallest useful document shape.

### Must Include

- Either one ADR-vs-RFC clarification or a justified lightweight choice.

### Must Not Include

- Multiple questions.
- Both full ADR and full RFC output at once.

### Review Notes

Ambiguity should not turn `/doc` into a decision engine.
