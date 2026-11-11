# Service Boundary

Loaded by `oc-arch` for `operation=boundary`. Static only: no execution, edits, security review, or schema design. One report per service, at the exact target path under `.ai/architect/reports/`.

- Every row has `file:line`, the discovery method, and the symbol when available. Trace cross-file wiring to the peer or destination; do not trust names.
- Confidence: `high` = direct mechanism plus peer/destination evidence; `medium` = corroborated registration, convention, or cross-file wiring; `low` = plausible, incomplete, or dynamic.
- Reflection, generated code, missing config, or indirection that blocks resolution goes to `Uncertain`.
- An empty mandatory table keeps one row: `No evidence found in inspected scope.` Omit empty `Uncertain` and `Limitations`.

```markdown
# Service Boundary Report

## Scope
<target, inspected paths, exclusions>

## Inputs
| Category | Mechanism | Source/peer | Evidence | Confidence | Notes |
|---|---|---|---|---|---|

## Outputs
| Category | Mechanism | Destination | Evidence | Confidence | Notes |
|---|---|---|---|---|---|

## Uncertain
- <finding, evidence, limit>

## Limitations
- <uninspected or runtime-only behavior>
```
