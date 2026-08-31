# Orchestration Test Plan

Run deterministic checks by default. Model-backed flows spend credits and require explicit authorization.

## Quick path

```bash
scripts/test-primary-agent-contracts.sh
scripts/test-plan-orchestration-contracts.sh
scripts/test-orchestration-permissions.sh
scripts/test-multi-primary-profile.sh
```

These scripts validate routing, state boundaries, development and delivery precedence, plan immutability, Git ownership, shared-skill installation, permissions, and profile inventory without a model or network.

## Model-backed harness

Set an explicit OpenCode binary, then choose one scenario from [Plan and Orchestration Flow Scenarios](plan-flow-test-scenarios.md).

```bash
OPENCODE_BIN=/absolute/path/to/opencode scripts/test-orchestration-flows.sh probe
ORCHESTRATION_FLOW_CONFIRM=run-paid-flow \
  OPENCODE_BIN=/absolute/path/to/opencode \
  scripts/test-orchestration-flows.sh DIRECT-RENAME-01
```

The harness copies `scripts/fixtures/orchestration-agent-routes/java-orders/` into isolated scratch state. It installs the current checkout into that project's `.opencode/` before each model call. Select one scenario id from the scenario guide; `probe` checks only the binary and fixture without model credits.

Delivery scenarios compare the final repository with the captured baseline. They verify commit count, message order, path scope, parent continuity, full-SHA `run.md` rows, source-plan hash, clean implementation paths, and exclusion of `.ai/`. `SDD-COMMIT-FAILURE-01` injects a Maven failure only after the first green commit to prove that later failure preserves the commit and active run.

A deterministic contract or `probe` pass is not model-backed proof. The model-backed scenarios are available but remain unverified until each selected call exits successfully with its final assertions.

## Evidence rules

- Capture the final process output.
- Treat silence, timeout, or interruption as not passed.
- Keep model-backed state isolated from the repository.
- Keep `ORCHESTRATION_FLOW_KEEP=1` only when the scratch repository is needed for manual evidence review.
- Do not run this section without explicit authorization.
