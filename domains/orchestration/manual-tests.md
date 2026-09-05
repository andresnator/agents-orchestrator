# Orchestration manual tests

Run these cases only in a copied fixture or disposable project. Agent cases may consume model credits; execute them only when that separate cost is explicitly authorized, and never infer a result from these written expectations.

## Quick path

1. Copy `manual-tests/fixtures/orchestration-agent-routes/java-orders/` outside the repository and install the current multi-primary profile there.
2. Run only the affected IDs from the pull-request summary and wait for each process to finish.
3. Inspect source, hidden `.ai/` state, worker activity, and final verification before cleanup.

### MT-ORCHESTRATION-DIRECT-CHANGE

- **Title:** Execute one local change without SDD state
- **Coverage key:** `orchestration/direct/local-change`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/skills/implementation-skill-routing/**`
- **Preconditions:** Use a clean copied Java fixture with a passing baseline and no `.ai/orchestration/` directory.
- **Steps:**
  1. Ask `orchestraitor` to rename only the local `subtotal` variable in `OrderPricing`, preserve behavior, and run the narrowest check.
  2. Inspect the diff, worker activity, `.ai/`, Git state, and final response.
- **Expected result:** Only the local declaration and use change, fresh verification completes, no SDD worker or orchestration state appears, and Orchestraitor does not stage, commit, or push.
- **Cleanup:** Revert the fixture copy and delete it.

### MT-ORCHESTRATION-DIRECT-PLAN

- **Title:** Execute one localized plan directly
- **Coverage key:** `orchestration/plan/direct-execution`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/skills/implementation-skill-routing/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/**`
- **Preconditions:** In a clean copied Java fixture, use `deep-planner` to create a localized plan for `Order.lineCount()` and record its checksum.
- **Steps:**
  1. Tell `orchestraitor`, `ejecuta el plan <exact-path>`.
  2. Inspect implementation and focused coverage, rerun the named check, and compare the plan checksum.
  3. In fresh Git-backed copies, repeat with `Delivery: commit-per-unit` immediately after the title: once without an execution override, then with an explicit no-commits override.
- **Expected result:** Implementation and focused coverage stay Direct; the plan is unchanged and no run or SDD worker appears. Default delivery leaves Git untouched. The delivery plan commits without another confirmation; the no-commits override leaves it uncommitted.
- **Essential negative variant:** Duplicate or unknown plan delivery values block before editing.
- **Cleanup:** Remove generated `.ai/` state and delete the fixture copy.

### MT-ORCHESTRATION-DIRECT-COMMITS

- **Title:** Deliver exact Direct commits without absorbing unrelated state
- **Coverage key:** `orchestration/delivery/direct-commits`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/common/skills/work-unit-commits/**`, `domains/orchestration/skills/work-unit-commits/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/**`
- **Preconditions:** Initialize a copied Java fixture as a Git repository on an attached branch, commit the passing baseline, and stage an unrelated `notes.txt` outside the requested target scope.
- **Steps:**
  1. Explicitly request `commit-per-unit`: first rename the local `subtotal` variable with exact message `refactor: clarify subtotal variable`, then add `Order.lineCount()` with focused coverage and exact message `feat: expose order line count`.
  2. Wait for both units, rerun `mvn -o test`, and inspect commit parents, messages, path sets, the staged diff, working tree, and remote activity.
- **Expected result:** Each requested unit runs green before one serial commit; the two messages, order, and path boundaries match the request; both commits form a continuous chain; `notes.txt` remains staged and unchanged; `.ai/` is absent; and no push occurs.
- **Essential negative variant:** Start again with a target file already modified and confirm Orchestraitor asks whether to include it, switch to `working-tree`, or stop before making another edit.
- **Cleanup:** Delete the disposable repositories without pushing them.

### MT-ORCHESTRATION-SDD-CONFIRM

- **Title:** Confirm SDD before creating durable state
- **Coverage key:** `orchestration/sdd/confirmation-gate`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/state-seeds/complex-plan/**`
- **Preconditions:** Copy the Java fixture and restore the `complex-plan/ai/` seed as `.ai/`; do not explicitly request SDD.
- **Steps:**
  1. Tell `orchestraitor`, `ejecuta el plan .ai/deep-planner/plans/adjust-order-pricing.md`.
  2. Inspect the explanation, closed confirmation, task activity, and `.ai/orchestration/runs/` before answering.
- **Expected result:** Orchestraitor explains the public-contract/dependency reason and asks once; it creates no run state or SDD worker before positive confirmation.
- **Essential negative variant:** Decline SDD and confirm no run is created and work stops or remains within an explicitly safe reduced scope.
- **Cleanup:** Remove the seeded `.ai/` directory and fixture copy.

### MT-ORCHESTRATION-SDD-COMPLETE

- **Title:** Complete and archive one verified SDD run
- **Coverage key:** `orchestration/sdd/verified-archive`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/agents/sdd-explore.md`, `domains/orchestration/agents/sdd-implement.md`, `domains/orchestration/agents/sdd-verify.md`, `domains/orchestration/agents/sdd-canonical-merge.md`, `domains/orchestration/skills/sdd-cold-verification/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/state-seeds/**`
- **Preconditions:** Copy the Java fixture, restore both state seeds under `.ai/`, ensure the baseline passes, and record the plan checksum.
- **Steps:**
  1. Explicitly request SDD execution of the seeded plan and wait through implementation, cold verification, and canonical merge.
  2. Rerun the plan's verification, inspect the archived run and canonical delta, and compare the plan checksum and Git state.
- **Expected result:** Matching scoped workers implement tests alongside the change, every source scenario and check is counted once, the completed run is archived, canonical behavior has no stale row, the plan is unchanged, and no Git mutation occurs.
- **Cleanup:** Delete the copied fixture and all generated state.

### MT-ORCHESTRATION-SDD-COMMITS

- **Title:** Resume serial SDD commits after an honest hook failure
- **Coverage key:** `orchestration/delivery/sdd-commits`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/agents/sdd-implement.md`, `domains/orchestration/agents/sdd-verify.md`, `domains/orchestration/skills/sdd-cold-verification/**`, `domains/common/skills/work-unit-commits/**`, `domains/orchestration/skills/work-unit-commits/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/**`
- **Preconditions:** Prepare two Git-backed fixture copies with a green baseline, the complex plan under `.ai/`, its checksum, an unrelated staged `notes.txt`, and executable `.git/hooks/pre-commit` copied from `hooks/reject-order-pricing-pre-commit`.
- **Steps:**
  1. Request SDD with `commit-per-unit`: keep the plan's groups as separate units in one copy and combine them into one verified unit in the other. Wait for the pricing hook rejection in each.
  2. Inspect write/hook order and the pending record in `run.md`: unit id, source work ids, declared scope, changed paths, check, message, parent SHA, and pre-stage/pre-hook snapshots. Compare them with `HEAD`, index, and working tree before changing anything.
  3. Disable the hook manually, then use a fresh session to `continúa <exact-run-path>` in each copy.
  4. Rerun `mvn -o test`; inspect the archived ledger, cleared pending record, plan checksum, commit parents/paths, staged `notes.txt`, and cold-verification selector.
- **Expected result:** Delivery is serial. Pending evidence exists before staging and hooks, including when the first commit fails with `Commits: none`. Resume validates saved state, reruns the check, and commits the same unit before clearing pending state. Unrelated staged content and green commits remain intact; `.ai/`, hook bypass, history rewrites, and push stay absent. Cold verification uses exactly `<Baseline>..HEAD` before archive.
- **Essential negative variant:** Change a pending target after rejection and confirm resume blocks without discarding it. A fresh SDD run with an already modified target also blocks without changing delivery.
- **Cleanup:** Remove the disposable hook, run state, and repository without pushing them.

### MT-ORCHESTRATION-SDD-RESUME

- **Title:** Resume the exact active SDD run
- **Coverage key:** `orchestration/sdd/exact-resume`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/agents/sdd-implement.md`, `domains/orchestration/agents/sdd-verify.md`
- **Preconditions:** Prepare a disposable active run with a valid `run.md`, immutable plan hash, one completed group, and one pending group; record all paths and checksums.
- **Steps:**
  1. Start a fresh session and tell `orchestraitor`, `continúa <exact-run-path>`.
  2. Inspect which group resumes, final verification, archive destination, and plan checksum.
- **Expected result:** Orchestraitor resumes only the named run, preserves completed work, executes pending scope without creating a second run or plan, verifies the original contract, and archives on completion.
- **Cleanup:** Delete the disposable run, plan, and project.

### MT-ORCHESTRATION-DIRECT-TCR

- **Title:** Commit green TCR microsteps and revert only attributable red changes
- **Coverage key:** `orchestration/delivery/direct-tcr`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/common/skills/tcr/**`, `domains/orchestration/skills/tcr/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/**`
- **Preconditions:** Initialize a copied fixture as a Git repository on an attached branch, commit a passing baseline, keep the target scope clean, and stage one unrelated file outside it.
- **Steps:**
  1. Explicitly request TCR for renaming local `subtotal` to `rawSubtotal`, with the complete `mvn -o test` verification before and after and exact final message `refactor: clarify raw subtotal`.
  2. Require one deliberate red microstep that changes only the tracked declaration, inspect its exact restoration, then one deliberate red microstep that creates malformed untracked `TcrProbe.java`, and inspect its exact removal.
  3. Let the correct rename run green and commit, then inspect the final verification, commit parent and paths, unrelated index entry, and remote activity.
- **Expected result:** The full baseline is green before editing; neither red microstep creates a commit; the tracked file returns byte-for-byte and only the newly created untracked probe is removed; unrelated staged state is preserved; the correct microstep commits once after its focused check; the full final verification passes; and no push occurs.
- **Essential negative variant:** Start with a modified, staged, or untracked target path and confirm TCR blocks before editing rather than offering to absorb or clean it.
- **Cleanup:** Delete the disposable repository without pushing it.

### MT-ORCHESTRATION-PARALLEL-WAVE

- **Title:** Parallelize only disjoint ready work
- **Coverage key:** `orchestration/sdd/disjoint-wave`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/agents/sdd-implement.md`, `domains/orchestration/agents/sdd-verify.md`
- **Preconditions:** Use a disposable plan with two dependency-free groups on disjoint files and a third group depending on both; enable visible task timing.
- **Steps:**
  1. Explicitly run the plan with SDD and observe task start/end times for the first wave.
  2. Observe the dependent group and final cold verification after both first-wave tasks settle.
- **Expected result:** The two disjoint ready groups overlap in one wave, the dependent group starts only after both finish, overlapping file scopes never run together, and serial verification begins after the barrier.
- **Cleanup:** Remove the disposable run state and project.

### MT-ORCHESTRATION-PERMISSIONS

- **Title:** Toggle orchestration permissions safely
- **Coverage key:** `orchestration/permissions/config-lifecycle`
- **Applies to:** `scripts/orchestration-permissions.sh`, `domains/orchestration/agents/**`
- **Preconditions:** Create a disposable target with valid JSON OpenCode config, one unrelated agent setting, and `jq` available.
- **Steps:**
  1. Run `on --dry-run`, then `on --target <target>`, `show`, a second `on`, and `off`.
  2. Inspect the backup, per-agent states, frontmatter-deny preservation, unrelated setting, and final config.
- **Expected result:** Dry run writes nothing; on creates complete discovered-agent blocks and reports `on`; the second on is idempotent; off removes managed permissions while preserving unrelated configuration.
- **Essential negative variant:** Add a JSONC comment and confirm `on` fails clearly before backup or mutation because this helper requires valid JSON.
- **Cleanup:** Remove the disposable target.
