# Verify SDD Flows

Use deterministic contract checks for every change. Run model-backed scenarios only when explicitly authorized because they spend credits.

## Quick path

```bash
scripts/test-plan-sdd-contracts.sh
scripts/test-sdlc-orchestrator-contracts.sh
scripts/test-sdd-automode.sh
scripts/validate-harness.sh
```

Probe the real OpenCode binary before a paid flow:

```bash
OPENCODE_BIN=/absolute/path/to/opencode scripts/test-sdd-flows.sh probe
```

Then run `smoke`, `plan`, `lite`, or one scenario id. The harness uses `scripts/fixtures/sdd-agent-routes/java-orders/` and resets its scratch state.

## Scenario map

| Coverage | Scenario or suite | Pass evidence |
|---|---|---|
| Natural route | SDLC POC E2E | Primary selects the expected coordinator; only the primary asks questions |
| One-document handoff | `PLAN-HANDOFF-01` | Producer writes one ready `change.md`; SDD adopts the exact path without drafting children |
| Direct one-change SDD | `SDD-LIGHT-01`, `SDD-FULL-02` | Direct root contains `change.md` and `state.md`; work reaches cold verify and archive without drafting children |
| Ready-change adoption | `SDD-ADOPT-01` | Marker and source are validated; execution starts at the first unchecked work item |
| Bounded Lite | `LITE-01` | Scope gate holds; only `lite-verify` is delegated; archive contains `change.md` |
| Resume | resume path in `smoke` | One unique active root resumes its recorded phase without repeating planning |
| Verification and spec merge | `SDD-ARCH-01`, `SDD-ARCH-02` | Scoped commands pass; verified behavior reaches canonical specs only after success |
| Judgment | `SDD-JDG-04` | Requested judge topology runs, confirmed fixes are bounded, unresolved findings remain visible |
| Failure paths | contract suites plus negative fixtures | Malformed marker, ambiguous state, scope escape, red tests, or ambiguous A2A returns block rather than guess |

Scenario names remain stable handles; the scripts contain exact fixtures and assertions.

## Evidence rules

A chat claim is not a pass. Inspect:

- exact artifact paths, status markers, work checkboxes, and `state.md`;
- session task activity for expected and forbidden children;
- scoped Git diff/status and commit ownership;
- real build or test exit status;
- compact terminal return and its evidence pointer.

Paths outside the declared brief scope are not verifier gaps. Workers must not stage, commit, or push. With commit-per-wave, only `orchestraitor` may commit and it never pushes.

## Full project-profile proof

The release-evidence runner is deliberately one attempt per workflow:

```bash
SDLC_POC_E2E_CONFIRM=run-exactly-two-paid-workflows \
  OPENCODE_BIN=/absolute/path/to/opencode \
  scripts/test-sdlc-orchestrator-e2e.sh
```

It runs Plan-to-SDD and bounded Lite through the installed project primary. Evidence is stored under ignored `.ai/evidence/sdlc-orchestrator-poc/<timestamp>/`. Retain failures as evidence; do not hide nondeterminism with retries.

## Reporting

Record the commit, OpenCode version, model/profile, scenario id, artifact root, route tree, test result, and observed failure. Static checks prove text and permission contracts; only model-backed runs prove routing and handoff behavior.
