# Plan manual tests

Run these cases with `orchestraitor` loading `oc-plan-deep` (or `oc-plan-light` where named) in a disposable repository. Planning may write only under `.ai/deep-planner/`; no case authorizes implementation, Git delivery, or edits to production files.

## Quick path

1. Install the current checkout's `orchestration,plan,common` domains into a disposable project.
2. Run the affected IDs from the catalog summary in fresh sessions.
3. Inspect the single discovery or plan and confirm source files are unchanged.

### MT-PLAN-DELIVERY

- **Title:** Emit delivery only from explicit intent
- **Coverage key:** `plan/delivery/explicit-control`
- **Applies to:** `domains/plan/skills/oc-plan-format/**`
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
- **Applies to:** `domains/plan/skills/oc-plan-deep/**`, `domains/plan/skills/oc-evidence/**`, `domains/plan/skills/oc-plan-format/**`, `domains/plan/skills/oc-routing/**`
- **Preconditions:** Use the copied Java fixture and request one localized public method with focused coverage and no open product decision.
- **Steps:**
  1. Ask `orchestraitor` for a deep plan of that change.
  2. Inspect `.ai/deep-planner/plans/`, the IDSD sections (every ICE field and Method), routed skills, and final response.
- **Expected result:** No route menu appears; exactly one complete plan is created, it recommends `direct` with a reason, and the response includes its path plus `ejecuta el plan <path>`.
- **Cleanup:** Remove `.ai/deep-planner/` and the disposable fixture copy.

### MT-PLAN-AMBIGUOUS-ROUTE

- **Title:** Offer one planning route choice
- **Coverage key:** `plan/routing/ambiguous-intent`
- **Applies to:** `domains/plan/skills/oc-plan-deep/**`
- **Preconditions:** Start a fresh session in a disposable repository with no `.ai/deep-planner/` state.
- **Steps:**
  1. Tell `orchestraitor`, `Help me improve order pricing.`
  2. Inspect the closed choice before selecting either option.
- **Expected result:** One choice offers exactly `Create a plan` and `Explore an idea`, no open-text question is forced through the choice UI, and no artifact exists before selection.
- **Cleanup:** Close the session and remove the disposable repository.

### MT-PLAN-WAYFINDER

- **Title:** Explore an open destination without a plan
- **Coverage key:** `plan/wayfinder/open-discovery`
- **Applies to:** `domains/plan/skills/oc-plan-deep/**`, `domains/plan/skills/oc-evidence/**`, `domains/plan/skills/oc-domain/**`, `domains/plan/skills/oc-interview/**`
- **Preconditions:** Use the copied Java fixture and an idea whose currencies, rate ownership, and rounding rules remain open.
- **Steps:**
  1. Ask `orchestraitor` to explore multi-currency pricing and answer one decision question at a time.
  2. Inspect `.ai/deep-planner/discoveries/<slug>.md` and all other changed paths.
- **Expected result:** One discovery records evidence, decisions, open questions, and next step; it has no status field, plan, roadmap, slice, production edit, or execution handoff.
- **Cleanup:** Remove the discovery and disposable fixture copy.

### MT-PLAN-DISCOVERY-TO-PLAN

- **Title:** Convert one discovery without rewriting it
- **Coverage key:** `plan/discovery/plan-conversion`
- **Applies to:** `domains/plan/skills/oc-plan-deep/**`, `domains/plan/skills/oc-evidence/**`, `domains/plan/skills/oc-plan-format/**`, `domains/plan/skills/oc-routing/**`
- **Preconditions:** Complete a Wayfinder discovery in a disposable repository and record its checksum after resolving every material question.
- **Steps:**
  1. Ask `orchestraitor` to convert that exact discovery into a plan.
  2. Compare the discovery checksum and inspect the one new plan.
- **Expected result:** The discovery remains byte-for-byte unchanged, and one new plan carries forward resolved evidence and decisions with complete ICE fields, Context `Scope`, work-group `Files`/`Skills`, and `Done means`.
- **Cleanup:** Remove both `.ai/deep-planner/` artifacts and the disposable repository.

### MT-PLAN-LARGE-PLAN

- **Title:** Keep a large plan in one artifact
- **Coverage key:** `plan/planning/grouped-large-plan`
- **Applies to:** `domains/plan/skills/oc-plan-deep/**`, `domains/plan/skills/oc-evidence/**`, `domains/plan/skills/oc-plan-format/**`, `domains/plan/skills/oc-routing/**`
- **Preconditions:** Use a disposable repository and request coupons, validation, reporting, and test migration with explicit dependencies.
- **Steps:**
  1. Ask `orchestraitor` for a deep executable plan and resolve any material dependency question.
  2. Inspect created files, work groups, `Depends on:` edges, `Files`, `Skills`, and execution guidance.
- **Expected result:** Exactly one plan contains ordered work groups and dependencies, assigns at most three relevant skills per group, recommends the evidenced route, and creates no roadmap or slice files.
- **Cleanup:** Remove `.ai/deep-planner/` and the disposable repository.

### MT-PLAN-REFACTOR-SAFETY

- **Title:** Order protection before legacy refactoring
- **Coverage key:** `plan/refactor/safety-sequencing`
- **Applies to:** `domains/plan/skills/oc-plan-deep/**`, `domains/plan/skills/oc-refactor-lens/**`, `domains/plan/skills/oc-arch-impact/**`, `domains/plan/skills/oc-characterize/**`, `domains/plan/skills/oc-char-scope/**`, `domains/plan/skills/oc-conventions/**`, `domains/plan/skills/oc-coupling/**`, `domains/plan/skills/oc-big-o/**`, `domains/plan/skills/oc-dip/**`, `domains/plan/skills/oc-seams/**`, `domains/plan/skills/oc-patterns/**`, `domains/plan/skills/oc-dry/**`, `domains/plan/skills/oc-naming/**`, `domains/plan/skills/oc-god-object/**`, `domains/plan/skills/oc-preconditions/**`, `domains/plan/skills/oc-java-*/**`, `domains/plan/skills/oc-kiss/**`, `domains/plan/skills/oc-legacy/**`, `domains/plan/skills/oc-logging/**`, `domains/plan/skills/oc-null-safety/**`, `domains/plan/skills/oc-ocp/**`, `domains/plan/skills/oc-refactor/**`, `domains/plan/skills/oc-risk/**`, `domains/plan/skills/oc-scope/**`, `domains/plan/skills/oc-srp/**`, `domains/plan/skills/oc-spaghetti/**`, `domains/plan/skills/oc-tooling-*/**`, `domains/plan/skills/oc-types/**`
- **Preconditions:** Use a disposable legacy project with observable behavior, weak or absent focused tests, and one medium-risk refactor target.
- **Steps:**
  1. Ask `orchestraitor` for a deep behavior-preserving refactor plan.
  2. Inspect any `oc-refactor-lens` brief and the ordering of tooling, seams, characterization, restructuring, and revalidation.
- **Expected result:** Analysis stays read-only and evidence-scoped; the plan protects current behavior before restructuring, separates discovered behavior changes, names rollback/revalidation, and introduces no speculative architecture.
- **Cleanup:** Remove `.ai/deep-planner/` and the disposable project.

### MT-PLAN-LIGHT

- **Title:** Draft a quick plan without subagents
- **Coverage key:** `plan/light/quick-plan`
- **Applies to:** `domains/plan/skills/oc-plan-light/**`, `domains/plan/skills/oc-plan-format/**`
- **Preconditions:** Use the copied Java fixture and request one localized, reversible change with no open product decision.
- **Steps:**
  1. Ask `orchestraitor` for a quick plan, then ask it to save the plan.
  2. Inspect delegations, the IDSD sections, `.ai/deep-planner/plans/`, and source files.
- **Expected result:** No subagent or refactor lens runs; the chat plan has every ICE field and Method part and recommends `direct`; the file appears only after the save request; source files are unchanged.
- **Essential negative variant:** Request a quick plan for a public contract migration and confirm it recommends `oc-plan-deep` instead of writing a light plan.
- **Cleanup:** Remove `.ai/deep-planner/` and the disposable fixture copy.
