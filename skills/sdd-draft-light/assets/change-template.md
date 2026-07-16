Mode: {interactive|automatic} | TDD: {yes|no} | Judgment: {none|light|verdict-only|full} | Depth: light | Delivery: {none|commit-per-wave}

# Change: {title}

## Why / What

{2-4 sentences: problem, current gap, why now.}

- {Observable change or deliverable}
- {Scope-out boundary worth naming, if any}

## Spec Deltas

### Delta for {capability}

#### ADDED Requirements

##### Requirement: {requirement-name}

The system MUST {observable behavior}.

###### Scenario: {scenario-name}

- **WHEN** {trigger/action}
- **THEN** {observable outcome}

#### MODIFIED Requirements

##### Requirement: {existing-requirement-name}

{Full updated requirement text. This replaces the existing requirement entirely.}

(Previously: {one-line summary of what changed})

###### Scenario: {scenario-name}

- **WHEN** {trigger/action}
- **THEN** {observable outcome}

#### REMOVED Requirements

##### Requirement: {removed-requirement-name}

(Reason: {why removal is correct})
(Migration: {replacement, migration path, or None})

#### RENAMED Requirements

##### Requirement: {old-name} → {new-name}

(Reason: {why rename is correct})
(Migration: {references/tests/docs to update, or None})

## Tasks

- [ ] 1.1 {Concrete action naming real files}
- [ ] 1.2 {Concrete action depending on 1.1}

<!-- Keep under 800 words total. Delta semantics are identical to full-depth
delta files; at archive each capability block merges into
specs/{capability}/spec.md. Omit empty ADDED/MODIFIED/REMOVED/RENAMED
subsections. Tasks: dependency-ordered `- [ ] X.Y` naming real files; only
multi-group changes add `### N. {group}` headings with a `Files:` scope line. -->
