# Delta Semantics

- `ADDED Requirements`: new observable behavior that does not replace an existing requirement.
- `MODIFIED Requirements`: full replacement for an existing requirement. Restate the entire requirement and all scenarios that should survive archive; partial blocks can erase behavior.
- `REMOVED Requirements`: behavior intentionally deleted. Include `(Reason: ...)` and `(Migration: ...)`.
- `RENAMED Requirements`: same behavior under a new name. Include old and new names plus `(Reason: ...)` and `(Migration: ...)`.
- New capabilities inside `.ai/orchestrator/changes/` still use delta headings: put all new behavior under `## ADDED Requirements`. Full `## Requirements` specs belong to canonical/base specs, not change deltas.
- Specs say WHAT the system must do, not HOW it is implemented.
- Requirement strength uses RFC 2119 keywords: MUST, SHALL, SHOULD, MAY.
- Scenarios must be testable and use `WHEN` / `THEN`; add `AND` only for additional observable outcomes.
