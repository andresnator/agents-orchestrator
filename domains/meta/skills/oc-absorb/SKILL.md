---
name: oc-absorb
description: >
  Analyze one or more external projects (git URL or local path) to extract
  AI-harness practices, agent patterns, or instruction logic and contrast them
  against this repository's harness. Not for application code review.
license: MIT
metadata:
  author: abdi
  adapted_by: andresnator
  source: user-provided absorb draft
  version: "2.1.0"
  status: testing
---

# Absorb

## Intent

- **Goal:** Produce a verified, contrasted adoption shortlist of external AI-harness practices for this repository.
- **Limits:**
  - Analyze harness and agent configuration, not the external project's business code quality.
  - Clone or update a git URL only with user awareness and to a clearly stated local destination.
  - Never auto-adopt, auto-commit, or silently edit this repository as a result of the audit.
- **Fails if:**
  - A README claim is promoted as proven behavior without source, activation-point, or wiring evidence.
  - A practice is recommended without contrast against this repository.
  - Findings are fabricated when a red flag applies: the path does not exist, the user wants general code review, no AI-config surface exists, or practices are documented but not wired. Surface these explicitly.

## Context

- **Reads:**
  - Targets: git URL(s) and/or local path(s); optional focus (skills, agents, prompts, workflows, installer patterns, comparison themes). Ask for a valid target when none is given.
  - External AI entrypoints: `AGENTS.md`, `CLAUDE.md`, command, agent, and skill folders, config files, prompt files, AI plugins. A repo is a valid harness even without `AGENTS.md`, `agents/`, or `skills/`; its AI surface may live in plugins, runtime config handlers, and maintenance scripts.
  - Repo-native contrast: `AGENTS.md`, `.ai/atl/skill-registry.md`, `domains/*/README.md`, `domains/*/skills/*/SKILL.md`, `skills/*/SKILL.md`, relevant local artifacts.
- **Never reads:** memory as a substitute for source evidence; delegate read-heavy discovery to subagents or researcher passes when available.
- **Persona:** skeptical harness auditor that avoids cargo-cult adoption.
- **Scope:** the user wants to learn from an external repository's or local project's AI-harness setup: agents, skills, prompts, orchestration rules, or instruction patterns. Not for application code review, bug hunting, product architecture review, or test-quality audits.

## Expectations

- **Scenarios:**
  - WHEN targets are given THEN they are resolved (local paths verified) and the list confirmed before deep analysis.
  - WHEN this repository already covers a practice well THEN it is marked `no adoption needed`.
  - WHEN the user explicitly asks not to persist THEN the file is skipped and the same structure returns as a concise chat summary.
- **Done means:** the report exists at `.ai/absorb/YYYY-MM-DD-<slug>.md` (`<slug>` is short kebab-case focus or target; fallback `external-practices`; create `.ai/absorb/` if missing), unless chat-only was requested. Return: resolved targets; key verified practices; rejected or conditional practices with reasons; our advantages; shortlist with proposed target paths in this repository; report path (always, unless the user opted out of persistence).
- **Quality needs:** each recommended practice has file-level evidence; at least one `no adoption needed` or `Our Advantages` item; no unverified README-only claims in the shortlist; no commit or automatic adoption.

## Method

1. **Map each harness.** Record how each candidate practice is triggered or wired, and per practice:

   | Field | What to record |
   | --- | --- |
   | Practice | Clear name |
   | Mechanism | File path and concrete evidence |
   | Status | Verified / partial / aspirational |
   | Strength | Why it helps |
   | Weakness | Limitation or trade-off |

2. **Contrast.** Carry forward only genuinely better or meaningfully missing practices. Record at least three **Our Advantages** points.
3. **Adversarial filter.** Is it truly verified? Better, or just different? Does it fit this repo's OpenCode-only, compact, contract-focused conventions? Is adoption cost proportional to benefit? Keep only `ADOPT` or `CONDITIONAL` items.
4. **Report sections:** sources analyzed; one section per external project; verified strengths; Our Advantages; ranked adoption shortlist with target file paths in this repository; immediate text-only wins vs. larger follow-up work.

## Attribution

Created by abdi. Adapted for this repository by andresnator.
