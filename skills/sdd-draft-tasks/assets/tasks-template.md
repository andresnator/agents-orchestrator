# Tasks: {title}

## Review Workload Forecast

| Field | Value |
| --- | --- |
| Estimated changed lines | {n} |
| Suggested split | {none | chained PRs description} |

Decision needed before apply: {Yes|No}
Chained PRs recommended: {Yes|No}
Chain strategy: {stacked-to-main|feature-branch-chain|size-exception|pending}
400-line budget risk: {Low|Medium|High}
Shared hotspots: {none | lockfiles, barrel/index files, registries, generated paths…}

## 1. {Group name — e.g. Foundation}

Files: {directories or globs this group touches}
Depends on: none

- [ ] 1.1 {Concrete action — file(s), change}
- [ ] 1.2 {Concrete action depending on 1.1}

## 2. {Group name — e.g. Core}

Files: {directories or globs this group touches}
Depends on: {none | earlier group numbers, e.g. 1}

- [ ] 2.1 {Concrete action}
- [ ] 2.2 {Concrete action}

## 3. {Group name — e.g. Integration & Tests}

Files: {directories or globs this group touches}
Depends on: {none | earlier group numbers, e.g. 1, 2}

- [ ] 3.1 {Wiring or test task; reference the spec scenario it proves}

<!-- Keep under 650 words. Every task line is `- [ ] X.Y ...`, ordered so a task only depends on earlier ones. Preserve the five forecast guard lines verbatim. Every group carries `Files:` and `Depends on:` lines; scopes are scheduling predictions, not enforcement. Execution scheduling (batching/parallelism/worktrees) is the downstream apply agent's job: only dependency-ready groups with explicit dependencies, disjoint scopes, and no shared hotspot may run in parallel. A missing dependency or scope line means serialize. -->
