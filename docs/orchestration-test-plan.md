# Orchestration Test Plan

Run deterministic checks by default. Model-backed flows spend credits and require explicit authorization.

## Quick path

```bash
scripts/test-primary-agent-contracts.sh
scripts/test-plan-orchestration-contracts.sh
scripts/test-orchestration-permissions.sh
scripts/test-multi-primary-profile.sh
```

These scripts validate routing, state boundaries, plan immutability, skills, permissions, and profile inventory without a model or network.

## Model-backed harness

Set an explicit OpenCode binary, then choose one scenario from [Plan and Orchestration Flow Scenarios](plan-flow-test-scenarios.md).

```bash
OPENCODE_BIN=/absolute/path/to/opencode scripts/test-orchestration-flows.sh probe
ORCHESTRATION_FLOW_CONFIRM=run-paid-flow \
  OPENCODE_BIN=/absolute/path/to/opencode \
  scripts/test-orchestration-flows.sh smoke
```

The harness copies `scripts/fixtures/orchestration-agent-routes/java-orders/` into isolated scratch state. It installs the current checkout into that project's `.opencode/` before each model call. A dry-run or deterministic harness is not model-backed proof.

## Evidence rules

- Capture the final process output.
- Treat silence, timeout, or interruption as not passed.
- Keep model-backed state isolated from the repository.
- Do not run this section without explicit authorization.
