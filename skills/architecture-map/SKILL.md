---
name: architecture-map
description: >
  Trigger: architecture map, C4 diagram, container diagram, flow map, visual
  architecture docs, architecture drift refresh. Generate compact C4-lite
  Mermaid architecture docs from code evidence and refresh them on re-run.
license: MIT
metadata:
  author: andresnator
  version: "1.1.0"
  status: in-progress
---

# Architecture Map

## Activation Contract

Use this skill when the user wants visual architecture documentation for a project: system context, containers, and key runtime flows.

Do not use it for code-level design review, user story mapping (`usm`), or AI-harness analysis (`absorb`).

## Hard Rules

- C4-lite: System Context (level 1) and Container (level 2) only. Component-level diagrams only on explicit request.
- Every node and edge comes from code evidence: manifests, build files, configs, routes, entrypoints, deployment descriptors. Never from README claims. Unverifiable elements are marked `hypothesis`.
- Derive containers, dependencies, and flows from imports, configs, deployment descriptors, or a code-graph index (for example, CodeGraph MCP/CLI) when available, before file-by-file search; a graph-resolved edge still cites the underlying `file:line`.
- Budgets: at most ~30 nodes per diagram and ~120 lines per doc. Split flows into more diagrams before exceeding a budget.
- Mermaid only (`flowchart`, `sequenceDiagram`), GitHub-renderable. No external image tooling.
- Visual first: diagrams carry the weight; prose is one short paragraph per diagram.

## Doc Folder Rule

Write under `<docfolder>/architecture/`, where `<docfolder>` is the project's existing `docs/`, else its existing `doc/`, else a newly created `doc/`.

## Doc Set

Three files; concrete skeletons live in `assets/architecture-doc-set.md`:

- `index.md`: ~10 lines — what each doc answers, generation date, source commit.
- `overview.md`: system context diagram + container diagram, each followed by a one-paragraph narrative.
- `flows.md`: 1-3 `sequenceDiagram`s showing how a representative request or event flows end to end, chosen for onboarding value.

## Multi-Deployable Workspaces

When the state scan reports multiple deployable projects, the level-2 diagram shows one container (or one subgraph) per deployable. When that would break the node budget, keep `overview.md` at workspace level (one node per project) and add `projects/<name>.md` pages under the same `architecture/` folder — one container diagram per project — linked from `index.md`. Cross-project edges carry only manifest/config evidence (URLs, topics, shared schemas); a per-project code graph never proves a cross-project edge.

## Drift Refresh

When the doc set already exists, re-running is a refresh, not a rewrite:

1. Regenerate the doc set from current code evidence.
2. Diff against the existing docs: added/removed containers, changed dependencies, changed flows.
3. Update files in place and report a short drift summary against the recorded source commit; leave unchanged docs untouched.

## Verification

- Every diagram element has evidence or a `hypothesis` mark.
- Budgets respected; Mermaid blocks are balanced and syntactically valid.
- `index.md`, `overview.md`, and `flows.md` exist and cross-link.
- Source commit is recorded in `index.md`.

## Output Contract

Return: the docfolder used, files written or updated, a drift summary (or "initial generation"), and any evidence gaps marked as hypotheses.
