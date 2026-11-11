# Code Conventions

Rules for all code, scripts, and tests. For language-specific rules, load the `oc-conventions` skill.

## General

- Obey the conventions of nearby code. Report deviations.
- Names tell the intent. Use only abbreviations from the [glossary](glossary.md).
- One function does one thing. One module has one reason to change.
- Comments tell why, not what, in STE ([writing-conventions.md](writing-conventions.md)).
- Do not add code that no test or caller uses.

## Shell scripts

- Start with `set -euo pipefail` unless the script needs different error handling.
- Quote all variables: `"$var"`.
- Run `bash -n <script>` after each change.

## Tests

### No tautological tests

A tautological test cannot fail. Do not write one:

- It calculates the expected value with the code under test.
- It only asserts that a mock returns its configured value.
- It asserts only `not null` or `true`.
- It copies the production algorithm into the assertion.
- It has no assertion.
- It asserts on a fixture that the test itself built. It tests the test, not the production code.

Use literal expected values that you calculated independently. Each test must fail when you break its behavior. To prove this for a doubtful test, break the production code temporarily and see the test fail.

### Minimum scenarios

Test each behavior for these scenarios when they apply:

1. **Happy path:** a typical valid input gives the correct result.
2. **Boundary:** minimum, maximum, empty, and one-element inputs.
3. **Invalid input:** a wrong input gives the specified error.
4. **Failure of a dependency:** the code handles a dependency error.

### Structure

- Use Given / When / Then (or Arrange / Act / Assert).
- One behavior in each test. The name tells the behavior and the expected result.
- Tests are independent: no shared mutable state, no order dependency.
- Test public behavior, not private details.
- Do not test trivial code such as getters, setters, or generated code.

## Validation

Before you complete a change, run:

```bash
make test
```
