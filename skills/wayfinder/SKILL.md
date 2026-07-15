---
name: wayfinder
description: "Plan an effort too big and foggy for one agent session as a shared map of investigation tickets, resolved one decision per session until the way to the destination is clear. Use only when invoked via the /wayfinder command, with a loose idea to chart or an existing map to advance."
license: MIT
metadata:
  author: Matt Pocock
  adapted_by: Agents Orchestrator maintainers
  source: https://github.com/mattpocock/skills/tree/main/skills/engineering/wayfinder
  status: testing
  version: "1.0.1"
---

# Wayfinder

A loose idea has arrived — too big for one agent session, and wrapped in fog: the way from here to the **destination** isn't visible yet. Wayfinding is about finding that way, not charging at the destination. This skill charts the way as a **shared map** of investigation tickets, then works them one at a time until the route is clear.

The destination varies per effort, and naming it is the first act of charting — it shapes every ticket. It might be a plan to hand to `/deep-plan`, a decision to lock before drafting starts, or a change made in place like a data-structure migration.

## Activation

This skill activates only through the `/wayfinder` command; never reach for it on your own. If the opening interview surfaces no fog — the whole journey fits one session — say so and stop: the effort doesn't need a map.

## Plan, don't do

Wayfinder is **planning** by default: each ticket resolves a decision, and the map is done when nothing is left to decide before someone goes and does the thing. The pull to just do the work is usually the signal you've reached the edge of the map and it's time to hand off. An effort can override this in the map's **Notes** — carrying execution into the map itself — but absent that, produce decisions, not deliverables.

## The map

The map is the canonical artifact. By default it lives as **local markdown** under `.ai/wayfinder/<map-slug>/`: `map.md` (the map body — template in `assets/map-template.md`) plus one file per ticket under `tickets/`. If the project already runs a real issue tracker, the map may live there instead — a parent issue labelled `wayfinder:map` with tickets as child issues, using the tracker's native blocking (for Jira, draft tickets with the `jira-spike` / `jira-task` skills). Tracker-specific tool names are examples only; local markdown is the portable default.

The map is an **index, not a store**: each decision lives in exactly one place — its ticket — and the map only gists and links, never restates. A session loads `map.md` once at low resolution and zooms into individual ticket files on demand.

**Refer by name.** Every map and ticket has a name — its title. In everything the human reads, refer to tickets by name (wrapping the link), never by a bare filename, id, or number.

## Tickets

Each ticket is one question sized to a single agent session — template in `assets/ticket-template.md`. Its header records `type`, `status`, `blocked-by`, and `claimed-by` (in tracker mode, use the native equivalents: labels, state, dependency links, assignee).

- A session **claims** a ticket by setting `claimed-by` **first**, before any work, so concurrent sessions skip it.
- A ticket is **unblocked** when every ticket in its `blocked-by` list is closed.
- The **frontier** is the open, unblocked, unclaimed tickets — the edge of the known, what's takeable now.
- The answer isn't part of the body: it's recorded in the ticket's **Resolution** section on close. Assets created while resolving are linked from the ticket, not pasted in.

## Ticket types

Every ticket is **HITL** (human in the loop) or **AFK** (agent alone). A HITL ticket only resolves through a live exchange — the agent never stands in for the human's side of it.

- **Research** (AFK): reading documentation, third-party APIs, or local resources. Produces a markdown summary linked from the ticket. Use when knowledge outside the working directory is required.
- **Prototype** (HITL): raise the fidelity of the discussion with a cheap, rough, concrete artifact to react to — an outline, a stub, a sketch of UI or logic. Link it as an asset. Use when "how should it look/behave" is the key question.
- **Grilling** (HITL): conversation via the `grilling` and `domain-modeling` skills, one question at a time. The default case.
- **Task** (HITL or AFK): manual work that must happen before a decision can be made — provisioning access, signing up for a service, moving data so its shape can be seen. The one type that *does* rather than decides; it earns its place by unblocking a decision. The resolution records what was done and any resulting facts later tickets depend on.

## Fog of war

The map is deliberately incomplete: don't chart what you can't yet see. Beyond the live tickets lies the **fog of war** — decisions you can tell are coming but can't yet pin down. The map's **Not yet specified** section writes that dim view down, as loosely or fully as the view allows. Resolving a ticket clears the fog ahead of it, **graduating** whatever's now specifiable into fresh tickets.

**Fog or ticket?** The test is whether you can *state the question precisely now* — not whether you can answer it now. Ticket when the question is sharp (even if blocked); fog when you can't phrase it that sharply. Don't pre-slice fog into ticket-sized pieces — one patch may graduate into several tickets, or none.

## Out of scope

Fog only gathers *toward* the destination; work beyond it is **out of scope** and gets the map's **Out of scope** section — a conscious ruling, not a step on the route. When an existing ticket turns out to sit past the destination, **close it** and leave one line in Out of scope: the gist, why it's out, linking the closed ticket. Out-of-scope work never graduates; it returns only if the destination is redrawn, as a fresh effort.

## Invocation

Two modes. Either way, **never resolve more than one ticket per session.**

### Chart the map

Input: a loose idea.

1. **Name the destination.** Run a `grilling` + `domain-modeling` interview to pin down what this map is finding its way to. The destination fixes the scope, so it's settled first.
2. **Map the frontier.** Grill again, **breadth-first**: fan out across the whole space, surfacing the open decisions and the first steps takeable now. If this surfaces no fog, stop — no map needed (see Activation).
3. **Create the map**: Destination and Notes filled in, Decisions-so-far empty, the fog sketched into Not yet specified.
4. **Create the tickets you can specify now**, then wire `blocked-by` edges in a second pass. Everything you can't yet specify stays in the fog.
5. Stop — charting is one session's work; do not also resolve tickets.

### Work through the map

Input: a map (path or URL), optionally a ticket — without one, you pick the next frontier ticket, not the user.

1. Load `map.md` — the low-res view, not every ticket body.
2. Choose the ticket (user's, or the first frontier ticket). **Claim it** before any work.
3. Resolve it — zoom into related or closed tickets on demand; invoke the skills the map's Notes name. If in doubt, use `grilling` and `domain-modeling`.
4. Record the resolution: write the answer in the ticket's Resolution section, set `status: closed`, and append a one-line pointer to the map's Decisions so far.
5. Add newly-surfaced tickets (create, then wire blocking); graduate any fog the answer made specifiable, removing each graduated patch from Not yet specified. If the answer reveals a ticket sits beyond the destination, rule it out of scope rather than resolving it. If the decision invalidates other tickets, update or delete them.

The user may run unblocked tickets in parallel sessions, so expect concurrent edits to the map.

## Handoff

When the fog is pushed back and the way is clear, the map merges onto the main build flow: run `/deep-plan`, which turns the cleared decisions into a ready-for-sdd bundle when the destination is an executable change, or a plan document when it is a decision. To slice the outcome into implementation-ready tickets, use the `buildable-issue` skill. If the effort turned out small, implement directly.

## Attribution

Original skill by Matt Pocock from <https://github.com/mattpocock/skills>.
