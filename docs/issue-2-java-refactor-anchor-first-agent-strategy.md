# Issue 2 Strategy: Java Refactor Anchor-First Agent

Issue 2 should be implemented as a **dumb primary orchestrator plus bounded phase subagents communicating through Engram**. This keeps context small: the orchestrator routes phases and enforces gates, but subagents do the real reading, analysis, writing, verification, and evidence capture.

## Quick path

1. Add `agents/primary/java-refactor-anchor-first.md` as the dumb orchestrator.
2. Add phase subagents only where context would otherwise explode: baseline audit, test anchoring, TCR refactor slices, and evidence curation.
3. Use Engram topic keys as the communication bus; pass references, not full content.
4. Add golden scenarios under `scenarios/java-refactor-anchor-first/README.md`.
5. Update `agents/primary/README.md`, `agents/subagents/README.md`, and only if broadly useful, the root `README.md` recommended entries.

## Implementation shape

| Area | Strategy |
|---|---|
| Layer | Add one dumb primary orchestrator plus specialist subagents for all substantive work. |
| Orchestrator file | `agents/primary/java-refactor-anchor-first.md` |
| Subagent files | `agents/subagents/java-refactor-baseline-auditor.md`, `agents/subagents/java-refactor-test-anchorer.md`, `agents/subagents/java-refactor-tcr-worker.md`, `agents/subagents/java-refactor-evidence-curator.md` |
| Communication | Engram topic keys; the orchestrator passes references and gate status only. |
| Related skills | `java-testing`, `refactor-java`, `tcr`, `chained-pr`. |
| Evidence | Engram is the phase communication source of truth; OpenSpec or project evidence files are optional outputs when explicit paths are provided. |
| Validation | Scenario/golden-case docs, because this repo has no runtime test framework. |
| Permissions | Start conservative: no autonomous edits until the human confirms baseline build/tests/coverage/mutation are available. |

## Implementation status

Implemented files:

- `agents/primary/java-refactor-anchor-first.md`
- `agents/subagents/java-refactor-baseline-auditor.md`
- `agents/subagents/java-refactor-test-anchorer.md`
- `agents/subagents/java-refactor-tcr-worker.md`
- `agents/subagents/java-refactor-evidence-curator.md`
- `scenarios/java-refactor-anchor-first/README.md`

The SDD cycle for this change passed verification and was archived in Engram.

## Context-saving architecture

```text
java-refactor-anchor-first primary orchestrator
│  └─ Dumb router: no codebase exploration, no implementation, no deep analysis.
├─ java-refactor-baseline-auditor
│  └─ Reads build/test config only; saves baseline + tooling gate report to Engram.
├─ java-refactor-test-anchorer
│  └─ Reads target scope; writes characterization tests/seams; saves coverage + mutation evidence to Engram.
├─ java-refactor-tcr-worker
│  └─ Reads one refactor slice; applies refactor-java + TCR; saves commit/slice evidence to Engram.
└─ java-refactor-evidence-curator
   └─ Reads Engram phase summaries only; updates final evidence, with optional OpenSpec/project files when provided.
```

The orchestrator must stay intentionally dumb. It should not ingest source files, build files, test files, coverage reports, mutation reports, or OpenSpec content. It tracks only:

- target scope,
- current gate status,
- Engram topic keys,
- artifact paths when needed,
- next phase,
- human decisions.

Each phase subagent writes durable output to Engram and returns only a compact status envelope.

## Engram communication contract

Engram is the source of truth between phases. The orchestrator passes these topic keys, not expanded artifacts:

| Artifact | Topic key |
|---|---|
| Run state | `java-refactor-anchor-first/{run-id}/state` |
| Baseline audit | `java-refactor-anchor-first/{run-id}/baseline-audit` |
| Target scope | `java-refactor-anchor-first/{run-id}/target-scope` |
| Test anchor evidence | `java-refactor-anchor-first/{run-id}/test-anchor` |
| Coverage evidence | `java-refactor-anchor-first/{run-id}/coverage` |
| Mutation evidence | `java-refactor-anchor-first/{run-id}/mutation` |
| Refactor slice plan | `java-refactor-anchor-first/{run-id}/slice-plan` |
| TCR slice progress | `java-refactor-anchor-first/{run-id}/tcr-slice-{n}` |
| Review-size decision | `java-refactor-anchor-first/{run-id}/review-strategy` |
| Evidence report | `java-refactor-anchor-first/{run-id}/evidence-report` |

Subagents must update their own topic keys and include enough evidence for the next phase to continue without rereading unrelated context.

### Subagent return envelope

Every phase subagent returns this compact shape:

```yaml
status: blocked | ready | complete | failed
gate: baseline | tooling | test-anchor | coverage | mutation | refactor | review-size | evidence
engram_topics:
  read: []
  written: []
next_recommended: <next phase or human decision needed>
human_question: <one question only, when blocked>
risk: low | medium | high
```

The orchestrator reads the envelope, updates run state in Engram, and launches the next subagent. It does not summarize raw code or tool output itself.

## Agent contract

The orchestrator should make one promise:

> Guide a Java refactor only after existing behavior is anchored by tests and quality gates prove the anchor is strong enough.

It should explicitly refuse to continue when:

- the project does not compile,
- existing tests are red,
- coverage tooling is missing or unverified,
- mutation tooling is missing or unverified,
- the target scope is unclear,
- coverage is below 100% for the target scope,
- mutation score is outside the accepted 80-100% target range,
- the user wants to mix behavior fixes with refactoring.

## Workflow gates

### 1. Human pre-flight

The first response must warn the human that the baseline must already be healthy, then ask one blocking question: whether build, tests, coverage, and mutation testing were verified.

If the answer is no or uncertain, the agent offers help verifying and stops. This matters because a refactor on an unstable baseline is not engineering; it is gambling with nicer syntax.

This step stays in the orchestrator because it is cheap and avoids launching subagents before the human confirms the baseline. The result is saved to `java-refactor-anchor-first/{run-id}/state`.

### 2. Skill and tooling validation

Before writing tests, the agent checks that the required skills and Java tooling are available. It should distinguish:

- Maven vs Gradle vs other build setup,
- JaCoCo or equivalent coverage tooling,
- PIT or equivalent mutation tooling,
- test framework and assertion/mocking style.

Missing tools are setup work, not refactor work. The agent should ask before changing build files.

This work belongs to `java-refactor-baseline-auditor` because it may need to inspect build files, test config, and plugin setup. It writes `baseline-audit`, `coverage`, and `mutation` topic keys as needed.

### 3. Behavior anchoring

The testing phase may add characterization tests and minimal seams only. It must not clean up structure, rename concepts, or fix discovered bugs.

Any discovered bug becomes follow-up work with evidence, because anchoring behavior and changing behavior in the same flow destroys the safety net.

This work belongs to `java-refactor-test-anchorer` because it is the first phase that may need broad target-scope code context. It writes `test-anchor`, `coverage`, and `mutation` topic keys.

### 4. Gates before refactor

The agent cannot enter refactor mode until:

- target-scope coverage is 100%,
- mutation score is between 80% and 100%,
- tests are green,
- any exclusions are justified in Engram evidence or an explicitly provided evidence document.

### 5. Refactor with TCR

Once gates pass, the agent applies `refactor-java` techniques through mandatory TCR micro-cycles:

```text
choose one smell/technique
→ make the smallest safe refactor
→ run focused tests/gates
→ commit on green or revert on red
```

This work belongs to `java-refactor-tcr-worker`, launched per slice to keep each context window small. Each slice writes a separate `tcr-slice-{n}` topic key.

### 6. Review-size guard

At or near 400 changed lines, the agent stops and asks the human to choose a chained PR strategy. If the human is unsure, the agent recommends one with tradeoffs and asks for confirmation.

The orchestrator owns this decision because it is a review strategy gate, not a code-analysis task. It saves the decision to `review-strategy`.

### 7. Evidence curation

`java-refactor-evidence-curator` updates Engram-first final evidence from phase summaries only. It should not read the full codebase. If an OpenSpec or project evidence path is provided explicitly, it may update that file too. Its job is to keep traceability durable without polluting the orchestrator context.

## Golden scenarios

Add scenario coverage for these cases:

| Scenario | Expected verdict |
|---|---|
| Human has not verified baseline | Agent warns, offers verification help, and stops. |
| Coverage tooling missing | Agent treats setup as blocker and asks before build-file changes. |
| Mutation tooling missing | Agent treats setup as blocker and asks before build-file changes. |
| Characterization exposes a bug | Agent documents follow-up and does not fix it. |
| Coverage below 100% | Agent keeps testing; no refactor. |
| Mutation below 80% | Agent strengthens tests; no refactor. |
| Gates pass | Agent enters TCR refactor mode. |
| Diff approaches 400 lines | Agent asks for chained PR strategy. |
| Evidence curation | Evidence curator updates Engram-first evidence from compact phase summaries, not raw code context. |
| Context control | Orchestrator passes Engram topic keys and compact envelopes, not raw source or reports. |

## Definition of done

- [x] `agents/primary/java-refactor-anchor-first.md` exists and follows the primary-agent conventions.
- [x] Phase subagents exist for baseline audit, test anchoring, TCR refactor slices, and evidence curation.
- [x] Orchestrator and subagents state responsibility, boundaries, related skills, input shape, and output contract.
- [x] Orchestrator is explicitly forbidden from reading raw code or doing implementation work.
- [x] Engram topic-key communication contract is documented in the orchestrator and every phase subagent.
- [x] Agent has explicit blocking gates for baseline, tooling, coverage, mutation, and review size.
- [x] `scenarios/java-refactor-anchor-first/README.md` validates the important behavioral branches.
- [x] `agents/primary/README.md` and `agents/subagents/README.md` list the new agents.
- [x] Root `README.md` is updated as a curated recommended entry.

## Recommendation

Implement this in three reviewable work units:

1. **Dumb orchestrator + baseline auditor**: establish routing, Engram topic keys, pre-flight, tooling gates, and README entries.
2. **Test anchorer + TCR worker**: add the two code-heavy phase agents and their compact output contracts.
3. **Evidence curator + scenarios**: add Engram-first evidence handling and golden cases that prove unsafe refactors are blocked.

Do not start by writing a giant all-knowing prompt. Start with the dumb orchestrator contract, Engram topic keys, and phase boundaries. The VALUE here is discipline plus context control: make unsafe refactoring impossible without making every agent carry the whole project in memory.
