# Plan Handoff Contract

How external planners hand complete OpenSpec change bundles to the sdd `orchestraitor` for execution. `refactor-planner` and `architect` (via `/arch-ideate`) are the current producers; any future planner (performance, migration, security) reuses the same shape.

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

## Producer obligations

- All four artifacts conform to the `sdd-draft-proposal`, `sdd-draft-spec`, `sdd-draft-design`, and `sdd-draft-tasks` templates, including the four Review Workload Forecast guard lines in `tasks.md`.
- Tasks are small, ordered `- [ ] X.Y` checkboxes naming real files, sized for `sdd-implement` waves.
- Every claim is evidence-backed or marked hypothesis; hypotheses and behavior changes stay out of `tasks.md`.
- Do not write the `Mode: … | TDD: … | Judgment: …` line; those choices belong to the user at adoption.
- Bundles are always full depth — the four-artifact shape is the contract; the light-mode `change.md` is not a valid bundle format, and adoption never asks Depth.

## Adoption semantics (consumer: orchestraitor)

1. Discover on "ejecuta el plan <change>" or during the session-start scan: `.ai/*/changes/*/proposal.md` (excluding `.ai/orchestrator/`) with the marker first line.
2. Adopt by moving the whole folder to `.ai/orchestrator/changes/<change>/`; never overwrite, ask for a new name on collision. The `Source:` marker stays.
3. Kickoff-lite: ask the Mode/TDD/Judgment round once, record it in `proposal.md`.
4. Normal sdd flow from there: implement from the first unchecked task, verify, optional judgment, archive. On archive, spec deltas merge into canonical specs — behavior-preservation deltas progressively document the system.
