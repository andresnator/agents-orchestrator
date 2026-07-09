# Plan Domain

Fable-style deep planning for features, changes, and technical decisions, producing single plan documents. The `refactor` domain covers refactor/hardening planning with ready-for-sdd bundles; this domain covers everything else you want planned rigorously before touching code.

One primary agent: `deep-planner` (plan-only; explores inline, with optional read-only fan-out to the built-in `general` subagent when scope spans several independent areas). Commands: `/deep-plan`, `/premortem` (grilling-style pre-mortem interview that ends in a prioritized risk register under the same plans root), and `/wayfinder` (discovery on-ramp, below). The methodology lives in the `fable-planning` skill so any agent can reuse it; `grilling` + `native-question-ux` drive the single clarification round, `code-conventions` supplies the language/tool-version evidence rule, and `judgment-day` is the opt-in adversarial review of the finished plan.

When the effort is too big and foggy for one `/deep-plan` sitting, `/wayfinder` sits upstream: the `wayfinder` skill charts a multi-session discovery map under `.ai/wayfinder/<map-slug>/` — investigation tickets (research / prototype / grilling / task) resolved one decision per session, with `grilling` + `domain-modeling` driving the HITL tickets — until the way is clear, then hands off to `/deep-plan` (or sdd drafting).

The plan is a human-readable document under `.ai/deep-planner/plans/<plan-slug>.md` with four sections: Context (why + decisions made with the user), Design (approach, rejected alternatives, files, reused `path:symbol`), an Edge Case Matrix where every edge ends in exactly one destination (handled / out of scope / open question — never silently dropped), and an end-to-end Verification section that exercises the real flow.

Deliberately **not** a ready-for-sdd bundle: the output is for humans first; execution is informal (hand the file to the sdd `orchestraitor` in direct mode). If automatic adoption is ever wanted, add a bundle mode following `docs/plan-handoff.md`.

```mermaid
graph TD
  wf[/wayfinder loose idea/] --> map[".ai/wayfinder/&lt;map-slug&gt;/<br/>map + tickets, one decision per session"]
  map -.->|way clear| cmd
  cmd[/deep-plan goal/] --> architect[deep-planner]
  architect --> explore[explore inline<br/>optional general x N read-only]
  explore --> clarify[one clarification round<br/>grilling + native-question-ux]
  clarify --> design[design: reuse-first,<br/>alternatives, files]
  design --> edges[edge validation<br/>three-destinations rule]
  edges --> selfcheck[write plan + self-check]
  selfcheck --> plan[".ai/deep-planner/plans/&lt;slug&gt;.md<br/>Context / Design / Edge Matrix / Verification"]
  plan -.->|opt-in| judgment[/judgment adversarial review/]
  plan -.->|informal handoff| orchestraitor[sdd orchestraitor executes]
```
