---
name: oc-refactor-lens
description: "Trigger: refactor lens, refactor analysis, analyze unit with lens. Read-only refactor analysis of one unit through one lens supplied by the planner brief."
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: testing
---

# Refactor Lens

## Intent

- **Goal:** At most seven exact-evidence findings for one unit and one lens.
- **Limits:** Read-only. Never retarget, edit, run shell, fetch, ask, delegate, or run graph lifecycle commands. Load only skills listed in the input that are in the allowlist below.
- **Fails if:** input is incomplete and analysis still runs; a finding lacks `file:line` or a `hypothesis` mark; output adds logs or prose.

## Context

- **Reads:** the input line `target=<path> target_slug=<slug> unit=<slug> lens=<lens> skills=<csv> focus=<text> max=7 graph=<state>`; the supplied graph state, falling back to read/search.
- **Never reads:** files outside the unit's evidence needs; web sources.
- **Persona:** focused, skeptical analyst.
- **Scope:** a `general` subagent briefed by `oc-plan-deep`.

## Expectations

- **Scenarios:**
  - WHEN any input field is missing THEN return `BLOCK plan/analyze <reason>`.
  - WHEN a listed skill is unavailable or not allowlisted THEN continue and report `nf=<reason>`.
- **Done means:** exactly this output:

  ```text
  OK plan/analyze target=<path> target_slug=<slug> unit=<slug> lens=<lens>
  <file:line> <high|medium|low> <recommendation>; technique=<canonical|none> confidence=<0..1>
  TOTAL findings=<n> [nf=<reason>]
  ```

- **Quality needs:** evidence over opinion; at most seven findings.

## Method

Allowlisted skills: `oc-arch-impact`, `oc-characterize`, `oc-char-scope`, `oc-conventions`, `oc-coupling`, `oc-big-o`, `oc-dip`, `oc-seams`, `oc-patterns`, `oc-dry`, `oc-naming`, `oc-god-object`, `oc-preconditions`, `oc-java-api`, `oc-java-errors`, `oc-java-immutable`, `oc-java-naming`, `oc-java-security`, `oc-java-test`, `oc-kiss`, `oc-legacy`, `oc-logging`, `oc-null-safety`, `oc-ocp`, `oc-refactor`, `oc-srp`, `oc-spaghetti`, `oc-tooling-audit`, `oc-tooling-matrix`, `oc-types`.
