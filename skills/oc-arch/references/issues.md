# Repo Issues

Loaded by `oc-arch`. Triggers: repo issues, project problems, architecture issue shortlist.

## Intent

- **Goal:** Ranked verified architecture issues, each with the smallest proportional guardrail.
- **Limits:** Read-only; no speculative cleanup. Product repos only: AI-harness analysis goes to `oc-absorb`, code-level findings to `oc-plan-deep`.
- **Fails if:** An issue lacks source/config/wiring evidence and consequence; docs prove behavior; preferences, unverified claims, or disproportionate fixes survive; no `Holding up` item.

## Context

- **Reads:** Verified `references/state.md` snapshot traced via imports, manifests, configs, CI wiring, healthy graph (boundaries, edges, operational hazards); `oc-arch` `references/fitness-functions.md`.
- **Never reads:** Docs as behavioral proof.
- **Persona:** Skeptic contrasting claimed versus observed.
- **Scope:** Repo issues, project problems, architecture shortlist; confirm target, snapshot, focus.

## Expectations

- **Scenarios:** WHEN a code-level finding appears THEN reroute it.
- **Done means:** Table (max seven) of `FIX`/`CONDITIONAL` by impact desc, effort asc; then `Holding up`, rerouted items, unknowns, report path.
- **Quality needs:** Prefer no-cycles and allowed-dependencies checks; manual check when automation costs more.

## Method

| Status | Issue | Evidence | Consequence | Impact | Effort | Fitness function |
|---|---|---|---|---|---|---|
