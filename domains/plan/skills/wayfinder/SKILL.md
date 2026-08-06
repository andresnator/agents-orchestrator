---
name: wayfinder
description: "Plan a foggy multi-session effort as decision tickets until it is clear enough for /deep-plan. Use only through /wayfinder."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: Agents Orchestrator maintainers
  source: https://github.com/mattpocock/skills/tree/main/skills/engineering/wayfinder
  status: testing
  version: "2.0.0"
---

## Contract

Use only through `/wayfinder` when the destination cannot be planned in one session. Wayfinder resolves decisions, not implementation. The canonical local map is `.ai/wayfinder/<map>/map.md` plus `tickets/`, using the supplied assets.

## Tickets

- One precise question per ticket; record `type`, `status`, `blocked-by`, and `claimed-by`.
- Claim before work. The frontier is open, unblocked, unclaimed work.
- HITL tickets require the human; never answer their side. AFK research may delegate against primary sources and store findings under the map.
- Keep unresolved but imprecise decisions in `Not yet specified`; keep work beyond the destination in `Out of scope`.

## Operations

**Chart:** name the destination through `grilling` + `domain-modeling`; map the frontier and fog; create tickets, then dependencies; resolve only delegated research; stop.

**Advance:** load `map.md`; choose and claim one frontier ticket; resolve it; close it with a Resolution; update the map pointer, new tickets, dependencies, and fog; stop. Research tickets may run in parallel. Expect concurrent map edits.

Never resolve more than one human decision per session. If no fog exists, say the effort does not need a map. When the route is clear, hand off to `/deep-plan`: executable work becomes one ready `change.md` (or a roadmap plus one slice `change.md`); decisions become a plan document.

## Attribution

Original skill by Matt Pocock from <https://github.com/mattpocock/skills>.
