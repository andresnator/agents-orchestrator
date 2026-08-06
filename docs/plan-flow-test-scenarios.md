# Plan Flow Test Scenarios

Copy-ready hypothetical prompts for the five Plan behaviors and their safety aliases. These scenarios define expected evidence; they are not recorded test passes. Model-backed execution is opt-in because it spends credits.

## Test setup

- Copy `scripts/fixtures/sdd-agent-routes/java-orders/` to a scratch project.
- Install the SDLC POC profile so natural-language requests and commands enter through `sdlc-orchestrator`.
- Start from a clean Git status and capture the session tree, `.ai/` artifacts, non-planning diff, and terminal A2A.
- Treat paths below as expected shapes; the planner chooses verb-led kebab-case slugs unless the prompt fixes one.

## PLAN-BOUNDED-01 — Bounded executable change

**Purpose:** Prove that normal planning writes one ready change and no production files.

**Preconditions:** Unmodified `java-orders` fixture.

**Prompt:**

```text
/deep-plan Plan, without implementing, a bounded change that adds a public lineCount() method to Order and focused automated coverage. Preserve pricing and quantity behavior, use the existing Java 17 and JUnit conventions, and produce one execution-ready change rather than a roadmap or investigation.
```

**Expected artifacts/A2A:**

- One `.ai/deep-planner/changes/<change>/change.md` whose first line is `Status: ready-for-sdd | Source: deep-planner`.
- Behavior scenarios, real `Files:` scopes, `mvn -o test` verification, and `OK plan/deep-plan` with `next=sdd` and the exact handoff path.

**Forbidden behavior:** Production/test edits, roadmap creation, companion proposal/design/spec/tasks files, or execution choices in the planner artifact.

## PLAN-DECISION-01 — Final technical decision

**Purpose:** Prove that a non-executable investigation ends as one final plan without an SDD handoff.

**Preconditions:** Unmodified fixture; no product decision is required from the user.

**Prompt:**

```text
/deep-plan Investigate and decide whether a maximum order-line policy belongs in the Order construction boundary or in an import adapter. Use repository evidence, compare the two options, record edge cases and a verification approach, but do not plan or implement the chosen change.
```

**Expected artifacts/A2A:**

- One `.ai/deep-planner/plans/<slug>.md` starting with `Status: final | Source: deep-planner`.
- Evidence, decision and rationale, rejected alternative, edge cases, verification, and `OK plan/deep-plan` with `next=none`.

**Forbidden behavior:** `change.md`, roadmap, production edits, or `handoff=`.

## PLAN-DISCOVERY-01 — Multi-session discovery alias

**Purpose:** Prove that `/wayfinder` uses one durable plan and resumes the same exact path.

**Preconditions:** Unmodified fixture; currency scope and ownership are deliberately unresolved.

**Turn 1 prompt:**

```text
/wayfinder Explore how this order-pricing module could support multiple currencies. The supported currencies, exchange-rate source, and rounding ownership are undecided. Resolve repository facts, persist the open product decisions, and do not implement or create an executable handoff.
```

**Turn 2 prompt:**

```text
Continue the exact discovery plan you just created. For this scenario choose EUR and USD, rates supplied by the caller, and final-total rounding owned by OrderPricing. Resolve any remaining repository-derived questions and finish the decision, but leave executable planning for a later /deep-plan invocation.
```

**Expected artifacts/A2A:**

- Turn 1 creates one `.ai/deep-planner/plans/<slug>.md` with `Status: discovery | Source: deep-planner` and grouped open questions.
- Turn 2 updates that same file to `Status: final | Source: deep-planner` and returns `OK plan/deep-plan` with `next=plan`.

**Forbidden behavior:** Ticket files, `.ai/wayfinder/`, a second plan slug, ready handoff, or one-question-per-session ceremony.

## PLAN-ROADMAP-01 — Oversized goal and first slice

**Purpose:** Prove just-in-time slicing and the machine-readable roadmap marker.

**Preconditions:** Unmodified fixture; the prompt explicitly approves roadmap slicing.

**Prompt:**

```text
/deep-plan Plan a staged order-promotion capability covering percentage coupons, coupon validation, per-line discount reporting, and migration of existing bulk-discount tests. This is intentionally oversized and I approve an ordered roadmap. Plan only the smallest first slice that preserves current pricing behavior; leave later slices pending.
```

**Expected artifacts/A2A:**

- `.ai/roadmaps/<goal>.md` starts with `Status: active | Source: deep-planner` and contains ordered `pending|planned` rows with dependencies.
- Exactly one first-slice `change.md`; line one is ready-for-SDD and line two is `Roadmap: <goal> | Slice: 1/<total>`.
- `OK plan/deep-plan`, `next=sdd`, and the exact first-slice handoff.
- After that slice is done, `"continúa el roadmap <goal>"` resolves the same roadmap, moves only its first unblocked `pending` row to `planned`, and creates exactly one next-slice change.

**Forbidden behavior:** More than one `planned|adopted` slice, missing dependencies, implementation, guessed roadmap paths, or automatic planning of the next slice.

## PLAN-REFACTOR-01 — Protected refactor with reliable coverage

**Purpose:** Prove that protected planning produces a refactor handoff when behavior is already pinned.

**Preconditions:** Add passing characterization coverage for `OrderPricing.total`, `bulkDiscount`, and `discountPerLine` to the scratch fixture before invoking the planner.

**Prompt:**

```text
/refactor-plan Plan a behavior-preserving refactor of OrderPricing that isolates rounding policy and makes discount calculation easier to read. Preserve every public signature, threshold, rate, scale, rounding mode, and observed result. Use the existing characterization coverage as the safety net and do not introduce new pricing behavior.
```

**Expected artifacts/A2A:**

- One ready refactor `change.md` with preservation scenarios, affected paths, rollback, and end-to-end verification.
- At most one analyzer for medium/high risk or two evidence-backed lenses for critical risk.
- `OK plan/refactor` with `next=sdd` and the exact handoff.

**Forbidden behavior:** Hardening tasks without evidence, functional changes, more than the analyzer budget, or production edits.

## PLAN-HARDEN-AUTO-01 — Automatic hardening gate

**Purpose:** Prove that an unsafe refactor request becomes a separate hardening change.

**Preconditions:** Unmodified fixture, where `discountPerLine` has no focused automated coverage.

**Prompt:**

```text
/refactor-plan Plan a behavior-preserving refactor of OrderPricing.discountPerLine that extracts its rounding policy. Do not assume untested behavior is safe; inspect the current coverage and preserve all observed results.
```

**Expected artifacts/A2A:**

- One `.ai/deep-planner/changes/harden-<target>/change.md` containing tooling if needed, minimal seams, characterization tests, and a coverage baseline in that order.
- `OK plan/refactor` with `next=sdd`; the documented next planning action after SDD is `/refactor-plan` again.

**Forbidden behavior:** Production refactor tasks, bug fixes, or hardening and restructuring in the same change.

## PLAN-HARDEN-ALIAS-01 — Explicit hardening alias

**Purpose:** Prove that `/harden-plan` forces the same protected operation without creating a third machine route.

**Preconditions:** Unmodified fixture.

**Prompt:**

```text
/harden-plan Prepare OrderPricing.discountPerLine for a later behavior-preserving refactor. Add only the minimum test seams, characterization coverage, and useful coverage baseline. Do not restructure production behavior yet.
```

**Expected artifacts/A2A:**

- Delegation uses `operation=refactor intent=hardening`.
- One ready `harden-*` change and terminal `OK plan/refactor`.

**Forbidden behavior:** `OK plan/hardening`, refactor tasks, or direct implementation.

## PLAN-REFACTOR-GUARD-01 — Functional-change guard

**Purpose:** Prove that protected planning does not hide intended behavior changes.

**Preconditions:** Unmodified fixture.

**Prompt:**

```text
/refactor-plan Change the bulk-discount threshold from 100.00 to 200.00 and rename the related method while preserving everything else.
```

**Expected artifacts/A2A:**

- `ASK plan/refactor` recommends routing the threshold change through `/deep-plan`.
- No protected ready handoff is written before the user resolves the route.

**Forbidden behavior:** Treating the threshold change as behavior-preserving, silently splitting scope, or writing refactor/hardening tasks for the new policy.

## Evidence checklist

- The primary is the only user-question owner and resumes the same planner child after `ASK`.
- Planner writes stay under `.ai/deep-planner/` or `.ai/roadmaps/`; Git-tracked source remains unchanged.
- Clean planner returns are at most three lines and never contain artifact bodies or logs.
- Human plans and changes remain readable English; Caveman compression is A2A-only.
- A failed or ambiguous case returns exact `ASK`, `BLOCK`, or `FAIL` evidence rather than guessed data.
