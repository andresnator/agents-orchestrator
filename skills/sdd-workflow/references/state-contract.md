# Arnes State Contract — `.arnes/changes/<name>/`

All harness state is file-based, per project, and disposable. There is no memory backend: every session reconstructs reality from these files.

## Directory layout

```
<project>/.arnes/
├── changes/
│   └── <change-slug>/
│       ├── state.yaml            # single source of truth (sdd-orchestrator-owned)
│       ├── proposal.md           # written by sdd-propose (T2 only)
│       ├── spec.md               # written by sdd-spec (T2 only)
│       ├── design.md             # written by sdd-design (T2 only)
│       ├── tasks.md              # written by sdd-tasks; checkboxes updated by sdd-apply
│       ├── verify-report.md      # written by sdd-verify
│       └── handoffs/
│           ├── explore.md        # one per completed phase, ≤30 lines each
│           ├── propose.md
│           ├── spec.md
│           ├── design.md
│           ├── tasks.md
│           ├── apply.md
│           └── verify.md
└── archive/                      # optional destination for closed changes
```

T0 work creates no folder. T1 folders typically contain only `state.yaml`, `handoffs/explore.md`, and optionally a minimal `tasks.md`.

## state.yaml schema

Created and updated exclusively by the sdd-orchestrator at every phase transition and gate decision. No subagent may write it.

| Field | Type | Allowed values / format |
|---|---|---|
| `change` | string | slug; must equal the folder name |
| `tier` | enum | `T1`, `T2` |
| `phase` | enum | `sdd-explore`, `propose`, `spec`, `design`, `tasks`, `apply`, `verify`, `review`, `ship`, `archive` |
| `gates` | list | entries `{gate, decision, at}`; `gate`: `propose` \| `plan` \| `review`; `decision`: `approve` \| `adjust` \| `abort`; `at`: ISO 8601 timestamp |
| `artifacts` | list | filenames relative to the change folder (plus PR URL after ship) |
| `created` | timestamp | ISO 8601 |
| `updated` | timestamp | ISO 8601, touched on every write |

Example:

```yaml
change: dark-mode-toggle
tier: T2
phase: verify
gates:
  - gate: propose
    decision: approve
    at: 2026-07-03T14:05:00Z
  - gate: plan
    decision: approve
    at: 2026-07-03T15:40:00Z
artifacts:
  - proposal.md
  - spec.md
  - design.md
  - tasks.md
created: 2026-07-03T13:40:00Z
updated: 2026-07-03T17:02:00Z
```

## Handoff file rules

- Path: `handoffs/<phase>.md`, written by the phase's agent immediately before it returns.
- Maximum 30 lines: decisions, artifact paths, risks, open points. Pointers, not payloads.
- The next phase reads the handoff first and opens full artifacts only when it needs detail the handoff does not carry.
- Handoffs are immutable once written; a re-run of a phase (gate decision `adjust`) overwrites its own handoff.

## Lifecycle

1. **Created** by `/sdd-quick` (tier T1) or `/sdd-new` (tier T2): folder, `handoffs/`, and initial `state.yaml`.
2. **Advanced** by `/sdd-continue` (T2) or within the `/sdd-quick` pipeline (T1); the sdd-orchestrator updates `state.yaml` at every transition.
3. **Shipped** via `/sdd-ship`: branch, work-unit conventional commits, PR; the gate decision and PR URL are recorded.
4. **Archived**: delta specs from `spec.md` are merged into the project's `specs/` directory (create it if absent), then the change folder is deleted or moved to `.arnes/archive/<change-slug>/`. `phase: archive` in `state.yaml` marks a closed change if the folder is kept.

## Disposability

The entire `.arnes/` tree carries no persistence guarantees. It can be deleted at any time; only merged specs, commits, and PRs survive by design. Whether to git-track `.arnes/` (audit trail) or gitignore it (noise-free history) is a per-repository preference — either choice is valid.
