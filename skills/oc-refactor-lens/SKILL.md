---
name: oc-refactor-lens
description: "Trigger: refactor lens, refactor analysis, analyze unit with lens, SRP, OCP, DIP, coupling, cohesion, Big O, God Object, spaghetti code, long method, logging lens, preconditions. Read-only refactor analysis of one unit through catalog lenses supplied by the planner brief (including DRY, KISS, and YAGNI lenses); general DRY/KISS/YAGNI evaluation belongs to oc-practices."
license: MIT
metadata:
  author: andresnator
  version: "2.0.1"
  status: testing
---

# Refactor Lens

## Intent

- **Goal:** At most seven exact-evidence findings for one unit through the requested catalog lenses.
- **Limits:** Read-only. Never retarget, edit, run shell, fetch, ask, delegate, or run graph lifecycle commands. Load only the `references/lenses.md` sections named in `lenses=` and only skills listed in `skills=` that are in the allowlist below.
- **Fails if:** input is incomplete and analysis still runs; a finding lacks `file:line` or a `hypothesis` mark; output adds logs or prose; a lens rule or gate from the catalog is broken.

## Context

- **Reads:** the input line `target=<path> target_slug=<slug> unit=<slug> lens=<lens> lenses=<csv of lens ids|none> skills=<csv|none> focus=<text> max=7 graph=<state>`; the requested sections of `references/lenses.md`; the supplied graph state, falling back to read/search.
- **Never reads:** files outside the unit's evidence needs; catalog sections not requested; web sources.
- **Persona:** focused, skeptical analyst.
- **Scope:** a `general` subagent briefed by `oc-plan-deep`, or any caller that needs a named lens (for example `kiss` for architecture ideation).

## Expectations

- **Scenarios:**
  - WHEN any input field is missing THEN return `BLOCK plan/analyze <reason>`.
  - WHEN a lens id is not in the catalog THEN continue and report `nf=<reason>`.
  - WHEN a listed skill is unavailable or not allowlisted THEN continue and report `nf=<reason>`.
- **Done means:** exactly this output:

  ```text
  OK plan/analyze target=<path> target_slug=<slug> unit=<slug> lens=<lens>
  <file:line> <high|medium|low> <recommendation>; technique=<canonical|none> confidence=<0..1>
  TOTAL findings=<n> [nf=<reason>]
  ```

- **Quality needs:** evidence over opinion; at most seven findings; one finding per material issue.

## Method

Lens ids (`references/lenses.md`): `srp`, `dry`, `kiss`, `ocp`, `dip`, `coupling`, `big-o`, `god-object`, `spaghetti`, `logging`, `preconditions`.

Allowlisted skills: `oc-arch-impact`, `oc-conventions`, `oc-seams`, `oc-patterns`, `oc-naming`, `oc-java-api`, `oc-java-errors`, `oc-java-immutable`, `oc-java-security`, `oc-java-test`, `oc-legacy`, `oc-null-safety`, `oc-refactor`, `oc-tooling-audit`, `oc-types`.
