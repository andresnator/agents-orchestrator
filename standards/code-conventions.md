# Code Conventions

Rules for all code, scripts, and tests. For language-specific rules, load the `oc-conventions` skill.

## General

- Names tell the intent. In a name, use only a common industry abbreviation or a [glossary](glossary.md) abbreviation. Do not invent abbreviations.
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

### Which scenarios to test

Write one test for each different way that a behavior can fail. Start with the normal case.

Then look for boundary, invalid input, and dependency failure cases. Add a test at each limit, for each validation rule, and for each error path that the code has. If the code has none, add none.

A test is a duplicate when no defect makes it fail while the other tests pass. Do not add a test to complete a list.

### Structure

- Use Given / When / Then (or Arrange / Act / Assert).
- One behavior in each test. The name tells the behavior and the expected result.
- Tests are independent: no shared mutable state, no order dependency.
- Test public behavior, not private details.
- Do not test trivial code such as getters, setters, or generated code.
