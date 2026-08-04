# OpenCode SDD Worktree Swarm POC

Status: experimental, explicit opt-in. The standard `orchestraitor` implementation path is unchanged.

The POC runs dependency-ready SDD task groups in isolated Git worktrees, verifies each worker's receipt and committed diff, and cherry-picks verified commits into a controller-owned integration worktree. It is a local development mechanism: it never pushes, opens a PR, or resolves a merge conflict automatically.

## Why A Plugin Instead Of Task Alone

OpenCode's built-in `Task` tool creates child sessions and can launch them concurrently. In OpenCode 1.18.10, only asynchronous background subagents are experimental (`OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`); `Task` itself is stable. Its input has no working-directory or worktree field, so child agents remain in the parent project instance. It is useful for read-only fan-out but not as mutation isolation. See the exact [Task 1.18.10 implementation](https://github.com/anomalyco/opencode/blob/v1.18.10/packages/opencode/src/tool/task.ts#L39-L107).

The `sdd-swarm` plugin keeps decisions in OpenCode while moving Git/process lifecycle into deterministic TypeScript. The worker processes are still OpenCode:

```text
/sdd-swarm <change>
  -> sdd-swarm supervisor
  -> sdd_swarm tool
  -> controller
     -> worktree + opencode run + sdd-swarm-worker (up to four)
     -> receipt/diff/scoped-validation gate
     -> integration worktree + full validation
```

The design follows the evidence behind centralized multi-agent systems: use a lead, bounded workers, complete briefs, explicit dependencies, and independent verification. Do not add peers, nested teams, or free-form inter-worker messaging to this POC.

Related evidence and precedents:

- OpenCode [Agent Teams proposal](https://github.com/anomalyco/opencode/issues/12711), [opencode-worktree](https://github.com/kdcokenny/opencode-worktree), [Oh My OpenAgent Team Mode](https://github.com/code-yeongyu/oh-my-openagent/blob/dev/docs/guide/team-mode.md), and [OpenCode Swarm](https://github.com/ZaxbyHub/opencode-swarm/blob/main/docs/architecture.md).
- Google Research, [Towards a science of scaling agent systems](https://research.google/blog/towards-a-science-of-scaling-agent-systems-when-and-why-agent-systems-work/).
- Anthropic, [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) and [Building a C compiler with a team of parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler).
- [MinionS](https://arxiv.org/abs/2502.15964) for the frontier-supervisor/economical-worker benchmark hypothesis; the POC does not assume its data-task result transfers to code.

## Components

- `/sdd-swarm <change>` — explicit command for an approved full-depth change.
- `sdd-swarm` — primary supervisor; it plans, starts, and reports durable runs.
- `sdd-swarm-worker` — one task group, one worktree, one commit, no nested tools.
- `sdd-swarm-baseline` — sequential control arm used only by the benchmark.
- `sdd-swarm.ts` — custom tool, parser, scheduler, process controller, verifier, integrator, and ledger.

Models remain user configuration. Agent files never contain provider or model ids. Use `docs/agent-models.md` or `/model-configurator` to map a frontier model to `sdd-swarm` and a cheaper capable model to `sdd-swarm-worker`.

## Requirements

The POC was built against:

- OpenCode 1.18.10.
- Node >= 22.18 with native TypeScript type stripping (verified locally with 26.5.1).
- Git 2.50.1 on a POSIX host.
- Java 17 and Maven 3.9.16 for the benchmark fixture.

Install the SDD domain from this worktree and reload OpenCode before a real-model run:

```bash
installers/opencode.sh install --domain sdd --reload
```

## Input Contracts

The change must exist at `.ai/orchestrator/changes/<change>/` and the repository working tree must be clean. Each new `tasks.md` group declares both scheduling dimensions:

```markdown
## 2. Shipping policy

Files: src/main/java/com/example/shipping/, src/test/java/com/example/shipping/
Depends on: none
```

`Depends on:` is `none` or earlier group numbers separated by commas. A legacy group without a valid dependency line remains accepted but runs alone in document order. Parallel groups also need disjoint `Files:` scopes and must not touch `Shared hotspots:`.

The project optionally defines deterministic commands in `.sdd-swarm.json`:

```json
{
  "schema_version": 1,
  "scoped_validation": {
    "1": ["mvn", "-B", "-o", "-Dtest=TaxCalculatorTest", "test"]
  },
  "full_validation": ["mvn", "-B", "-o", "test"],
  "final_validation": ["bash", ".sdd-swarm/golden-verify.sh"]
}
```

Commands are argv arrays and are spawned without a shell. `mock_worker` is fixture-only. A Maven project without a config falls back to `mvn -B test`; other project types must provide a config.

## Run Lifecycle

Use `/sdd-swarm parallel-checkout` inside OpenCode. The supervisor calls `plan` first and starts only a valid plan. The custom tool surface is:

```text
sdd_swarm {
  action: plan | run | status | abort | cleanup
  change?: kebab-case change name
  run_id?: durable id
  execution?: mock | opencode
  max_workers?: 1..4
  worker_timeout_seconds?: positive integer
}
```

Defaults are four workers and 1,200 seconds per worker. `run` returns immediately. Query later with the reported `run_id`; do not poll in a prompt loop.

State is atomically persisted under `.ai/sdd-swarm/<run-id>/run.json`; the append-only state ledger is `events.jsonl`, with process, worker, and validation logs beside it. Runtime worktrees default to:

```text
${XDG_DATA_HOME:-~/.local/share}/opencode/sdd-swarm/<repo-id>/<run-id>/
```

`SDD_SWARM_WORKTREE_ROOT` overrides that root for tests. Branches use `codex/swarm/<run-id>/task-<group>` and `codex/swarm/<run-id>/integration`.
The detached controller uses `node` from `PATH`; `SDD_SWARM_NODE_BIN` can select another Node >= 22.18 executable. This is intentionally separate from OpenCode's own executable.

Terminal states are `completed`, `blocked`, `failed`, `aborted`, and `interrupted`. Completion means every receipt, diff, scoped check, cherry-pick, full gate, and optional final gate passed. A dead controller is reported as `interrupted`; the ledger and worktrees remain for diagnosis. `abort` terminates recorded process groups. `cleanup` is explicit, preserves branches and the ledger, unlocks worktrees, and refuses to remove any dirty worktree.

## Verification

The deterministic suite uses a Java 17/Maven fixture with four independent groups, one four-way dependent integration group, and one shared hotspot. It also covers legacy serialization, overlapping scopes, technical retry, timeout, malformed/missing receipt, out-of-scope changes, real cherry-pick conflict/abort, golden verification, and safe cleanup:

```bash
scripts/test-sdd-swarm.sh
scripts/validate-harness.sh
```

The Task background probe spends model tokens and is separate:

```bash
SDD_SWARM_REAL_BENCHMARK_APPROVED=1 scripts/probe-sdd-swarm-task.sh
```

It enables `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true` internally, asserts that four background `Task` calls are launched before the first automatic notification, records wall time, and interrupts a separate parent session after its background task starts to exercise cancellation propagation. Set `SDD_SWARM_TASK_PROBE_MODEL=provider/model` for a reproducible model selection. It never edits files; cancellation is exercised through parent-session interruption because `Task` has no public cancel action.

## Real-Model Benchmark

The benchmark is opt-in and refuses to start without a cost budget and explicit models. It rotates three arms over three fresh repetitions:

1. One `sdd-swarm-baseline` agent, sequential.
2. `sdd-swarm` plus four workers using the same model.
3. Frontier `sdd-swarm` supervisor plus cheaper workers.

```bash
SDD_SWARM_REAL_BENCHMARK_APPROVED=1 \
SDD_SWARM_MAX_COST_USD=25 \
SDD_SWARM_SAME_MODEL=provider/model \
SDD_SWARM_TIERED_SUPERVISOR_MODEL=provider/frontier-model \
SDD_SWARM_TIERED_WORKER_MODEL=provider/worker-model \
scripts/benchmark-sdd-swarm.sh
```

The limit is checked after each completed model run, so one in-flight run can cross it. Raw JSONL, OpenCode events, stderr, state, and an English Markdown report are written under `.ai/sdd-swarm-benchmark/<timestamp>/` by default. The report includes worker versus serial integration time, retries, timeouts, conflicts, scope failures, verified groups per minute/unit, configuration, limitations, and the promotion decision.

For each correct repetition the report computes:

```text
efficiency = sqrt((single_time / arm_time) * (single_cost / arm_cost))
```

Provider cost is used when reported, otherwise total tokens. A failed correctness gate scores zero. Promote only when one swarm arm passes 3/3 and reaches median efficiency >= 1.25x. A score from 1.00x through 1.24x is inconclusive; below 1.00x or any correctness regression is not promoted.

## Safety And Limitations

- Worktrees isolate files and indexes, not Git refs, Maven caches, ports, services, databases, or rate limits. The fixture prewarms dependencies and gives every checkout its own `target/` and Java temp directory.
- The controller owns all worktree/branch creation and integration. Workers cannot use `Task`, `sdd_swarm`, external directories, push, merge, or rebase.
- Every worker must produce exactly one commit. The controller compares the real diff with `Files:` and the receipt; model self-report is never sufficient.
- A conflict, dirty tree, out-of-scope path, bad receipt, timeout, or red gate blocks the run and preserves evidence. There is no autonomous conflict repair.
- Integration remains serial. Tasks with strong dependencies or hotspots should be expected to show little or no speedup.
- No forge, CI server, distributed queue, UI plugin, Windows support, or remote workers are included.
