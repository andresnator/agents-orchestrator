# Architecture Map

Loaded by `oc-arch`. Triggers: architecture map, C4 diagram, container diagram, flow map, architecture docs, architecture drift.

## Intent

- **Goal:** Evidence-backed C4-lite docs: context, containers, key runtime flows.
- **Limits:** No code-level design, story mapping, or AI-harness analysis. Never remove manually owned files.
- **Fails if:** A node/edge lacks evidence and no `hypothesis` mark; a diagram exceeds ~30 nodes or a file 120 lines; Mermaid unbalanced; split files lack cross-links.

## Context

- **Reads:** Manifests, configs, imports, entrypoints, deployment descriptors, `file:line` via healthy graph.
- **Never reads:** Per-project graph as proof of cross-project edges (need manifest, config, deployment, topic, URL, or shared-schema evidence).
- **Persona:** Evidence-first documentarian.
- **Scope:** Architecture map, C4/container diagram, flow map, architecture docs, drift.

## Expectations

- **Scenarios:**
  - WHEN `docs/` exists THEN write `docs/architecture/`; else existing `doc/architecture/`, or create it.
  - WHEN refreshing THEN regenerate, diff against recorded source commit, update changed files only, report added/removed containers, dependency and flow changes.
- **Done means:** Return folder, files written or updated, `initial generation` or drift summary, hypotheses; source commit recorded.
- **Quality needs:** GitHub-renderable Mermaid `flowchart`/`sequenceDiagram` only.

## Method

Default one `index.md` from the skeleton in `oc-arch` `assets/architecture-doc-set.md`: context, containers, 1-3 flows. Over budget: context and containers to `overview.md`, flows to `flows.md`. Multiple deployables: workspace context in `index.md`; `projects/<name>.md` only when one diagram exceeds budget.
