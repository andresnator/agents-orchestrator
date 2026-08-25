# Plan Flow Test Scenarios

These eight copy-ready scenarios define expected Plan evidence; they are not recorded passes. Model-backed execution is opt-in because it spends credits.

## Setup

- Copy `scripts/fixtures/sdd-agent-routes/java-orders/` to a scratch project.
- Install the SDLC POC profile so requests enter through `sdlc-orchestrator`.
- Start with clean Git state and capture the session tree, `.ai/` artifacts, non-planning diff, and terminal A2A.
- Treat paths as shapes unless a prompt fixes the slug.

## PLAN-BOUNDED-01 — Bounded executable change

Fixture: unmodified `java-orders`.

**Prompt:**

```text
/deep-plan Plan, without implementing, a bounded change that adds a public lineCount() method to Order and focused automated coverage. Preserve pricing and quantity behavior, use the existing Java 17 and JUnit conventions, and produce one execution-ready change rather than a roadmap or investigation.
```

**Expected artifacts/A2A:**

- One `.ai/deep-planner/changes/<change>/change.md` starting with `Status: ready-for-sdd | Source: deep-planner`.
- Behavior scenarios, real `Files:` scopes, `Skills: code-conventions, java-testing`, `mvn -o test`, and `OK plan/deep-plan` with `next=sdd` plus exact handoff path.

**Forbidden behavior:** Production or test edits, roadmap, companion proposal/design/spec/tasks files, or execution choices in the planner artifact.

## PLAN-DECISION-01 — Final technical decision

Fixture: unmodified project; no user-owned product decision.

**Prompt:**

```text
/deep-plan Investigate and decide whether a maximum order-line policy belongs in the Order construction boundary or in an import adapter. Use repository evidence, compare the two options, record edge cases and a verification approach, but do not plan or implement the chosen change.
```

**Expected artifacts/A2A:**

- One `.ai/deep-planner/plans/<slug>.md` starting with `Status: final | Source: deep-planner`.
- Evidence, decision, rationale, rejected alternative, edge cases, verification, and `OK plan/deep-plan` with `next=none`.

**Forbidden behavior:** `change.md`, roadmap, production edits, or `handoff=`.

## PLAN-DISCOVERY-01 — Multi-session discovery alias

Fixture: unmodified project; currency scope and ownership remain unresolved.

**Prompt:**

Turn 1:

```text
/wayfinder Explore how this order-pricing module could support multiple currencies. The supported currencies, exchange-rate source, and rounding ownership are undecided. Resolve repository facts, persist the open product decisions, and do not implement or create an executable handoff.
```

Turn 2:

```text
Continue the exact discovery plan you just created. For this scenario choose EUR and USD, rates supplied by the caller, and final-total rounding owned by OrderPricing. Resolve any remaining repository-derived questions and finish the decision, but leave executable planning for a later /deep-plan invocation.
```

**Expected artifacts/A2A:**

- Turn 1 creates one `.ai/deep-planner/plans/<slug>.md` with `Status: discovery | Source: deep-planner` and grouped open questions.
- Turn 2 updates the same file to `Status: final | Source: deep-planner` and returns `OK plan/deep-plan` with `next=plan`.

**Forbidden behavior:** Ticket files, `.ai/wayfinder/`, a second slug, ready handoff, or one-question-per-session ceremony.

## PLAN-ROADMAP-01 — Oversized goal and first slice

Fixture: unmodified project; roadmap slicing explicitly approved.

**Prompt:**

```text
/deep-plan Plan a staged order-promotion capability covering percentage coupons, coupon validation, per-line discount reporting, and migration of existing bulk-discount tests. This is intentionally oversized and I approve an ordered roadmap. Plan only the smallest first slice that preserves current pricing behavior; leave later slices pending.
```

**Expected artifacts/A2A:**

- `.ai/roadmaps/<goal>.md` starts with `Status: active | Source: deep-planner` and contains ordered `pending|planned` rows with dependencies.
- Exactly one first-slice `change.md`; line one is ready-for-SDD and line two is `Roadmap: <goal> | Slice: 1/<total>`.
- `OK plan/deep-plan`, `next=sdd`, and the exact handoff.
- After completion, `"continúa el roadmap <goal>"` resolves the same roadmap, moves only the first unblocked `pending` row to `planned`, and creates one next-slice change.

**Forbidden behavior:** Multiple `planned|adopted` slices, missing dependencies, implementation, guessed paths, or automatic next-slice planning.

## PLAN-REFACTOR-01 — Protected refactor with reliable coverage

Fixture: add passing characterization coverage for `OrderPricing.total`, `bulkDiscount`, and `discountPerLine` before planning.

**Prompt:**

```text
/refactor-plan Plan a behavior-preserving refactor of OrderPricing that isolates rounding policy and makes discount calculation easier to read. Preserve every public signature, threshold, rate, scale, rounding mode, and observed result. Use the existing characterization coverage as the safety net and do not introduce new pricing behavior.
```

**Expected artifacts/A2A:**

- One ready refactor `change.md` with preservation scenarios, affected paths, `Skills: code-conventions, legacy-code-safety`, rollback, and end-to-end verification.
- At most one analyzer for medium/high risk or two evidence-backed lenses for critical risk.
- `OK plan/refactor` with `next=sdd` and exact handoff.

**Forbidden behavior:** Unsupported hardening tasks, functional changes, excess analyzers, or production edits.

## PLAN-HARDEN-AUTO-01 — Automatic hardening gate

Fixture: unmodified project; `discountPerLine` lacks focused automated coverage.

**Prompt:**

```text
/refactor-plan Plan a behavior-preserving refactor of OrderPricing.discountPerLine that extracts its rounding policy. Do not assume untested behavior is safe; inspect the current coverage and preserve all observed results.
```

**Expected artifacts/A2A:**

- One `.ai/deep-planner/changes/harden-<target>/change.md` ordered as tooling, minimal seams, characterization tests, then coverage baseline.
- Characterization groups use `code-conventions, java-testing, behavior-characterization`; later protected-code groups use `code-conventions, legacy-code-safety`.
- `OK plan/refactor` with `next=sdd`; after SDD, plan the refactor again with `/refactor-plan`.

**Forbidden behavior:** Production refactor tasks, bug fixes, or combined hardening and restructuring.

## PLAN-HARDEN-ALIAS-01 — Explicit hardening alias

Fixture: unmodified project.

**Prompt:**

```text
/harden-plan Prepare OrderPricing.discountPerLine for a later behavior-preserving refactor. Add only the minimum test seams, characterization coverage, and useful coverage baseline. Do not restructure production behavior yet.
```

**Expected artifacts/A2A:**

- Delegation uses `operation=refactor intent=hardening`.
- One ready `harden-*` change and terminal `OK plan/refactor`.

**Forbidden behavior:** `OK plan/hardening`, refactor tasks, or direct implementation.

## PLAN-REFACTOR-GUARD-01 — Functional-change guard

Fixture: unmodified project.

**Prompt:**

```text
/refactor-plan Change the bulk-discount threshold from 100.00 to 200.00 and rename the related method while preserving everything else.
```

**Expected artifacts/A2A:**

- `ASK plan/refactor` recommends routing the threshold change through `/deep-plan`.
- No protected ready handoff exists before the user resolves the route.

**Forbidden behavior:** Treating the threshold change as behavior-preserving, silently splitting scope, or writing refactor/hardening tasks for the new policy.

## Evidence checklist

- Only the primary asks users questions and resumes the same planner child after `ASK`.
- Planner writes stay under `.ai/deep-planner/` or `.ai/roadmaps/`; tracked source stays unchanged.
- Clean returns use at most three lines and contain no artifact bodies or logs.
- Human artifacts remain normal English; Caveman compression is A2A-only.
- Ambiguous or failed cases return exact `ASK`, `BLOCK`, or `FAIL` evidence.
