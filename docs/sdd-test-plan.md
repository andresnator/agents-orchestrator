# Verify SDD Flows

Run deterministic contracts for every change. Run model-backed scenarios only with explicit authorization because they spend credits.

## Quick path

```bash
scripts/test-plan-sdd-contracts.sh
scripts/test-sdlc-orchestrator-contracts.sh
scripts/test-sdd-automode.sh
scripts/validate-harness.sh
```

Before a paid flow, probe the real binary:

```bash
OPENCODE_BIN=/absolute/path/to/opencode scripts/test-sdd-flows.sh probe
```

Then run `smoke`, `plan`, `lite`, or one scenario id. The harness copies `scripts/fixtures/sdd-agent-routes/java-orders/` into scratch state.

## Scenario map

| Coverage | Scenario or suite | Pass evidence |
|---|---|---|
| Natural route | SDLC POC E2E | Expected coordinator; only primary asks questions |
| One-document handoff | `PLAN-HANDOFF-01` | Producer writes one change; SDD adopts exact path |
| Direct full SDD | `SDD-LIGHT-01`, `SDD-FULL-02` | Change and state reach verification and archive |
| Ready-change adoption | `SDD-ADOPT-01` | Valid marker; first unchecked work starts |
| Bounded Lite | `LITE-01` | Scope holds; only `lite-verify` delegates |
| Resume | `smoke` resume path | Unique active root resumes recorded phase |
| Verification and merge | `SDD-ARCH-01`, `SDD-ARCH-02` | Tests pass before canonical merge |
| Judgment | `SDD-JDG-04` | Requested judges run; fixes stay bounded |
| Failures | Contract suites and negative fixtures | Invalid or ambiguous state blocks |

Scenario ids are stable handles; scripts own exact fixtures and assertions.

## Evidence rules

A chat claim is not a pass. Capture:

- exact artifact paths, markers, work checkboxes, and `state.md`;
- routed skill names, availability, allowlists, and worker skill calls;
- expected and forbidden child sessions;
- scoped Git status and commit ownership;
- real build or test exit status;
- compact terminal return and evidence pointer.

Paths outside a declared brief are not verifier gaps. Workers never stage, commit, or push. With commit-per-wave, only `orchestraitor` commits and it never pushes.

## Full project-profile proof

The paid runner performs one Plan-to-SDD workflow and one bounded Lite workflow, without retries:

```bash
SDLC_POC_E2E_CONFIRM=run-exactly-two-paid-workflows \
  OPENCODE_BIN=/absolute/path/to/opencode \
  scripts/test-sdlc-orchestrator-e2e.sh
```

Evidence goes under ignored `.ai/evidence/sdlc-orchestrator-poc/<timestamp>/`. Keep failures; retries would hide nondeterminism.

## Reporting

Record commit, OpenCode version, model profile, scenario id, artifact root, route tree, test result, and failure. Static checks prove text and permission contracts; only model-backed runs prove live routing and handoff behavior.
