---
name: oc-sdd
description: "Trigger: SDD, spec-driven run, ejecutar SDD, plan execution via SDD, continúa <run>. Coordinate one durable SDD run: approval gate, run controls, units, workers, cold verification, merge, and archive."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---

# SDD Run

## Intent

- **Goal:** Deliver one approved contract through a durable, resumable SDD run with fresh cold verification and the resolved delivery mode.
- **Limits:** Loaded only by the primary coordinator, which owns every Git action; workers never mutate Git, ask, or delegate. SDD allows only `working-tree` or `commit-per-unit`. Never implement before approval, never modify an executed plan, never alter an approved contract silently, never reconstruct or infer approval.
- **Fails if:** an edit, run, implementation worker, stage, or commit precedes approval; a run lacks `Approval` or actual `Approval evidence`; a plan hash changes; a Scenario or Done means item is skipped; `.ai/` or canonical specs enter a delivery commit; a child returns logs, diffs, or artifact bodies.

## Context

- **Reads:** the request or exact plan, `.ai/orchestration/runs/<slug>/run.md`, Git state, and skills `oc-sdd-explore`, `oc-sdd-implement`, `oc-sdd-verify`, `oc-sdd-merge`, `oc-commits`.
- **Never reads:** unrelated working-tree changes as scope; child logs or diffs; mutable `run.md` as a checksum source.
- **Persona:** careful run coordinator; contract first, then units.
- **Scope:** explicit SDD requests, plan execution routed to SDD, Direct work exceeding safety, and `continúa <run>`.

## Expectations

- **Scenarios:**
  - WHEN `tcr` was resolved for SDD work THEN ask before any edit whether to switch to `commit-per-unit` or reduce to safe Direct work; stop if neither is chosen.
  - WHEN new SDD work arrives without a plan execution instruction THEN explore, draft, and gate on approval.
  - WHEN a plan execution instruction routes to SDD THEN record `Approval: plan-execution` without a confirmation or content reapproval; structural validation, delivery restrictions, and checksum checks still apply.
  - WHEN the user says `continúa <run>` THEN resume that exact run with its recorded controls.
  - WHEN behavior, scope, or acceptance must change during execution THEN stop and communicate.
  - WHEN a correction fails twice THEN ask whether to continue, reduce scope, or stop.
- **Done means:** the outcome and fresh verification; the active or archived run path; confirmation that the original plan stayed unchanged; for `commit-per-unit`, the full SHAs.
- **Quality needs:** progress in natural language; expose phase, wave, unit, or retry counters only on request.

## Method

### Approval gate

For new SDD work without a plan execution instruction, explore (via `oc-sdd-explore`) and draft the contract in conversation. Present Intent, Scope, every `WHEN/THEN` scenario, Approach, and Done means compactly without hiding acceptance criteria; use native `question` with `Approve`, `Request adjustments`, `Cancel`. An explicit response approving the presented contract also counts. Direct → SDD explains the route change and one approval covers route and contract; if rejected, continue only with an explicitly authorized safe reduced scope. Adjustments require re-presenting and approving the revision; silence, the initial SDD request, or a reply that introduces changes never approve. Cancel stops. If interrupted, present the contract again; never reconstruct approval. Before approval, do not create the run, edit implementation, launch implementation workers, stage, or commit, including through other agents. After approval, continue automatically.

### Run controls

Create `.ai/orchestration/runs/<slug>/run.md` only after approval or a plan execution instruction, with one value per line at the top:

```text
Delivery: working-tree | commit-per-unit
Baseline: working-tree | <full SHA>
Commits: none
Approval: explicit | plan-execution
Approval evidence: <actual user response or execution instruction authorizing this contract>
```

`working-tree` records `Baseline: working-tree`; `commit-per-unit` records the full pre-edit `HEAD` after the `oc-commits` clean-target preflight. Record `Approval: explicit` after a presented contract is approved, or `Approval: plan-execution` for a plan execution instruction, with the actual authorizing response or instruction in `Approval evidence:`. A supplied plan is recorded by exact path and SHA-256, never copied, rewritten, or marked. Planless SDD persists the complete approved contract in the IDSD plan shape (Intent, Context, Expectations with every scenario and Done means item, Method with Approach and Work groups).

### Resume

Require and reuse the recorded controls, including valid `Approval` and actual `Approval evidence`; missing approval blocks as an incomplete contract without migration. Never infer approval from file existence; never reconfirm an approved run. For `commit-per-unit`, require `HEAD` to equal the last recorded commit, or `Baseline` when `Commits: none`; load `oc-commits` and apply its pending-delivery checks before retrying. Never discard pending changes or rebuild their scope from work groups.

### Execute

Contract sections are immutable; only progress, derived units, pending delivery, and commits change. Keep the external plan SHA-256 checks; do not checksum mutable `run.md` or introduce contract versioning. Split or combine Work groups into cohesive, independently verifiable `unit-01`, `unit-02`, ... `working-tree` parallelizes only dependency-ready units with disjoint scopes; `commit-per-unit` implements, checks, commits, and records each unit serially.

- **Implement:** brief a `general` worker to load `oc-sdd-implement` with every input that skill requires. Accept only a matching result; reconcile changed paths, rerun the focused check, verify the plan hash before and after.
- **Commit:** under `commit-per-unit`, follow `oc-commits`: persist the pending unit and Git snapshots before staging and hooks, verify the commit, update the ledger, clear pending state.
- **Verify:** with no pending delivery, brief a `general` worker to load `oc-sdd-verify` with every input that skill requires, including every Scenario and Done means item and exactly `working-tree` or `<Baseline>..HEAD`.
- **Correct:** a failure becomes a new scoped correction unit (new id and commit after a commit; never rewrite history).
- **Merge:** only when canonical behavior is required, brief a `general` worker to load `oc-sdd-merge`; require one merge row per delta and `stale=0`. Keep canonical specs and `.ai/` outside delivery commits.
- **Archive:** move a completed run to `.ai/orchestration/runs/archive/<YYYY-MM-DD>-<slug>/`, preserving plan path, final SHA-256, delivery and approval controls with evidence, the contract, and the commit ledger. An incomplete run stays active and keeps every green commit.

Every worker brief states: load `<skill>`, no Git mutation, no questions, no further delegation, return only the skill's result lines.
