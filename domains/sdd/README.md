# SDD Domain

Spec-driven development around one primary coordinator: `orchestraitor`. Start it conversationally ("vamos con sdd") or use `/judgment` for a standalone adversarial review.

Agents:

- `orchestraitor` (primary coordinator)
- `sdd-explore` (read-only discovery)
- `sdd-proposal`, `sdd-spec`, `sdd-design`, `sdd-tasks`, `sdd-implement`, `sdd-verify` (single-responsibility phase subagents)
- `jd-judge-a`, `jd-judge-b`, `jd-fix` (judgment-day review, opt-in)

The orchestraitor keeps the interview, confirmation gates, integration, checkbox updates, and archive in the main session. Phase work goes to dedicated subagents so each phase can receive a separate `model:` later without changing the flow. The built-in `general` subagent remains allowlisted only for auxiliary self-contained chores such as lateral research, fixtures, or background test suites; it must not draft, implement, or verify SDD phases.

Artifacts live OpenSpec-style under `.ai/orchestrator/` in each project: canonical `specs/` per capability, active `changes/<name>/` with proposal/design/spec deltas/tasks, and `changes/archive/` with deltas merged into canonical specs on completion. At resume/startup, legacy `.orchestraitor/` or `.orchestrator/` state is migrated into `.ai/orchestrator/` without overwriting existing files.

```mermaid
graph TD
  user[Usuario: vamos con sdd] --> orch[orchestraitor]
  orch --> explore[sdd-explore]
  orch --> proposal[sdd-proposal]
  proposal --> spec[sdd-spec]
  proposal --> design[sdd-design]
  spec --> tasks[sdd-tasks]
  design --> tasks
  tasks --> implement[sdd-implement]
  implement --> verify[sdd-verify]
  verify --> jd[jd-judge-a / jd-judge-b / jd-fix]
  orch --> aux[general: auxiliary chores only]
  orch --> files[.ai/orchestrator specs + changes + archive]
```
