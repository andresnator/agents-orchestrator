# Edge-Case Validation Checklist

Walk each branch of the design against these categories before closing the plan. The trigger questions are prompts, not a form to fill: skip a category only when you can say in one line why it does not apply.

## Data boundaries

- Empty, null, zero, exactly one, maximum: what happens at each?
- Empty collections and single-element collections — does iteration/aggregation still hold?
- Odd strings: unicode, very long, whitespace-only, injection-looking content.
- Duplicates: same item twice in input, same event twice in history.

## Error paths

- Every external dependency (network, DB, filesystem, other service) can fail — what happens, and what does the user see?
- Timeouts: slow instead of failed. Is there a bound?
- Partial failure mid-operation: is the system left consistent? Can the operation resume or must it roll back?

## State and concurrency

- Double invocation: what breaks if this runs twice?
- Retries and idempotency: is a retry safe, or does it duplicate effects?
- Races: two actors touching the same state — who wins, and is that acceptable?
- Event ordering: does correctness depend on arrival order? What if it inverts?

## Compatibility and migration

- Existing data: does the change read/write records created before it?
- Existing consumers: does any public contract (API, schema, CLI output) change shape?
- Rollback: if this ships and fails, can it be reverted without data loss?
- Flags: does the change need to coexist with the old path during rollout?

## Security and trust

- Untrusted input crossing a boundary: validated where?
- New paths: is authorization checked on each, not just the happy one?
- Sensitive data: can it leak into logs, errors, or telemetry?

## Scale

- Behavior at large N: does the approach hold at 100x current volume?
- N+1 queries or per-item remote calls hidden in a loop?
- Memory: is anything unbounded accumulated?

## Observability

- If this fails in production, how is it detected — log, metric, alert?
- Can a failed run be distinguished from a never-started one?

## The destinations rule

Each edge that you find gets one destination:

1. **Handled:** a task in the plan covers it.
2. **Out of scope:** `## Notes` has one line that excludes it.
3. **Assumption:** only the user can decide it. Pick the most reasonable default and write `Assumption: <default> (<reason>)` in `## Notes`.

Ask the user only when the decision cannot be undone, for example data deletion or a migration on real data. In a discovery, an edge can stay in `Open questions`.
