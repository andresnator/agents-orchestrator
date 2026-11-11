# Plan: <verb-led outcome>
<!-- Explicit delivery only: replace with Delivery: <working-tree|commit-per-unit|tcr>, choosing one value. Otherwise remove. -->

## Intent

- **Goal:** <user-visible or operational outcome>
- **Limits:** <out-of-scope work and forbidden changes>
- **Fails if:** <observable failure or rollback conditions>

## Context

- **Reads:**
  - `<path:line>`: <evidence that changes execution, or `hypothesis`>
- **Never reads:** <excluded sources, or `none`>
- **Persona:** <executor stance, e.g. behavior-preserving Java implementer>
- **Scope:**
  - `<path>`: <planned responsibility>

## Expectations

### Scenarios

#### ADD|MODIFY|REMOVE <capability>/<requirement> | RENAME <old-capability>/<old-requirement> -> <new-capability>/<new-requirement>

- WHEN <condition>
- THEN <observable result>

### Done means

- <command or observable check>

### Quality needs

- <non-functional bar, or `none beyond repository conventions`>

## Method

### Approach

<Chosen shape, constraints, rejected alternatives that matter.>

### Work groups

#### Group 1: <goal>

Files: <paths>
Skills: <comma-separated oc-* names or none>
Depends on: none | <group ids>

- [ ] <small verifiable task>

### Risks and open questions

- <real risk, rollback condition, or unresolved decision>

### Execution guidance

Route: direct | SDD
Reason: <why>
Run: `ejecuta el plan <path>`
