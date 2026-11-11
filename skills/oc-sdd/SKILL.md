---
name: oc-sdd
description: "Trigger: SDD, spec-driven run, ejecutar SDD, plan execution via SDD, continúa <run>, SDD explore, SDD discovery, explore change scope, SDD implement, implement unit, run.md unit, cold verification, verify run.md, SDD verification, behavior acceptance, canonical merge, merge spec deltas, SDD canonical spec. Coordinate one durable SDD run: approval gate, run controls, units, workers, cold verification, merge, and archive; workers load it with a role (explore, implement, verify, merge) and follow only that role reference."
license: MIT
metadata:
  author: andresnator
  version: "2.2.0"
  status: testing
---

# SDD Run

## Intent

- **Goal:** Deliver one approved contract through a durable, resumable SDD run with fresh cold verification and the resolved delivery mode.
- **Limits:**
  - Only the primary coordinator follows the coordinator sections. It owns every Git action. Workers follow "Worker roles".
  - SDD allows only `working-tree` or `commit-per-unit`.
  - "Approval" owns every approval rule. "Plan integrity" owns every plan and contract change rule.
- **Fails if:** an "Approval" rule is broken (including any edit, run, worker, stage, or commit before approval); a plan hash changes; a Scenario or Done means item is skipped; `.ai/` or canonical specs enter a delivery commit; a child returns logs, diffs, or artifact bodies.

## Context

- **Reads:** the request or exact plan, `.ai/orchestration/runs/<slug>/run.md`, Git state, the worker role references `references/explore.md`, `references/implement.md`, `references/verify.md`, `references/merge.md`, and skill `oc-commits`.
- **Never reads:** unrelated working-tree changes as scope; child logs or diffs; mutable `run.md` as a checksum source.
- **Scope:** explicit SDD requests, plan execution routed to SDD, Direct work exceeding safety, and `continúa <run>`.

## Expectations

- **Scenarios:**
  - WHEN the user says `continúa <run>` THEN resume that exact run with its recorded controls (see "Resume").
  - WHEN behavior, scope, or acceptance must change during execution THEN stop and communicate.
  - WHEN a correction fails twice THEN ask whether to continue, reduce scope, or stop.
- **Done means:** the outcome and fresh verification; the active or archived run path; confirmation that the original plan stayed unchanged; for `commit-per-unit`, the full SHAs.
- **Quality needs:** progress in natural language; expose phase, wave, unit, or retry counters only on request.

## Method

### Approval

This section owns every approval rule. Never implement before approval. Never reconstruct or infer approval.

| Source | Gate | `Approval:` value |
| --- | --- | --- |
| New SDD work without a plan execution instruction | Explore, draft, and gate on approval (below). | `explicit`, after the presented contract is approved |
| A plan execution instruction that routes to SDD | No confirmation or content reapproval. Structural validation, delivery restrictions, and checksum checks still apply. | `plan-execution` |

- **Gate:** explore (brief a `general` worker to load `oc-sdd role=explore`) and draft the contract in conversation. Present Intent, Scope, every `WHEN/THEN` scenario, Approach, and Done means compactly without hiding acceptance criteria. Use native `question` with `Approve`, `Request adjustments`, `Cancel`. An explicit response approving the presented contract also counts.
- **Route change:** Direct → SDD explains the route change, and one approval covers route and contract. If rejected, continue only with an explicitly authorized safe reduced scope.
- **Not approval:** adjustments require re-presenting and approving the revision. Silence, the initial SDD request, or a reply that introduces changes never approve. Cancel stops. If interrupted, present the contract again.
- **Before approval:** do not create the run, edit implementation, launch implementation workers, stage, or commit, including through other agents. After approval, continue automatically.
- **Record:** create `run.md` only after approval or a plan execution instruction. Write the `Approval:` value above and the actual authorizing user response or execution instruction in `Approval evidence:`. A run without `Approval` or actual `Approval evidence` is invalid.
- **Resume:** require a valid `Approval` and actual `Approval evidence`; missing approval blocks as an incomplete contract without migration. Never infer approval from file existence. Never reconfirm an approved run.

### Run file

`.ai/orchestration/runs/<slug>/run.md` starts with one value per line:

```text
Delivery: working-tree | commit-per-unit
Baseline: working-tree | <full SHA>
Commits: none
Approval: explicit | plan-execution
Approval evidence: <actual user response or execution instruction authorizing this contract>
```

`working-tree` records `Baseline: working-tree`; `commit-per-unit` records the full pre-edit `HEAD` after the `oc-commits` clean-target preflight. Planless SDD persists the complete approved contract in the IDSD plan shape (Intent, Context, Expectations with every scenario and Done means item, Method with Approach and Work groups).

### Plan integrity

- Never modify an executed plan. Record a supplied plan by exact path and SHA-256; never copy, rewrite, or mark it.
- Contract sections are immutable; only progress, derived units, pending delivery, and commits change. Never alter an approved contract silently.
- Keep the external plan SHA-256 checks. Do not checksum mutable `run.md` or introduce contract versioning.

### Resume

Require and reuse the recorded controls ("Approval" owns the approval checks). For `commit-per-unit`, require `HEAD` to equal the last recorded commit, or `Baseline` when `Commits: none`; load `oc-commits` and apply its pending-delivery checks before retrying. Never discard pending changes or rebuild their scope from work groups.

### Execute

A unit is one cohesive, independently verifiable part of the work: `unit-01`, `unit-02`, ... Split or combine plan Work groups into units. A wave is one set of dependency-ready units that run in parallel. `working-tree` puts in a wave only dependency-ready units with disjoint scopes; `commit-per-unit` implements, checks, commits, and records each unit serially.

- **Implement:** brief a `general` worker to load `oc-sdd role=implement` with every input that skill requires. Accept only a matching result; reconcile changed paths, rerun the focused check, verify the plan hash before and after.
- **Commit:** under `commit-per-unit`, follow `oc-commits`: persist the pending unit and Git snapshots before staging and hooks, verify the commit, update the ledger, clear pending state.
- **Verify:** with no pending delivery, brief a `general` worker to load `oc-sdd role=verify` with every input that skill requires, including every Scenario and Done means item and exactly `working-tree` or `<Baseline>..HEAD`.
- **Correct:** a failure becomes a new scoped correction unit (new id and commit after a commit; never rewrite history).
- **Merge:** only when canonical behavior is required, brief a `general` worker to load `oc-sdd role=merge`; require one merge row per delta and `stale=0`. Keep canonical specs and `.ai/` outside delivery commits.
- **Archive:** move a completed run to `.ai/orchestration/runs/archive/<YYYY-MM-DD>-<slug>/`, preserving plan path, final SHA-256, delivery and approval controls with evidence, the contract, and the commit ledger. An incomplete run stays active and keeps every green commit.

### Worker roles

A worker loading `oc-sdd role=<role>` follows only `references/<role>.md` (explore, implement, verify, merge) and ignores the coordinator sections above.

Every worker brief states: load `oc-sdd role=<role>`, no Git mutation, no questions, no further delegation, return only the role's result lines.
