# Harness Flow Map

This document maps the agent harnesses in this repository and evaluates them for overlap, coverage, orchestration cost, and routing gates. It is an analysis artifact: no executable frontmatter, installer behavior, or skill contract changes live here.

## Executive Summary

The repo has two heavy orchestration clusters and three lighter routing domains.

| Cluster | Shape | Primary boundary |
|---|---|---|
| SDD | Single hybrid primary agent with a conversational kickoff | `orchestraitor` interviews, drafts, and implements itself; it delegates only to its 5 `permission.task` allowlisted subagents (explore, judgment-day, and the built-in `general` for self-contained background work and automatic-mode artifact drafting) and manages artifacts OpenSpec-style under `.orchestraitor/**`. |
| Refactor | Risk-gated planning plus TCR execution | `refactor-planner` delegates only to its 18 `permission.task` allowlisted analysis/composition/gate subagents and writes only `.ia-refactor/plan/**`; `refactor-executor` does not delegate. |
| Docs | Thin command routers | `/doc`, `/prd`, and `/english` select the smallest relevant skill or subagent. |
| Meta | Prompt and registry utilities | `/prompt-checker` routes to `prompt-structure-writer`; `skill-registry.ts` generates `.atl/skill-registry.md`. |
| Common | Reusable inspection | `/boundary-inspector` delegates to the bounded `boundary-inspector` subagent. |

Legend:

| Convention | Meaning |
|---|---|
| `primary` | OpenCode primary agent, usually user-facing or command target. |
| `subagent` | Delegated worker, phase, reviewer, or bounded specialist. |
| `-->` | Delegation edge, authoritative only when present in `permission.task` allowlists for SDD and refactor hubs. |
| `-. skill .->` | Skill load, not subagent delegation. |
| `GATE` | User question, safety review, linter, or explicit execution precondition. |
| `A & B` | Parallel fan-out. |

## Global Map

Delegation edges from `orchestraitor` and `refactor-planner` are taken from their `permission.task` allowlists. Router-to-skill edges are derived from command bodies and agent required-skill sections.

```mermaid
flowchart TD
  subgraph SDD["domain: sdd"]
    SDDHub["orchestraitor<br/>primary"]
    SDDHub --> SExplore["sdd-explore"]
    SDDHub --> JDA["jd-judge-a"]
    SDDHub --> JDB["jd-judge-b"]
    SDDHub --> JDFix["jd-fix"]
    SDDHub --> Gen["general (built-in)<br/>self-contained / background"]
    SDDHub -. skill .-> GrillSDD["grill + sdd-draft-*"]
    SDDHub -. skill .-> JDSkill["judgment-day"]
  end

  subgraph Refactor["domain: refactor"]
    CPlan["/refactor-plan"] --> RPlanner["refactor-planner<br/>primary"]
    CExec["/refactor-execute"] --> RExec["refactor-executor<br/>primary"]
    RPlanner --> RScope["scope-analyzer"]
    RPlanner --> RRisk["risk-assessor"]
    RPlanner --> RBehavior["behavior-characterizer"]
    RPlanner --> RSeam["dependency-seam-finder"]
    RPlanner --> RTest["test-planner"]
    RPlanner --> RArch["architecture-reviewer"]
    RPlanner --> RTool["tooling-auditor"]
    RPlanner --> RNaming["naming-readability-reviewer"]
    RPlanner --> RSize["function-size-responsibility-reviewer"]
    RPlanner --> RSolid["solid-design-reviewer"]
    RPlanner --> RDup["duplication-simplicity-reviewer"]
    RPlanner --> RCohesion["cohesion-coupling-reviewer"]
    RPlanner --> RTypes["type-contract-nullability-reviewer"]
    RComplex["complexity-performance-reviewer"]
    RPlanner --> RComplex
    RPlanner --> RAnti["antipattern-reviewer"]
    RPlanner --> RLog["logging-observability-reviewer"]
    RPlanner --> RCompose["refactor-openspec-composer"]
    RPlanner --> RGate["refactor-safety-gate-reviewer"]
  end

  subgraph Docs["domain: docs"]
    Doc["/doc"] -. skill .-> ADR["adr"]
    Doc -. skill .-> RFC["rfc"]
    Doc -. route .-> PRD["/prd"]
    Doc -. skill .-> USM["usm"]
    Doc -. skill .-> Spike["jira-spike"]
    Doc -. skill .-> Issue["buildable-issue"]
    Doc -. skill .-> CogDoc["cognitive-doc-design"]
    PRD -. skill .-> PRDFull["prd"]
    PRD -. skill .-> PRDLight["prd-light"]
    English["/english"] --> EnglishAgent["english-tutor"]
  end

  subgraph Meta["domain: meta"]
    Prompt["/prompt-checker"] -. skill .-> PSW["prompt-structure-writer"]
    Registry["skill-registry.ts"] --> ATL[".atl/skill-registry.md"]
  end

  subgraph Common["domain: common"]
    BoundaryCmd["/boundary-inspector"] --> BoundaryAgent["boundary-inspector"]
    BoundaryAgent -. skill .-> BoundarySkill["service-boundary-analysis"]
  end

  JDA -. reads .-> ATL
  JDB -. reads .-> ATL
  JDFix -. reads .-> ATL
```

## Harness Diagrams

### SDD

Sources: `domains/sdd/agents/orchestraitor.md`, `skills/judgment-day/SKILL.md`, and `docs/sdd-domain-sequence.md`.

```mermaid
flowchart TD
  Request["User: vamos con sdd"] --> Trivial{"trivial or mechanical?"}
  Trivial -->|yes| Direct["orchestraitor edits directly<br/>no artifacts"]
  Trivial -->|no| Kickoff["kickoff questions<br/>mode / TDD / judgment"]

  Kickoff --> Explore["sdd-explore<br/>(or inline read)"]
  Explore --> Draft["proposal -> specs || design -> tasks<br/>interactive: sdd-draft-* interview + gates<br/>automatic: drafted directly"]
  Draft --> Implement["implement tasks.md<br/>TDD if chosen"]
  Implement --> Verify["verify against spec scenarios"]
  Verify --> JudgmentRoute{"judgment requested?"}
  JudgmentRoute -->|no| Archive["archive: merge deltas<br/>into canonical specs"]
  JudgmentRoute -->|yes| JDA2["jd-judge-a"]
  JudgmentRoute -->|yes| JDB2["jd-judge-b"]
  JDA2 --> Synth["synthesis<br/>confirmed suspect contradiction"]
  JDB2 --> Synth
  Synth -->|confirmed| Fix["jd-fix"]
  Fix --> Rejudge{"re-judge<br/>max 2 rounds"}
  Rejudge -->|still failing| Escalate["question user"]
  Rejudge -->|clean| Archive
  Synth -->|clean| Archive
```

Key observations:

| Area | Current behavior |
|---|---|
| Entry | Conversational: "vamos con sdd" or any non-trivial development request; no commands, no automatic triage. |
| Kickoff | One question round via `native-question-ux`: interactive/automatic mode, TDD, judgment. Ceremony scales down to a direct edit for trivial changes. |
| Gates | Interactive mode confirms after the proposal and after specs plus design; automatic mode only stops when genuinely blocked. |
| Artifacts | OpenSpec-style under `.orchestraitor/`: canonical `specs/`, active `changes/<name>/`, and `changes/archive/` with deltas merged into canonical specs. |

### Refactor Plan

Sources: `domains/refactor/agents/refactor-planner.md` and `docs/workflows/refactor-plan.md`.

```mermaid
flowchart TD
  Start["/refactor-plan target"] --> Lock["freeze plan_target"]
  Lock --> Scope["scope-analyzer"]
  Scope --> UnitGate{"units <= 8?"}
  UnitGate -->|no| Block["blocked<br/>narrow target"]
  UnitGate -->|yes| Risk["risk-assessor"]
  Risk --> Depth{"risk-gated depth"}

  Depth -->|low -> light| Light["scope + risk only"]
  Depth -->|medium -> standard| Standard["selected reviewer lenses"]
  Depth -->|high critical -> deep| Deep["behavior seam test architecture tooling<br/>+ all 9 lenses"]

  Standard --> Reducer["dedupe and partition findings"]
  Deep --> Reducer
  Light --> Reducer
  Reducer --> Compose["refactor-openspec-composer"]
  Compose --> Lint["plan-lint.sh"]
  Lint --> Safety["refactor-safety-gate-reviewer"]
  Safety -->|needs_changes max 3| Compose
  Safety -->|approved| Plan["17-section plan<br/>.ia-refactor/plan/**"]
```

Depth fan-out:

| Depth | Trigger | Delegation profile |
|---|---|---|
| `smoke` | explicit `mode=smoke` or `--smoke` | No analysis fan-out; writes a lintable stub plan, not executable. |
| `light` | `risk: low` | `scope-analyzer`, `risk-assessor`, then planner-authored minimal findings. |
| `standard` | `risk: medium` | Always naming and type-contract lenses; additional lenses by method count, collaborators, target size, and logging evidence. |
| `deep` | `risk: high` or `critical` | Five additional workers plus all nine reviewer lenses in one fan-out message, then composer and safety gate. |

### Refactor Execute

Source: `domains/refactor/agents/refactor-executor.md`.

```mermaid
flowchart TD
  ExecStart["/refactor-execute plan"] --> Resolve["resolve explicit or latest plan"]
  Resolve --> Validate{"valid 17-section plan<br/>Section 17 approved?"}
  Validate -->|no| ExecBlock["blocked no edits"]
  Validate -->|yes| Baseline["git status + baseline validation"]
  Baseline -->|red or dirty| ExecBlock
  Baseline -->|green| TaskLoop["for each unchecked tasks.md task"]
  TaskLoop --> Evidence{"evidence still valid?"}
  Evidence -->|no| Deviation["record deviation"]
  Evidence -->|yes| Edit["smallest behavior-preserving edit"]
  Edit --> Test["task validation"]
  Test -->|green| Commit["mark task complete + report + commit"]
  Test -->|red| Revert["revert task changes + report"]
  Commit --> Continue{"more tasks?"}
  Revert --> StopRule{"two consecutive reverts<br/>or unrecoverable baseline?"}
  Deviation --> Continue
  Continue -->|yes| TaskLoop
  Continue -->|no| Report["execution report"]
  StopRule -->|yes| Partial["partial or blocked"]
  StopRule -->|no| TaskLoop
```

Execution gates:

| Gate | Effect |
|---|---|
| Plan shape | Rejects anything without exactly the expected 17-section contract. |
| `Depth:` | Rejects `smoke`; smoke is for harness validation only. |
| Section 17 | Requires `safety_review.status: "approved"` before any edits. |
| Baseline | Requires clean worktree and an explicit allowed validation command. |
| TCR loop | Green validation commits; red validation reverts the current task only. |

### Docs, Meta, Common

```mermaid
flowchart LR
  Doc["/doc"] --> DocSelect{"request shape"}
  DocSelect --> ADR["adr"]
  DocSelect --> RFC["rfc"]
  DocSelect --> PRDRouter["/prd"]
  DocSelect --> USM["usm"]
  DocSelect --> Spike["jira-spike"]
  DocSelect --> Buildable["buildable-issue"]
  DocSelect --> Cog["cognitive-doc-design"]

  PRDRouter --> PRDChoice{"rigor needed?"}
  PRDChoice --> PRDFull["prd"]
  PRDChoice --> PRDLight["prd-light"]

  EnglishCmd["/english"] --> EnglishAgent2["english-tutor subagent"] -. skill .-> EnglishSkill["english-tutor"]
  PromptCmd["/prompt-checker"] -. skill .-> PromptSkill["prompt-structure-writer<br/>Evaluation Mode"]
  Boundary["/boundary-inspector"] --> BoundarySub["boundary-inspector"] -. skill .-> BoundaryTax["service-boundary-analysis"]
  SkillRegistry["skill-registry.ts"] --> RegistryDoc[".atl/skill-registry.md"]
```

These domains are mostly routers, not multi-phase harnesses. They matter because they introduce reusable skills into the same installation target and because judgment-day can read the generated registry as "Project Standards".

### Installer

Source: `installers/opencode.sh`.

```mermaid
flowchart TD
  Install["opencode.sh install"] --> Filters["domain/status filters"]
  Filters --> DiscoverAgents["discover domains/*/agents/*.md"]
  Filters --> DiscoverCommands["discover domains/*/commands/*.md"]
  Filters --> DiscoverSkills["discover domains/*/skills/* symlinks"]
  Filters --> DiscoverPlugins["discover domains/*/plugins/*.ts"]
  DiscoverAgents --> LinkAgents["symlink target/agents"]
  DiscoverCommands --> LinkCommands["symlink target/commands"]
  DiscoverSkills --> LinkSkills["symlink target/skills to top-level skills"]
  DiscoverPlugins --> LinkPlugins["symlink target/plugins"]
  LinkAgents --> Manifest["write .agents-orchestrator-manifest"]
  LinkCommands --> Manifest
  LinkSkills --> Manifest
  LinkPlugins --> Manifest
  Manifest --> Sync["next install removes stale manifest-owned links"]
```

Installer notes:

| Area | Behavior |
|---|---|
| Targets | Default `~/.config/opencode`; `--project` targets `./.opencode`; `--target` supports scratch installs. |
| Status filter | Applies to skills only. Agents, commands, and plugins are not status-filtered because executable frontmatter cannot carry repo-only metadata. |
| Skill source | Domain skill entries must be symlinks to top-level `skills/<skill>`. |
| Sync | The manifest lets future installs remove previously owned links that are no longer selected. |

## Evaluation

### 1. Overlap And Redundancy

| Finding | Evidence | Evaluation |
|---|---|---|
| SDD planning path unified | The 2026-07-06 simplification removed the phase agents (`sdd-{propose,spec,design,tasks,apply,verify}`); `orchestraitor` now drives the interview-first `sdd-draft-*` skills directly. | Resolved: one planning path, two interaction modes (interactive/automatic). |
| Multiple review systems | SDD uses judgment-day dual blind judges (opt-in); refactor has nine reviewer lenses. | Intentional depth ladder, but review naming should make scope obvious to avoid invoking the expensive path for routine checks. |
| Generic refactor skill overlaps refactor domain | `skills/refactor/SKILL.md` is a 62+ technique catalog, while `domains/refactor` provides planning/execution harnesses. | Keep the skill as technique reference; avoid routing it as a replacement for `/refactor-plan`. |
| `single-responsibility` is reused by two lenses | `function-size-responsibility-reviewer` loads `single-responsibility`; `solid-design-reviewer` also loads it. | Acceptable reuse, but findings can duplicate. The planner reducer is the right dedupe point. |
| Two SDD entrypoints | `grill` keeps its standalone `sdd` mode for pure planning interviews; `orchestraitor` runs the full build cycle using the same `sdd-draft-*` skills. | Acceptable: `grill sdd` is plan-only drafting in chat; `orchestraitor` plans and implements. Both write `.orchestraitor/changes/`. |

### 2. Coverage And Gaps

| Finding | Evidence | Risk or gap |
|---|---|---|
| No refactor runtime plugin | `domains/refactor/plugins/` has no plugin files. | The write boundary depends on OpenCode permission frontmatter and prompt contracts, not a global write-guard plugin. This is simpler but makes permission drift more important to review. |
| Backlog skills are installable unless filtered out | Current frontmatter count: 10 backlog skills, including `buildable-issue` and `tcr`. `/doc` references `buildable-issue`; `refactor-executor` loads `tcr`. | Status is lifecycle metadata, not a hard runtime block unless installer filters are used. Backlog dependencies should be reviewed before promoting a workflow as stable. |
| `meta` has no agents | `domains/meta/agents/` is absent; meta has one command and one plugin. | Fine for now: prompt checking is skill-only and registry behavior is plugin runtime. Add an agent only when prompt/meta work needs delegation or scoped permissions. |
| Isolated leaf flows | `boundary-inspector` and `english-tutor` are useful leaf agents but not integrated into larger SDD or refactor flows. | This keeps them simple. The tradeoff is duplicated manual invocation when a larger workflow needs boundary or language review. |
| Refactor execution observes tests, not app runtime | `refactor-executor` gates on baseline validation and TCR task validation. | Good for behavior-preserving refactors, but there is no explicit running-app observation phase beyond tests and user-approved validation commands. |

### 3. Cost And Orchestration Depth

| Harness | Tier or depth | Subagent count | Fan-out points | Cost controls |
|---|---:|---:|---|---|
| SDD | trivial change | 0 subagents | none | No artifacts, no kickoff. |
| SDD | default change | 0-1 (`sdd-explore` only when the area is unknown or large), plus up to 4 `general` drafters in automatic mode (proposal, specs ∥ design, tasks) and optional `general` calls for self-contained tasks | drafting wave 2 (specs and design in parallel); `general` in background for independent work | Kickoff choices; interactive gates after proposal and specs+design. |
| SDD | with judgment | explore plus 2 judges and `jd-fix`, repeated up to 2 fix rounds | `jd-judge-a` and `jd-judge-b` in blind parallel rounds | Opt-in at kickoff; confirmed-only fixes; max 2 rounds. |
| Refactor plan | light | 2 delegated analysis agents plus composer/gate path as needed | none | `risk: low` skips reviewer panel. |
| Refactor plan | standard | 2 base agents plus selected lenses plus composer and gate | selected reviewer subset | Lens heuristics by size, collaborators, and logging evidence. |
| Refactor plan | deep | 16 analysis/reviewer subagents in one fan-out, then composer and safety gate | 5 workers plus 9 lenses after scope and risk | Risk-gated depth, target unit cap, reducer, lint, and max 3 safety iterations. |
| Refactor execute | approved plan | 0 delegated subagents | none | Section 17 approval, clean baseline, TCR commits/reverts, stop rules. |

### 4. Routing And Gates

| Gate or route | Location | Purpose |
|---|---|---|
| SDD kickoff | `orchestraitor` | One question round: mode (interactive/automatic), TDD, judgment; ceremony scales down for trivial changes. |
| SDD proposal gate | interactive mode, after the proposal draft | Approves intent, scope, approach, and capability binding. |
| SDD plan gate | interactive mode, after specs plus design | Approves the implementation contract before tasks. |
| Judgment-day synthesis | `judgment-day` skill | Separates confirmed, suspect, and contradiction buckets; only confirmed findings go to `jd-fix`. |
| Refactor risk gate | `refactor-planner` | Converts risk to depth and controls fan-out. |
| Refactor safety gate | `refactor-safety-gate-reviewer` plus `plan-lint.sh` | Blocks malformed, speculative, or unsafe plans before completion. |
| Refactor execute gate | `refactor-executor` | Requires valid Section 17 approved plan before edits. |
| Task allowlists | `orchestraitor` and refactor planner frontmatter | Make delegation boundaries explicit: `*` denied, named subagents allowed. |

## Appendix: Inventory

Current inventory from the working tree:

| Type | Count |
|---|---:|
| Agents | 27 |
| Commands | 7 |
| Skills | 66 |
| Domain skill symlinks | 67 |
| Plugins | 1 |

By domain:

| Domain | Agents | Commands | Skill symlinks | Plugins |
|---|---:|---:|---:|---:|
| common | 1 | 1 | 27 | 0 |
| docs | 1 | 3 | 13 | 0 |
| meta | 0 | 1 | 2 | 1 |
| refactor | 20 | 2 | 18 | 0 |
| sdd | 5 | 0 | 7 | 0 |

Skill lifecycle status, from `skills/*/SKILL.md` frontmatter:

| Status | Count |
|---|---:|
| backlog | 10 |
| in-progress | 37 |
| testing | 16 |
| done | 3 |

### Agent To Skill Loads

This table lists explicit, stable skill loads. Some agents select additional skills dynamically from caller payloads or language detection.

| Agent or command | Explicit skill loads |
|---|---|
| `orchestraitor` | `native-question-ux` for the kickoff and gates; `sdd-draft-proposal`, `sdd-draft-spec`, `sdd-draft-design`, `sdd-draft-tasks` for drafting; `judgment-day` when judgment is requested; `tcr` offered for TDD cadence. |
| `sdd-explore` | No separate homonymous skill; discovery behavior is in the agent prompt. |
| `refactor-executor` | `tcr`, `work-unit-commits`. |
| `refactor-openspec-composer` | `openspec-refactor-composition`. |
| `refactor-safety-gate-reviewer` | `refactor-plan-safety-gates`. |
| `naming-readability-reviewer` | `reviewer-output-contract`, then `java-naming-readability` or `general-naming-readability`. |
| `function-size-responsibility-reviewer` | `reviewer-output-contract`, `small-functions`, `single-responsibility`. |
| `solid-design-reviewer` | `reviewer-output-contract`, `single-responsibility`, `open-closed-principle`, `dependency-inversion`. |
| `duplication-simplicity-reviewer` | `reviewer-output-contract`, `dry-business-knowledge`, `kiss-yagni`. |
| `cohesion-coupling-reviewer` | `reviewer-output-contract`, `cohesion-coupling`. |
| `type-contract-nullability-reviewer` | `reviewer-output-contract`, `type-contracts`, `null-safety`, `input-validation-preconditions`. |
| `complexity-performance-reviewer` | `reviewer-output-contract`, `complexity-big-o`. |
| `antipattern-reviewer` | `reviewer-output-contract`, `god-object-detection`, `spaghetti-code-detection`. |
| `logging-observability-reviewer` | `reviewer-output-contract`, `logging-observability`. |
| `english-tutor` | `english-tutor`. |
| `boundary-inspector` | `service-boundary-analysis`. |
| `/doc` | `adr`, `rfc`, `usm`, `jira-spike`, `buildable-issue`, `cognitive-doc-design`, or `/prd` by request shape. |
| `/prd` | `prd` or `prd-light` after triage confirmation. |
| `/prompt-checker` | `prompt-structure-writer` Evaluation Mode. |
| `grill` SDD mode | `grilling`, `native-question-ux`, `sdd-draft-proposal`, `sdd-draft-spec`, `sdd-draft-design`, `sdd-draft-tasks`. |

### Verification Checklist

- Mermaid blocks use simple `flowchart` syntax suitable for GitHub preview.
- SDD delegation edges match the 5 named `permission.task` allows in `domains/sdd/agents/orchestraitor.md` (including OpenCode's built-in `general`).
- Refactor planner delegation edges match the 18 named `permission.task` allows in `domains/refactor/agents/refactor-planner.md`.
- Every agent and skill named in the inventory exists in `domains/*/agents/` or `skills/`.
- This file is documentation-only under `docs/` and does not change executable frontmatter or installer behavior.
