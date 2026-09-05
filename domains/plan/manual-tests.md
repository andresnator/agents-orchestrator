# Plan manual tests

Run these cases with `deep-planner` in a disposable repository. Planning may write only under `.ai/deep-planner/`; no case authorizes implementation, Git delivery, or edits to production files.

## Quick path

1. Install the current checkout's `plan,common` domains into a disposable project.
2. Run the affected IDs from the catalog summary in fresh sessions.
3. Inspect the single discovery or plan and confirm source files are unchanged.

### MT-PLAN-DELIVERY

- **Title:** Emit delivery only from explicit intent
- **Coverage key:** `plan/delivery/explicit-control`
- **Applies to:** `domains/plan/skills/execution-plan/**`
- **Preconditions:** Prepare fresh Git-backed copies of the Java fixture with the same clean baseline and no `.ai/deep-planner/` state.
- **Steps:**
  1. In separate copies, request the same executable plan with no Git language, with no commits, with commits per cohesive unit, and with TCR.
  2. Inspect each title boundary, `Delivery` occurrence, work-group skills, source diff, index, `HEAD`, and final response.
- **Expected result:** The neutral request has no `Delivery` line; the other plans contain exactly one matching `Delivery: working-tree`, `Delivery: commit-per-unit`, or `Delivery: tcr` line immediately after the title; no delivery skill appears under a work group; and planning changes only its plan artifact without staging, committing, or pushing.
- **Essential negative variant:** Request two contradictory delivery modes and confirm planning blocks for resolution before writing a plan or mutating Git.
- **Cleanup:** Remove every `.ai/deep-planner/` artifact and delete the disposable copies.

### MT-PLAN-CLEAR-REQUEST

- **Title:** Create one plan for a clear request
- **Coverage key:** `plan/routing/clear-plan-request`
- **Applies to:** `domains/plan/agents/deep-planner.md`, `domains/plan/skills/evidence-first-planning/**`, `domains/plan/skills/execution-plan/**`, `domains/plan/skills/implementation-skill-routing/**`
- **Preconditions:** Use the copied Java fixture and request one localized public method with focused coverage and no open product decision.
- **Steps:**
  1. Ask `deep-planner` to create the execution plan.
  2. Inspect `.ai/deep-planner/plans/`, the plan sections, routed skills, and final response.
- **Expected result:** No route menu appears; exactly one complete plan is created, it recommends `direct` with a reason, and the response includes its path plus `ejecuta el plan <path>`.
- **Cleanup:** Remove `.ai/deep-planner/` and the disposable fixture copy.

### MT-PLAN-AMBIGUOUS-ROUTE

- **Title:** Offer one planning route choice
- **Coverage key:** `plan/routing/ambiguous-intent`
- **Applies to:** `domains/plan/agents/deep-planner.md`
- **Preconditions:** Start a fresh session in a disposable repository with no `.ai/deep-planner/` state.
- **Steps:**
  1. Tell `deep-planner`, `Help me improve order pricing.`
  2. Inspect the closed choice before selecting either option.
- **Expected result:** One choice offers exactly `Create a plan` and `Explore an idea`, no open-text question is forced through the choice UI, and no artifact exists before selection.
- **Cleanup:** Close the session and remove the disposable repository.

### MT-PLAN-WAYFINDER

- **Title:** Explore an open destination without a plan
- **Coverage key:** `plan/wayfinder/open-discovery`
- **Applies to:** `domains/plan/agents/deep-planner.md`, `domains/plan/skills/evidence-first-planning/**`, `domains/plan/skills/domain-modeling/**`, `domains/plan/skills/grilling/**`
- **Preconditions:** Use the copied Java fixture and an idea whose currencies, rate ownership, and rounding rules remain open.
- **Steps:**
  1. Ask `deep-planner` to explore multi-currency pricing and answer one decision question at a time.
  2. Inspect `.ai/deep-planner/discoveries/<slug>.md` and all other changed paths.
- **Expected result:** One discovery records evidence, decisions, open questions, and next step; it has no status field, plan, roadmap, slice, production edit, or execution handoff.
- **Cleanup:** Remove the discovery and disposable fixture copy.

### MT-PLAN-DISCOVERY-TO-PLAN

- **Title:** Convert one discovery without rewriting it
- **Coverage key:** `plan/discovery/plan-conversion`
- **Applies to:** `domains/plan/agents/deep-planner.md`, `domains/plan/skills/evidence-first-planning/**`, `domains/plan/skills/execution-plan/**`, `domains/plan/skills/implementation-skill-routing/**`
- **Preconditions:** Complete a Wayfinder discovery in a disposable repository and record its checksum after resolving every material question.
- **Steps:**
  1. Ask `deep-planner` to convert that exact discovery into a plan.
  2. Compare the discovery checksum and inspect the one new plan.
- **Expected result:** The discovery remains byte-for-byte unchanged, and one new plan carries forward resolved evidence and decisions with complete work, file, skill, and verification sections.
- **Cleanup:** Remove both `.ai/deep-planner/` artifacts and the disposable repository.

### MT-PLAN-LARGE-PLAN

- **Title:** Keep a large plan in one artifact
- **Coverage key:** `plan/planning/grouped-large-plan`
- **Applies to:** `domains/plan/agents/deep-planner.md`, `domains/plan/skills/evidence-first-planning/**`, `domains/plan/skills/execution-plan/**`, `domains/plan/skills/implementation-skill-routing/**`
- **Preconditions:** Use a disposable repository and request coupons, validation, reporting, and test migration with explicit dependencies.
- **Steps:**
  1. Ask `deep-planner` for an executable plan and resolve any material dependency question.
  2. Inspect created files, work groups, dependency edges, `Files`, `Skills`, and execution guidance.
- **Expected result:** Exactly one plan contains ordered work groups and dependencies, assigns at most three relevant skills per group, recommends the evidenced route, and creates no roadmap or slice files.
- **Cleanup:** Remove `.ai/deep-planner/` and the disposable repository.

### MT-PLAN-REFACTOR-SAFETY

- **Title:** Order protection before legacy refactoring
- **Coverage key:** `plan/refactor/safety-sequencing`
- **Applies to:** `domains/plan/agents/deep-planner.md`, `domains/plan/agents/refactor-analyzer.md`, `domains/plan/skills/architecture-impact-review/**`, `domains/plan/skills/behavior-characterization/**`, `domains/plan/skills/characterization-test-scoping/**`, `domains/plan/skills/code-conventions/**`, `domains/plan/skills/cohesion-coupling/**`, `domains/plan/skills/complexity-big-o/**`, `domains/plan/skills/dependency-*/**`, `domains/plan/skills/design-patterns-pragmatic/**`, `domains/plan/skills/dry-business-knowledge/**`, `domains/plan/skills/general-naming-readability/**`, `domains/plan/skills/god-object-detection/**`, `domains/plan/skills/input-validation-preconditions/**`, `domains/plan/skills/java-*/**`, `domains/plan/skills/kiss-yagni/**`, `domains/plan/skills/legacy-code-safety/**`, `domains/plan/skills/logging-observability/**`, `domains/plan/skills/null-safety/**`, `domains/plan/skills/open-closed-principle/**`, `domains/plan/skills/refactor/**`, `domains/plan/skills/risk-assessment/**`, `domains/plan/skills/scope-analysis/**`, `domains/plan/skills/single-responsibility/**`, `domains/plan/skills/spaghetti-code-detection/**`, `domains/plan/skills/tooling-*/**`, `domains/plan/skills/type-contracts/**`
- **Preconditions:** Use a disposable legacy project with observable behavior, weak or absent focused tests, and one medium-risk refactor target.
- **Steps:**
  1. Ask `deep-planner` for a behavior-preserving refactor plan.
  2. Inspect any analyzer brief and the ordering of tooling, seams, characterization, restructuring, and revalidation.
- **Expected result:** Analysis stays read-only and evidence-scoped; the plan protects current behavior before restructuring, separates discovered behavior changes, names rollback/revalidation, and introduces no speculative architecture.
- **Cleanup:** Remove `.ai/deep-planner/` and the disposable project.
