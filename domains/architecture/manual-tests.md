# Architecture manual tests

Run these cases against a disposable repository after changing Architecture runtime artifacts. They verify user-visible routing and artifact boundaries; they are not recorded as passed until a person runs them.

## Quick path

1. Install the current checkout's `architecture,common` domains into a disposable project.
2. Run the affected IDs shown by `manual-test-catalog`.
3. Inspect artifacts and confirm production files remain unchanged.

### MT-ARCHITECTURE-MAP

- **Title:** Map current architecture without implementation
- **Coverage key:** `architecture/map/current-state`
- **Applies to:** `domains/architecture/agents/architect.md`, `domains/architecture/commands/arch-map.md`, `domains/architecture/skills/architecture-map/**`, `domains/architecture/skills/architecture-state/**`
- **Preconditions:** Use a small disposable repository with source code and either `docs/` or no documentation directory.
- **Steps:**
  1. Run `/arch-map` for one explicit module and answer only material scope questions.
  2. Inspect the returned paths and compare claims with the cited source lines.
- **Expected result:** Architect creates or refreshes C4-lite files under the existing documentation root, cites verified evidence or labels hypotheses, and creates no plan or source diff.
- **Cleanup:** Delete generated architecture documents and the disposable repository.

### MT-ARCHITECTURE-REVIEW

- **Title:** Rank architecture risks with evidence
- **Coverage key:** `architecture/review/ranked-risks`
- **Applies to:** `domains/architecture/agents/architect.md`, `domains/architecture/commands/arch-review.md`, `domains/architecture/skills/architecture-state/**`, `domains/architecture/skills/repo-issues/**`, `domains/architecture/skills/dependency-security-audit/**`
- **Preconditions:** Use a disposable repository with at least one observable module boundary and dependency manifest.
- **Steps:**
  1. Run `/arch-review` on the repository without authorizing dependency commands.
  2. Inspect the single report under `.ai/architect/reports/` and the final response.
- **Expected result:** The report ranks risks and fitness functions with `path:line` evidence, treats unaudited dependency conclusions as inventory or hypotheses, and returns no execution plan.
- **Cleanup:** Remove `.ai/architect/` and the disposable repository.

### MT-ARCHITECTURE-IDEATE

- **Title:** Produce one architecture decision and plan
- **Coverage key:** `architecture/ideate/adr-plan-handoff`
- **Applies to:** `domains/architecture/agents/architect.md`, `domains/architecture/commands/arch-ideate.md`, `domains/architecture/skills/architecture-ideation/**`, `domains/architecture/skills/architecture-state/**`, `domains/architecture/skills/adr/**`, `domains/architecture/skills/design-patterns-pragmatic/**`, `domains/architecture/skills/kiss-yagni/**`, `domains/architecture/skills/execution-plan/**`, `domains/architecture/skills/implementation-skill-routing/**`, `domains/architecture/skills/code-conventions/**`, `domains/architecture/skills/java-testing/**`
- **Preconditions:** Use a disposable repository with one concrete architecture concern and an existing documentation root.
- **Steps:**
  1. Run `/arch-ideate <concern>` and resolve the material target decision.
  2. Inspect the ADR, `.ai/architect/plans/<slug>.md`, and the final handoff.
- **Expected result:** Exactly one ADR and one neutral plan are created, group 1 establishes fitness guardrails, each group names routed skills, and the response shows `ejecuta el plan <path>` without editing source.
- **Cleanup:** Remove the generated ADR, `.ai/architect/`, and the disposable repository.

### MT-ARCHITECTURE-BOUNDARY

- **Title:** Inspect one service boundary
- **Coverage key:** `architecture/boundary/static-report`
- **Applies to:** `domains/architecture/agents/architect.md`, `domains/architecture/commands/boundary-inspector.md`, `domains/architecture/skills/service-boundary-analysis/**`
- **Preconditions:** Use a disposable repository with one identifiable service or module path.
- **Steps:**
  1. Run `/boundary-inspector <exact-target>`.
  2. Inspect the target-specific report under `.ai/architect/reports/` and compare inputs and outputs with source evidence.
- **Expected result:** Exactly one static boundary report is created for the named target, production files remain unchanged, and no plan or execution handoff is invented.
- **Essential negative variant:** Omit the target and confirm Architect asks one blocking target question before writing a report.
- **Cleanup:** Remove `.ai/architect/` and the disposable repository.
