# Orchestration manual tests

Run these cases only in a copied fixture or disposable project. Agent cases may consume model credits; execute them only when that separate cost is explicitly authorized, and never infer a result from these written expectations.

## Quick path

1. Copy `manual-tests/fixtures/orchestration-agent-routes/java-orders/` outside the repository and install the current single-primary profile there.
2. Run only the affected IDs from the pull-request summary and wait for each process to finish.
3. Inspect real conversation/tool events, source diff, hidden `.ai/` state, worker activity, Git index/HEAD, and final verification before cleanup. Catalog lint does not demonstrate model behavior; unexecuted cases remain pending.

### MT-ORCHESTRATION-DIRECT-CHANGE

- **Title:** Execute one local change without SDD state
- **Coverage key:** `orchestration/direct/local-change`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/skills/oc-routing/**`
- **Preconditions:** Use a clean copied Java fixture with a passing baseline and no `.ai/orchestration/` directory.
- **Steps:**
  1. Ask `orchestraitor` to rename only the local `subtotal` variable in `OrderPricing`, preserve behavior, and run the narrowest check.
  2. Inspect the diff, worker activity, `.ai/`, Git state, and final response.
- **Expected result:** No contract or route approval is requested. Only the local declaration and use change, fresh verification completes, no SDD worker or orchestration state appears, and Orchestraitor does not stage, commit, or push.
- **Cleanup:** Revert the fixture copy and delete it.

### MT-ORCHESTRATION-PLAN-ROUTE

- **Title:** Route planning requests to a plan skill without implementing
- **Coverage key:** `orchestration/plan/route`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`
- **Preconditions:** Use a clean copied Java fixture with a passing baseline.
- **Steps:**
  1. Ask `orchestraitor` for a light plan to add `Order.lineCount()` and ask to save it.
  2. In a fresh copy, ask `orchestraitor` for a deep plan to migrate order pricing across modules.
  3. Inspect loaded skills, the produced plans, and Git state.
- **Expected result:** The first request loads `oc-plan-light` and the second `oc-plan-deep`. Each produces only a plan file; no source or test edits, workers, or commits appear.
- **Cleanup:** Delete the fixture copies.

### MT-ORCHESTRATION-DIRECT-PLAN

- **Title:** Execute one localized plan directly
- **Coverage key:** `orchestration/plan/direct-execution`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/skills/oc-routing/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/**`
- **Preconditions:** In a clean copied Java fixture, ask `orchestraitor` to save a light plan (`oc-plan-light`) for `Order.lineCount()` and record its path and checksum.
- **Steps:**
  1. Tell `orchestraitor`, `ejecuta el plan <exact-path>`.
  2. Inspect implementation and focused coverage, rerun the named check, and compare the plan checksum.
  3. In fresh Git-backed copies, repeat with `Delivery: commit-per-unit` immediately after the title: once without an execution override, then with an explicit no-commits override.
- **Expected result:** No contract or SDD confirmation is requested. Implementation and focused coverage stay Direct; the plan is unchanged and no run or SDD worker appears. Default delivery leaves Git untouched. The delivery plan commits without another confirmation; the no-commits override leaves it uncommitted.
- **Essential negative variant:** Duplicate or unknown plan delivery values block before editing.
- **Cleanup:** Remove generated `.ai/` state and delete the fixture copy.

### MT-ORCHESTRATION-DIRECT-COMMITS

- **Title:** Deliver exact Direct commits without absorbing unrelated state
- **Coverage key:** `orchestration/delivery/direct-commits`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/common/skills/oc-commits/**`, `domains/orchestration/skills/oc-commits/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/**`
- **Preconditions:** Initialize a copied Java fixture as a Git repository on an attached branch, commit the passing baseline, and stage an unrelated `notes.txt` outside the requested target scope.
- **Steps:**
  1. Explicitly request `commit-per-unit`: first rename the local `subtotal` variable with exact message `refactor: clarify subtotal variable`, then add `Order.lineCount()` with focused coverage and exact message `feat: expose order line count`.
  2. Wait for both units, rerun `mvn -o test`, and inspect commit parents, messages, path sets, the staged diff, working tree, and remote activity.
- **Expected result:** No SDD contract approval is requested. Each requested unit runs green before one serial commit; the two messages, order, and path boundaries match the request; both commits form a continuous chain; `notes.txt` remains staged and unchanged; `.ai/` is absent; and no push occurs.
- **Essential negative variant:** Start again with a target file already modified and confirm Orchestraitor asks whether to include it, switch to `working-tree`, or stop before making another edit.
- **Cleanup:** Delete the disposable repositories without pushing them.

### MT-ORCHESTRATION-SDD-CONFIRM

- **Title:** Execute an existing SDD plan without another confirmation
- **Coverage key:** `orchestration/sdd/confirmation-gate`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/state-seeds/complex-plan/**`
- **Preconditions:** Copy the Java fixture and restore the `complex-plan/ai/` seed as `.ai/`; record the plan SHA-256 and do not explicitly request SDD.
- **Steps:**
  1. Tell `orchestraitor`, `ejecuta el plan .ai/deep-planner/plans/adjust-order-pricing.md`.
  2. Inspect conversation/tool events, worker activity, run controls, implementation, and the final plan SHA-256.
- **Expected result:** Structural validation succeeds and SDD proceeds without a route confirmation or content review/approval. The run records `Approval: plan-execution` and the actual execution instruction as evidence; the original plan checksum is retained and checked through implementation and verification.
- **Essential negative variant:** Use an invalid Delivery value and confirm execution still blocks before editing; plan execution does not bypass technical controls.
- **Cleanup:** Remove the seeded `.ai/` directory and fixture copy.

### MT-ORCHESTRATION-SDD-CONTRACT-APPROVAL

- **Title:** Approve the generated SDD contract before implementation
- **Coverage key:** `orchestration/sdd/contract-approval`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`
- **Preconditions:** Use fresh Git-backed Java fixture copies with a passing baseline and no run state. Record source, index, and HEAD before each variant; enable conversation/tool and worker activity inspection.
- **Steps:**
  1. Request SDD directly for a pricing behavior change without supplying a plan. Inspect the presented contract and native Approve / Request adjustments / Cancel choice before responding.
  2. Request an adjustment. Inspect the revised contract, then explicitly approve it. Repeat in a fresh copy using an explicit chat response approving the presented contract. Complete once with `working-tree` and once with explicitly requested `commit-per-unit`.
  3. In separate copies, cancel at the gate and interrupt before approval. On return from interruption, inspect the re-presented contract before answering.
  4. Start with a Direct change, then introduce dependencies or a public-contract change requiring SDD. Inspect the route explanation and approve the presented contract once.
- **Expected result:** Intent, Scope, every WHEN/THEN scenario, Approach, and Done means are visible without omitted acceptance criteria. Before approval, only exploration and conversation drafting occur: no run, implementation edits, `oc-sdd-implement` worker, staging, or commits, including via other agents. Adjustments do not authorize the revision, cancellation starts no implementation, and interruption does not invent approval. Direct → SDD asks once for both route and contract. Approval records `Approval: explicit`, the actual approving response, and the full approved contract including Scope and Approach in `run.md`; implementation then continues automatically through focused checks, optional serial commits, global cold verification, any required canonical merge, and archive, without duplicate approval or changed worker responsibilities. Contract sections stay unchanged while execution state advances.
- **Essential negative variant:** Leave the question unanswered or respond with approval plus a behavior change; neither authorizes the revised contract. If implementation reveals a required scope, behavior, or acceptance change after approval, it stops and communicates the change without silently rewriting the contract.
- **Cleanup:** Delete the disposable projects and generated state without pushing.

### MT-ORCHESTRATION-SDD-COMPLETE

- **Title:** Complete and archive one verified SDD run
- **Coverage key:** `orchestration/sdd/verified-archive`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/skills/oc-sdd-explore/**`, `domains/orchestration/skills/oc-sdd-implement/**`, `domains/orchestration/skills/oc-sdd-merge/**`, `domains/orchestration/skills/oc-sdd-verify/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/state-seeds/**`
- **Preconditions:** Copy the Java fixture, restore both state seeds under `.ai/`, ensure the baseline passes, and record the plan checksum.
- **Steps:**
  1. Tell `orchestraitor`, `ejecuta el plan <exact-seeded-plan-path>`, and wait through implementation, cold verification, and canonical merge.
  2. Rerun the plan's Done means, inspect the archived run and canonical delta, and compare the plan checksum and Git state.
- **Expected result:** No additional approval is requested; the archived run retains `Approval: plan-execution` and the actual instruction as evidence. Matching scoped workers implement tests alongside the change, every source Scenario and Done means item is counted once, the completed run is archived, canonical behavior has no stale row, the plan is unchanged, and no Git mutation occurs.
- **Cleanup:** Delete the copied fixture and all generated state.

### MT-ORCHESTRATION-SDD-COMMITS

- **Title:** Resume serial SDD commits after an honest hook failure
- **Coverage key:** `orchestration/delivery/sdd-commits`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/skills/oc-sdd-implement/**`, `domains/orchestration/skills/oc-sdd-verify/**`, `domains/common/skills/oc-commits/**`, `domains/orchestration/skills/oc-commits/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/**`
- **Preconditions:** Prepare two Git-backed fixture copies with a green baseline, the complex plan under `.ai/`, its checksum, an unrelated staged `notes.txt`, and executable `.git/hooks/pre-commit` copied from `hooks/reject-order-pricing-pre-commit`.
- **Steps:**
  1. Request `ejecuta el plan <exact-path>` with `commit-per-unit`: keep the plan's groups as separate units in one copy and combine them into one verified unit in the other. Wait for the pricing hook rejection in each.
  2. Inspect write/hook order and the pending record in `run.md`: unit id, source work ids, declared scope, changed paths, check, message, parent SHA, and pre-stage/pre-hook snapshots. Compare them with `HEAD`, index, and working tree before changing anything.
  3. Disable the hook manually, then use a fresh session to `continúa <exact-run-path>` in each copy.
  4. Rerun `mvn -o test`; inspect the archived ledger, cleared pending record, plan checksum, commit parents/paths, staged `notes.txt`, and cold-verification selector.
- **Expected result:** Plan execution and resume ask no duplicate contract or route approval. The run preserves `Approval: plan-execution` and its actual instruction as evidence. Delivery is serial. Pending evidence exists before staging and hooks, including when the first commit fails with `Commits: none`. Resume validates saved state, reruns the check, and commits the same unit before clearing pending state. Unrelated staged content and green commits remain intact; `.ai/`, hook bypass, history rewrites, and push stay absent. Cold verification uses exactly `<Baseline>..HEAD` before archive.
- **Essential negative variant:** Change a pending target after rejection and confirm resume blocks without discarding it. A fresh SDD run with an already modified target also blocks without changing delivery.
- **Cleanup:** Remove the disposable hook, run state, and repository without pushing them.

### MT-ORCHESTRATION-SDD-RESUME

- **Title:** Resume the exact active SDD run
- **Coverage key:** `orchestration/sdd/exact-resume`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/skills/oc-sdd-implement/**`, `domains/orchestration/skills/oc-sdd-verify/**`
- **Preconditions:** Interrupt an approved disposable run after one completed group with one group pending. Require valid delivery controls, `Approval` and actual `Approval evidence`, and an immutable external plan hash when present; record contract sections, progress, paths, and Git state. Repeat for generated-contract approval and existing-plan execution.
- **Steps:**
  1. Start a fresh session and tell `orchestraitor`, `continúa <exact-run-path>`.
  2. Inspect conversation/tool events, which group resumes, contract sections, Git controls, final verification, archive destination, and external plan checksum when present.
- **Expected result:** Orchestraitor asks no contract or route reconfirmation, resumes only the named run, preserves the immutable contract, approval evidence, completed work, and Git controls, executes pending scope without creating a second run or plan, verifies the original contract, and archives on completion.
- **Essential negative variant:** In separate copies, remove `Approval` or `Approval evidence` and request resume. Both block as incomplete execution contracts before implementation or Git mutation; no approval is inferred, migrated, or reconstructed.
- **Cleanup:** Delete the disposable run, plan, and project.

### MT-ORCHESTRATION-DIRECT-TCR

- **Title:** Commit green TCR microsteps and revert only attributable red changes
- **Coverage key:** `orchestration/delivery/direct-tcr`
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/common/skills/oc-tcr/**`, `domains/orchestration/skills/oc-tcr/**`, `manual-tests/fixtures/orchestration-agent-routes/java-orders/**`
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
- **Applies to:** `domains/orchestration/agents/orchestraitor.md`, `domains/orchestration/skills/oc-sdd-implement/**`, `domains/orchestration/skills/oc-sdd-verify/**`
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
- **Expected result:** Dry run writes nothing; on creates complete blocks for the discovered `orchestraitor` and `general` and reports `on`; the second on is idempotent; off removes managed permissions, including retired `sdd-*` blocks, while preserving unrelated configuration.
- **Essential negative variant:** Add a JSONC comment and confirm `on` fails clearly before backup or mutation because this helper requires valid JSON.
- **Cleanup:** Remove the disposable target.

### MT-ORCHESTRATION-V2-STATUSLINE

- **Title:** Load and dispose the local OpenCode V2 CLI status contribution
- **Coverage key:** `orchestration/plugins/v2-subagent-statusline`
- **Applies to:** `domains/orchestration/tui-plugins/subagent-statusline.tsx`, `domains/orchestration/tui-plugins/subagent-statusline/**`
- **Preconditions:** Use OpenCode v2.0.28 with an isolated HOME, XDG configuration/data/cache/state and runtime directory under an approved temporary fixture. Install the `orchestration` domain into the fixture configuration with `--target <config> --no-install-brew-tools`; confirm `cli.json` registers `./plugins/subagent-statusline.tsx` in `plugins` and all three companion runtime files are present. Use a private server and empty fixture project; never edit the real global CLI configuration or submit LLM prompts.
- **Steps:**
  1. Run `node --test --test-reporter=tap domains/orchestration/tui-plugins/subagent-statusline/*.test.mjs`, then start the actual full-screen CLI in an isolated PTY with `--standalone` and inspect plugin loading diagnostics.
  2. Seed parent, direct-child, grandchild and unrelated sessions using the private host session API without prompting a model. Navigate between the parent, child and unrelated sessions; reopen an existing parent to exercise hydration.
  3. Inspect the appended prompt-footer status contribution with running and idle children and succeeded, failed and interrupted outcomes. Use synthetic host fixtures for execution states when real execution would require separately authorized model credits.
  4. Disable/reload the plugin in the fixture and close/reopen a session view. Check that the contribution disappears and returns once without duplicate hydration effects, subscriptions or prompt replacement.
- **Expected result:** The installed wrapper loads the directory's `./tui` entrypoint with stable ID `orchestration.subagent-statusline` using `@opencode/plugin/tui`. Only direct children of the currently viewed session are counted; grandparents, grandchildren and foreign-session children never leak. Cached states update reactively, reopened sessions hydrate children, and unknown/idle states are not reported as success. The built-in prompt and health indicators remain intact. Disposal removes the single appended contribution; no log scanning, task/delegate heuristics, dependency installation or global configuration changes occur. Node tests and startup evidence alone do not prove visual placement or real execution transitions; unperformed UI checks remain pending.
- **Essential negative variant:** Reject child hydration in a fixture, switch sessions during an outstanding hydration, and dispose before it finishes. No unhandled rejection, stale foreign count, duplicate contribution or plugin-owned late state write appears.
- **Cleanup:** Stop only fixture-owned CLI/server processes and remove the disposable fixture.
