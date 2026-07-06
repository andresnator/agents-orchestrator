# SDD Harness PRD

## Tiers

- **T0 - Direct**: one-file mechanical changes; the `sdd-build` agent edits inline, no artifacts, no gates.
- **T1 - Quick** (`/sdd-quick`): bounded changes in a known area; one CodeGraph exploration, one writer, one advisory review.
- **T2 - Full SDD** (`/sdd-new`): new features, unknown areas, hot paths, or large diffs; the full `explore -> propose -> spec || design -> tasks -> apply -> verify -> review -> ship -> archive` chain with visual gates.

## Source PRD

| | |
|---|---|
| **Status** | Proposal v2 (goal corrected 2026-07-03: personal harness design, not a multi-CLI product) |
| **Date** | 2026-07-03 |
| **Owner** | Andres (solo freelance developer) |
| **Target** | OpenCode (single CLI) |

---

## 1. Goal

Design and set up a **personal development harness on OpenCode** for daily work. The harness is a curated configuration — agents, skills, commands, state conventions, and MCP wiring — that shapes how every piece of work flows from idea to merged PR.

Hard requirement: the harness contains the **SDD flow** (`explore → propose → spec ∥ design → tasks → apply → verify → archive`).

Profile constraints: solo developer, no team features, **no context persistence** (file-based state only, disposable), token-frugal, per-subagent model routing, parallelism where it pays, visual questions via OpenCode's native `question` tool.

### Non-goals

- No multi-CLI adapters, no `sync` compiler, no product to maintain. This is *my* config, versioned in a dotfiles-style repo.
- No external memory backend. State lives in files inside each project.
- No heavyweight process for trivial work — the harness must scale ceremony DOWN, not just up.

## 2. Best practices adopted (what was taken from each harness)

| Source | Practice adopted |
|---|---|
| **Claude Code harness** | Plan-first gate (plan mode → approve → execute); visual question gates (AskUserQuestion pattern); thin-context subagents that return summaries; skills as lazy-loaded procedures; hooks for session automation; "lead with the outcome" result discipline |
| **gentle-ai / agent-teams-lite** | SDD Orchestrator = coordinator, never executor; 4-file rule (4+ files to understand → delegate exploration); structured result envelope (`status, executive_summary, artifacts, next, risks`); lazy-loaded workflow doc; phase → model table; judgment-day blind dual review (max 2 fix rounds, then escalate); review lenses with the >400-line trigger |
| **Hermes** | Fresh subagent per task + **two-stage review** (stage 1: spec compliance; stage 2: code quality); elicitation only at the top level (subagents return questions, never ask) |
| **CodeGraph** | Index-first exploration: one `codegraph_explore` call instead of grep/read fan-out (−58% tool calls); `.codegraph/` per project |
| **External memory pattern** | Deterministic artifact keys (`sdd/{change}/{artifact}`) — reused as **file paths** instead of memory keys, since persistence is excluded |
| **OpenCode native** | Per-agent `model`/`tools`/`permission` frontmatter; `question` tool + permission; `subtask: true` commands for context isolation; `compaction { auto, prune }`; primary/subagent split |

## 3. The daily flow (core of the design)

Not everything deserves the full SDD cycle. The harness routes every request through a **triage step** into one of three tiers, and can escalate mid-flight — ceremony proportional to blast radius.

### Triage (sdd-orchestrator, first response)

| Signal | Tier |
|---|---|
| 1 file, mechanical, no behavior change (typo, rename, config bump) | **T0 — Direct** |
| ≤3 files, known area, behavior change bounded, no hot path | **T1 — Quick** |
| New feature, unknown area, hot path (auth/payments/security/update), or est. >400 lines | **T2 — Full SDD** |

Escalation rule: a T0/T1 task that grows past its tier's bounds STOPS and escalates (T1 inherits the work done; T2 starts at `propose` with the exploration already in hand).

### T0 — Direct (seconds)
`sdd-build` agent edits inline. No artifacts. Guard: if a second non-trivial file gets touched → escalate to T1.

### T1 — Quick (minutes) — `/sdd-quick <task>`
1. **Explore-lite**: one `codegraph_explore` query (no file crawling).
2. **Apply**: single writer subagent, fresh context, tests run.
3. **Review**: ONE lens (`sdd-review-quality`) advisory before commit.
No proposal/spec/design artifacts; only a `tasks.md`-style checklist in the change folder if >1 work unit.

### T2 — Full SDD (hours/days) — `/sdd-new <idea>`
```
explore ──► propose ──[GATE]──► spec ∥ design ──[GATE]──► tasks ──► apply ──► verify ──► review ──[GATE]──► ship ──► archive
```
- **Gates** are visual `question`-tool prompts to the user (approve / adjust / abort). Only the sdd-orchestrator asks; subagents return `status: blocked` + `questions[]` in their envelope and the sdd-orchestrator relays.
- **spec ∥ design** run as parallel subagent sessions after the proposal is approved.
- **verify** runs real tests + a spec-compliance matrix (Hermes stage-1 review).
- **review** = code quality (Hermes stage-2): `sdd-review-quality` + `sdd-review-risk` in parallel; **judgment-day** (blind judges A ∥ B → fix → re-judge) replaces them when the diff touches hot paths or exceeds 400 lines.
- **ship** = branch + conventional commits + PR (work-unit commit discipline).
- **archive** merges delta specs into `specs/` and deletes/closes the change folder.

### Daily rhythm
- **Session start**: `/sdd-status` — reads `.arnes/changes/*/state.yaml`, reports active change, current phase, next gate. No memory system needed: state is re-read from files every session.
- **During the day**: T0/T1 for interrupts and small fixes; the active T2 change advances phase by phase via `/sdd-continue`.
- **Pre-commit / pre-PR**: review lens (T1) or full review stage (T2) — the only mandatory quality gates.
- **Session end**: nothing to persist; `state.yaml` already reflects reality.

## 4. Architecture (OpenCode-native, no extra tooling)

```
~/.config/opencode/              # global harness (versioned as dotfiles)
├── opencode.json                # primary agent, permissions, MCP (codegraph!), compaction
├── agents/*.md                  # subagents with per-agent model frontmatter
├── commands/*.md                # /sdd-quick /sdd-new /sdd-continue /sdd-status /sdd-review /sdd-ship
├── skills/<name>/SKILL.md       # lazy-loaded procedures (SDD phases, judgment-day, elicit…)
└── plugins/                     # existing TS plugins (keep skill-registry; no memory backend)

<project>/.arnes/changes/<name>/ # per-change ephemeral state (gitignored or committed, my call per repo)
├── state.yaml                   # tier, phase, gates passed — single source of truth
├── proposal.md  spec.md  design.md  tasks.md
└── handoffs/<phase>.md          # ≤30-line executive summary consumed by the next phase
```

Key `opencode.json` settings:
- `mcp.codegraph` registered (`codegraph serve --mcp`) — closes the current gap where prompts demand CodeGraph but no server exists.
- `compaction: { auto: true, prune: true }`.
- SDD Orchestrator permissions: `question: allow`; `task` allowlist restricted to the harness subagents; `edit/write: deny` (coordinator never writes code).

### Context & token rules (enforced by prompts + structure)
1. SDD Orchestrator thread carries only envelopes and `state.yaml` — never file contents.
2. Every phase = fresh subagent session; input = its handoff + only the artifacts it needs.
3. CodeGraph before any grep/read for structural questions (4-file rule as backstop).
4. Workflow doc lazy-loads via skill invocation, not the always-on prompt.
5. Cheap models for mechanical phases (table below).

## 5. Agents (opencode `agents/*.md`, per-agent `model:`)

| Agent | Mode | Model | Role |
|---|---|---|---|
| `sdd-orchestrator` | primary | session default | Triage + gates + delegation; only user-facing questioner; no write access |
| `sdd-build` | primary | balanced | T0 direct edits (Tab-switch for trivial work without ceremony) |
| `sdd-explore` | subagent | cheap | Read-only, CodeGraph-first |
| `sdd-propose` | subagent | strong | Intent, scope, rollback |
| `sdd-spec` | subagent | balanced | Delta specs, Given/When/Then |
| `sdd-design` | subagent | strong | Architecture decisions + rationale |
| `sdd-tasks` | subagent | balanced | Phased checklist |
| `sdd-apply` | subagent | balanced | Single writer; marks tasks done; runs tests |
| `sdd-verify` | subagent | balanced | Spec-compliance matrix + real test run |
| `sdd-review-quality` | subagent | balanced | Readability + reliability lens (T1 default) |
| `sdd-review-risk` | subagent | balanced | Risk + resilience lens (T2, hot paths) |
| `jd-judge-a` / `jd-judge-b` | subagent | balanced | Blind adversarial judges (parallel) |
| `jd-fix` | subagent | balanced | Confirmed findings only; max 2 rounds → escalate |

Aliases resolved once in frontmatter (e.g. `strong` = opus-class, `balanced` = sonnet-class, `cheap` = haiku-class). Changing providers = editing frontmatter, nothing else.

## 6. Commands & skills

**Commands** (`commands/*.md`): `/sdd-quick` (T1 pipeline, `subtask: true`), `/sdd-new`, `/sdd-continue`, `/sdd-status`, `/sdd-review` (manual lens run), `/sdd-ship` (branch + work-unit commits + PR).

**Skills** (lazy procedures): `sdd-workflow` (the full phase contract — loaded only by SDD commands), `judgment-day`, `elicit` (blocked-envelope question relay), `context-handoff` (envelope + handoff conventions, 4-file rule), plus the existing curated skills that stay (branch-pr, work-unit-commits, chained-pr for >400-line splits).

## 7. Implementation plan (lean — it's configuration, not a product)

| Step | Deliverable |
|---|---|
| **S1 — Wiring** | Register CodeGraph MCP; set compaction; keep the daily flow file-backed; define `.arnes/changes/` state contract (`state.yaml` schema + handoff format) |
| **S2 — Agents & models** | Write the 13 agent files with per-agent model frontmatter and permission blocks |
| **S3 — Flow commands** | `/sdd-quick`, `/sdd-new`, `/sdd-continue`, `/sdd-status`, `/sdd-ship` + the `sdd-workflow` skill (triage table + gates encoded here) |
| **S4 — Review layer** | Lenses + judgment-day + escalation triggers (hot paths, >400 lines) |
| **S5 — Shakedown** | One real T1 and one real T2 change on `legacy-java-test`; measure tokens with/without CodeGraph; tune the triage thresholds |

## 8. Acceptance criteria

- A trivial fix ships through T0 with zero artifacts and zero gates.
- A `/sdd-quick` task completes with exactly one CodeGraph call and one advisory review.
- A T2 change passes every gate via the visual `question` tool, with spec ∥ design and judges A ∥ B observably parallel.
- The sdd-orchestrator session never contains source file contents — only envelopes.
- `/sdd-status` fully reconstructs harness state from files after a cold start (no memory backend).

## 9. References

- Research notes: NousResearch/hermes-agent (delegation, two-stage review) · anomalyco/opencode + opencode.ai/docs (agents, question, compaction) · Gentleman-Programming/gentle-ai (sdd-orchestrator, judgment-day, lenses) · an external memory harness (excluded; key-scheme pattern reused as paths) · colbymchenry/codegraph (index-first exploration) · Claude Code (plan gate, question UX, subagent discipline)
