# Plan Handoff Contract

External planners hand SDD one compact coordinator receipt plus the exact path to a complete OpenSpec bundle. The bundle remains the durable source under its producer root; SDD executes it in place without redrafting. `refactor-planner`, `architect`, and `deep-planner` are the current producers.

## Bundle location

```
.ai/<planner>/changes/<change>/
  proposal.md                  # first line: Status: ready-for-sdd | Source: <planner>
  design.md
  specs/<capability>/spec.md   # delta specs (ADDED / MODIFIED / REMOVED / RENAMED)
  tasks.md
```

`<planner>` is the producing agent's name (e.g. `refactor-planner`). `<change>` is kebab-case and verb-led.

## Marker grammar

The first line of `proposal.md` must be exactly:

```
Status: ready-for-sdd | Source: <planner>
```

The orchestraitor's discovery scan keys on this line; without it a folder is invisible to intake. A same-session handoff additionally validates this marker against `handoff.producer` and `handoff.bundle` from the coordinator receipt.

## Coordinator handoff

A producer returns the complete public schema from `docs/delegation-receipts.md`. A ready bundle fills this block:

```yaml
handoff:
  kind: ready-for-sdd
  producer: <planner>
  change: <change>
  bundle: .ai/<planner>/changes/<change>/
```

The parent sends the entire compact receipt and exact bundle path to `orchestraitor` with `operation: execute-handoff`. The receipt carries routing context, not proposal or design bodies. In a new session, the same context can be reconstructed from the durable bundle and its exact marker.

## Roadmaps (oversized goals)

When a goal is too big for one bundle, a planner may split it into an ordered roadmap of slices; each slice is planned just-in-time into its own ready-for-sdd bundle and executed as its own bounded change. `deep-planner` is currently the only roadmap producer; the grammar stays planner-generic (`Source: <planner>`) so future producers reuse the same shape.

The roadmap lives at `.ai/roadmaps/<goal>.md` (`<goal>` kebab-case and verb-led; never overwrite on collision):

```
# Roadmap: <goal>
Status: active | Source: <planner>
Outcome: <one line: the end state when every slice is done>

| # | Slice | Scope | Depends on | Status | Bundle |
|---|---|---|---|---|---|
| 1 | <change> | <one line> | — | planned | .ai/<planner>/changes/<change>/ |
| 2 | <change> | <one line> | 1 | pending | — |
```

- Slice `Status`: `pending` (row only) → `planned` (planner drafts the bundle, fills `Bundle`) → `adopted` (orchestraitor, at adoption) → `done` (orchestraitor, at archive; `Bundle` points at the archive folder). Any non-`done` slice may also become `dropped` (either agent, only on the user's say-so): dropped slices are excluded from offers, and a dependent of a dropped slice is blocked until the user re-slices or also drops it.
- Roadmap `Status`: `active` → `done` when every slice is `done` or `dropped`, or `abandoned` (either agent, only on the user's say-so; abandoned roadmaps get no offers or mentions). The actor that closes the final outstanding slice sets `done`.
- The **next unblocked slice** is the first row by `#` that is not `done` (skipping `dropped`), with every `Depends on` entry `done`. Every offer, scan, and re-entry below resolves against this definition.
- Slices are planned just-in-time — one slice per planning sitting; later slices stay `pending` rows so they absorb what executed slices taught. "continúa el roadmap <goal>" is the deep-planner re-entry trigger.

A bundle that belongs to a roadmap declares it on the second line of `proposal.md`, immediately after the Status marker:

```
Roadmap: <goal> | Slice: <n>/<total>
```

Without this line nothing changes — the single-bundle flow is untouched. The slice row is matched by its `Slice` column, which always equals the bundle's `<change>` folder name; `<n>/<total>` is informational only — `<total>` is the slice count at that bundle's drafting time, so consumers must tolerate drift and never match on it. Re-slicing edits only the roadmap file, renumbering `Depends on` references among the edited `pending` rows; it never touches adopted or archived bundles' proposal lines. A not-yet-adopted `planned` slice whose bundle no longer fits reality may return to `pending` (discarding its stale bundle) only on user confirmation.

Consumer semantics (orchestraitor):

- At in-place adoption, match the row by `<goal>` + `<change>` in the `Slice` column, flip it to `adopted`, and keep its existing `Bundle` path. If the slice has `Depends on` entries not `done`, return `needs_input` and proceed only after primary-mediated confirmation. A missing, malformed, or `abandoned` roadmap never blocks plain bundle execution.
- At archive, flip the slice row to `done` (`Bundle` → archive path), then offer the next unblocked slice in ONE line and wait for the user — never auto-continue: `planned` → offer "ejecuta el plan <next-change>"; `pending` → offer running `/deep-plan` with "continúa el roadmap <goal>"; `adopted` (out-of-order execution in flight) → offer "continúa <change>". Every slice `done` or `dropped` → flip the roadmap `Status` to `done` and report it. A missing, malformed, or `abandoned` roadmap never blocks archive: report one line and finish normally (no row flips, no offers).

## Producer obligations

- A producer delegating to the shared sdd drafting agents sends `Draft context: handoff`, `Producer: <planner>`, `Depth: full`, and an exact target under `.ai/<planner>/changes/<change>/` in every brief. Each receipt must echo `draft_context: handoff`. `Draft context: active` is reserved for orchestraitor-owned artifacts and is not a handoff bundle.
- All four artifacts conform to the `sdd-draft-proposal`, `sdd-draft-spec`, `sdd-draft-design`, and `sdd-draft-tasks` templates, including the Review Workload Forecast guard lines in `tasks.md`.
- Tasks are small, ordered `- [ ] X.Y` checkboxes naming real files, sized for `sdd-implement` waves.
- Every task group MUST carry a `Files:` scope line, and the forecast MUST include the `Shared hotspots:` guard line (see `sdd-draft-tasks` >= 2.1.0). Intake still accepts legacy or malformed bundles without them, but the orchestraitor serializes those waves instead of parallelizing.
- Every claim is evidence-backed or marked hypothesis; hypotheses and behavior changes stay out of `tasks.md`.
- Do not write the `Mode: … | TDD: … | Judgment: … | Depth: … | Delivery: …` kickoff line; those choices belong to the user at adoption.
- Bundles are always full depth — the four-artifact shape is the contract; the light-mode `change.md` is not a valid bundle format, and adoption never asks Depth.

## Execution semantics (consumer: orchestraitor)

1. Same-session intake validates the full coordinator receipt, exact bundle path, complete marker, and four-artifact shape. New-session intake discovers one unique `.ai/*/changes/*/proposal.md` outside `.ai/orchestrator/` with the same exact marker grammar.
2. Adopt in place. The bundle path becomes the active change root; do not copy or move it into `.ai/orchestrator/changes/` and do not draft replacement artifacts.
3. Kickoff-lite: return `needs_input` for missing Mode/TDD/Judgment/Delivery values, then record the kickoff line (with `Depth: full`) immediately after the marker block. Create `<bundle>/state.md` at `Phase: implement`, with zero verify/judgment rounds and `Last verified: none`.
4. Implement from the first unchecked task, verify, optionally route Judgment through `review-coordinator`, and merge deltas into `.ai/orchestrator/specs/`. Archive the completed bundle under `.ai/<planner>/changes/archive/<date>-<change>/`.

A direct `operation: direct-sdd` is different: `orchestraitor` drafts its local proposal/specs/design/tasks under `.ai/orchestrator/changes/` before implementation. The handoff fast path never removes that direct-entry behavior.
