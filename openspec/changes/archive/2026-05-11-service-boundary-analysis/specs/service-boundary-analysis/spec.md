# Service Boundary Analysis Specification

## Purpose

Define a reusable, multilingual, heuristic contract to inspect backend service boundaries and report inputs/outputs with explicit evidence and confidence, without executing or modifying analyzed code.

## Requirements

### Requirement: Reusable Skill Contract

The system MUST define one reusable skill for multilingual backend service boundary analysis. The skill SHALL define a boundary taxonomy, evidence model, confidence rubric, and report contract for read-only inspection.

#### Scenario: Skill is reusable across stacks
- GIVEN repositories with different backend languages/frameworks
- WHEN the skill is applied
- THEN findings are produced using heuristic signals rather than runtime execution or AST-only parsing

### Requirement: Bounded Inspector Subagent

The system MUST define one bounded subagent inspector that uses the skill and produces the report. v1 MUST NOT require adding a new primary agent.

#### Scenario: Inspector remains bounded
- GIVEN a boundary-analysis request
- WHEN the subagent runs
- THEN it executes read-only inspection and emits the required report shape
- AND no primary-agent dependency is required to satisfy v1 behavior

### Requirement: Mandatory Inputs and Outputs Tables

The report MUST contain two mandatory tables named `Inputs` and `Outputs`.

#### Scenario: Report contract validation
- GIVEN a completed analysis report
- WHEN the report is reviewed against the contract
- THEN exactly one `Inputs` table and one `Outputs` table are present

### Requirement: Finding Evidence and Confidence Fields

Each finding in `Inputs` and `Outputs` MUST include: category, mechanism, source/destination, file, line or line range when available, symbol when available, confidence, evidence, and notes.

#### Scenario: Complete finding shape
- GIVEN a classified boundary finding
- WHEN rendered in either table
- THEN all required fields are present
- AND line/symbol fields are explicitly marked unavailable when not derivable

### Requirement: Input Category Coverage

Input findings MUST support at least these categories: HTTP/API, RPC, messaging consumers, stream consumers, WebSocket/SSE, scheduled jobs, CLI/batch/worker entrypoints, file/object triggers, and config loading.

#### Scenario: Representative input classifications
- GIVEN golden-case fixtures containing representative ingress patterns
- WHEN the inspector analyzes them
- THEN findings are classified into the supported input categories with evidence and confidence

### Requirement: Output Category Coverage

Output findings MUST support at least these categories: database writes, external service calls, event publishing, cache writes/invalidations, filesystem/object writes, search/index writes, embeddings/vector writes, notification dispatch, job scheduling, and scoped observability emissions.

#### Scenario: Representative output classifications
- GIVEN golden-case fixtures containing representative egress patterns
- WHEN the inspector analyzes them
- THEN findings are classified into the supported output categories with evidence and confidence

### Requirement: Uncertain, Not-Found, and Limitations Reporting

The report MUST explicitly include uncertain findings, not-found categories, and analysis limitations. Low-confidence or inferred findings SHALL include rationale in notes.

#### Scenario: Transparent uncertainty behavior
- GIVEN dynamic or indirect wiring with incomplete static evidence
- WHEN the inspector evaluates those paths
- THEN uncertain findings are retained with confidence rationale
- AND unsupported/not-found categories and limitations are explicitly documented

### Requirement: Scenario/Golden-Case Validation Contract

The system MUST define scenario/golden-case validation that verifies representative input/output categories and confidence/evidence behavior.

#### Scenario: Golden-case assertions
- GIVEN maintained golden scenarios for boundary analysis
- WHEN validation is executed as documentation/scenario review
- THEN expected classifications and required confidence/evidence fields are verifiable for representative cases
