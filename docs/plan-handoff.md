# Plan Handoff Contract

How external planners hand complete OpenSpec change bundles to the sdd `orchestraitor` for execution. `refactor-planner`, `architect` (via `/arch-ideate`), and `deep-planner` (via `/deep-plan`) are the current producers; any future planner (performance, migration, security) reuses the same shape.

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

The orchestraitor's discovery scan keys on this line; without it a folder is invisible to intake.

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
- Roadmap `Status`: `active` → `done` (orchestraitor, when the last slice archives) or `abandoned` (either agent, only on the user's say-so; abandoned roadmaps get no offers or mentions).
- The **next unblocked slice** is the first row by `#` that is not `done` (skipping `dropped`), with every `Depends on` entry `done`. Every offer, scan, and re-entry below resolves against this definition.
- Slices are planned just-in-time — one slice per planning sitting; later slices stay `pending` rows so they absorb what executed slices taught. "continúa el roadmap <goal>" is the deep-planner re-entry trigger.

A bundle that belongs to a roadmap declares it on the second line of `proposal.md`, immediately after the Status marker:

```
Roadmap: <goal> | Slice: <n>/<total>
```

Without this line nothing changes — the single-bundle flow is untouched. The slice row is matched by its `Slice` column, which always equals the bundle's `<change>` folder name; `<n>/<total>` is informational only — `<total>` is the slice count at that bundle's drafting time, so consumers must tolerate drift and never match on it. Re-slicing edits only the roadmap file, renumbering `Depends on` references among the edited `pending` rows; it never touches adopted or archived bundles' proposal lines. A not-yet-adopted `planned` slice whose bundle no longer fits reality may return to `pending` (discarding its stale bundle) only on user confirmation.

Consumer semantics (orchestraitor):

- At adoption, match the row by `<goal>` + the moved folder's original name in the `Slice` column, flip it to `adopted`, and repoint its `Bundle`; if the folder was renamed on collision, rewrite the row's `Slice` to the new name. If the adopted slice has `Depends on` entries not `done`, warn in one line and adopt only on user confirmation. A missing, malformed, or `abandoned` roadmap never blocks adoption: report one line and adopt as a plain bundle (no row flips, no offers).
- At archive, flip the slice row to `done` (`Bundle` → archive path), then offer the next unblocked slice in ONE line and wait for the user — never auto-continue: `planned` → offer "ejecuta el plan <next-change>"; `pending` → offer running `/deep-plan` with "continúa el roadmap <goal>"; `adopted` (out-of-order execution in flight) → offer "continúa <change>". Every slice `done` or `dropped` → flip the roadmap `Status` to `done` and report it. A missing, malformed, or `abandoned` roadmap never blocks archive: report one line and finish normally (no row flips, no offers).

## Producer obligations

- All four artifacts conform to the `sdd-draft-proposal`, `sdd-draft-spec`, `sdd-draft-design`, and `sdd-draft-tasks` templates, including the Review Workload Forecast guard lines in `tasks.md`.
- Tasks are small, ordered `- [ ] X.Y` checkboxes naming real files, sized for `sdd-implement` waves.
- Task groups SHOULD carry the `Files:` scope line and the forecast SHOULD include the `Shared hotspots:` guard line (see `sdd-draft-tasks` >= 2.1.0); bundles without them still adopt — the orchestraitor simply serializes those waves instead of parallelizing.
- Every claim is evidence-backed or marked hypothesis; hypotheses and behavior changes stay out of `tasks.md`.
- Do not write the `Mode: … | TDD: … | Judgment: … | Depth: … | Delivery: …` kickoff line; those choices belong to the user at adoption.
- Bundles are always full depth — the four-artifact shape is the contract; the light-mode `change.md` is not a valid bundle format, and adoption never asks Depth.

## Adoption semantics (consumer: orchestraitor)

1. Discover on "ejecuta el plan <change>" or during the session-start scan: `.ai/*/changes/*/proposal.md` (excluding `.ai/orchestrator/`) with the marker first line.
2. Adopt by moving the whole folder to `.ai/orchestrator/changes/<change>/`; never overwrite, ask for a new name on collision. The `Source:` marker stays.
3. Kickoff-lite: ask the Mode/TDD/Judgment/Delivery round once, record the kickoff line (with `Depth: full`) in `proposal.md` on the first line after the marker block (the `Status: ready-for-sdd | Source: …` line plus the optional `Roadmap:` line) — the marker stays the first line.
4. Normal sdd flow from there: implement from the first unchecked task, verify, optional judgment, archive. On archive, spec deltas merge into canonical specs — behavior-preservation deltas progressively document the system.
