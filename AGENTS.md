# Agent Contributor Guide

This file provides guidance to AI coding assistants when working in this repository. `CLAUDE.md` is intentionally kept as a symlink to this file so Claude Code and other agents share the same source of truth.

## What This Repo Is

This repo is a **personal AI agent harness**: a place to design, organize, validate, and reuse agents, subagents, skills, commands, recipes, scenarios, and templates for day-to-day software work.

It has no runtime application, build system, or test framework. Most validation is documentation review plus scenario/golden-case checks.

## Project Structure

| Directory | Purpose |
|---|---|
| `agents/primary/` | Coordinating agents that own multi-step workflows |
| `agents/subagents/` | Focused specialist agents with narrow boundaries |
| `skills/` | Reusable instruction contracts |
| `commands/` | Fast invocation wrappers for repeated workflows |
| `recipes/` | Playbooks combining agents, skills, commands, and human judgment |
| `scenarios/` | Golden-case validations |
| `templates/` | Starter templates for new harness pieces |
| `docs/` | Deeper architecture and conventions |

## Design Rules

- Do not add prompt dumps. Every tool needs a clear job, boundaries, and expected output.
- Prefer small composable pieces over one large do-everything agent.
- A skill explains how to do something; an agent decides when and whether to use it.
- When modifying a skill, update its `metadata.version` according to SemVer.
- Commands are only for workflows used often enough to deserve a shortcut.
- Scenarios are the default validation strategy for prompt-only behavior.
- Keep READMEs updated when adding, moving, or removing tools (ALL READMEs).
- Keep the root README's “Recommended entry points” section curated and minimal; do not add every new tool, only broadly useful entry points.

## Agent Rules

| Agent type | Directory | Rule |
|---|---|---|
| Primary agent | `agents/primary/` | Coordinates phases, subagents, or tools |
| Subagent | `agents/subagents/` | Performs one bounded specialist task |

Every agent should state:

- responsibility
- permissions and forbidden actions
- related skills, if any
- input shape
- output contract

## Prompt Evaluator Validation

Because this repo has no runtime test framework, validate `prompt-evaluator` with scenario/golden cases rather than unit tests:

- clear prompt → verdict `READY`, minor polish only
- vague prompt → verdict `NEEDS_REFINEMENT`, detects missing goal/context/output
- conflicting constraints → verdict `MAJOR_REWRITE`, identifies the conflict
- execution trap → evaluates only and does not perform the requested task
- missing critical context → asks at most one question and still provides best-effort rewrite
- tool/MCP request → treats tool usage as out of scope and does not call tools

## Editing Guidance

- Use `apply_patch` or file-edit tools for Markdown changes.
- After every change, check whether documentation should be updated. Keep updates as concise as possible and only document what future agents need to understand the change.
- Do not commit unless the user explicitly asks.
- Do not build; there is no build step for this repo.
- Before committing, inspect unrelated working-tree changes and keep them out unless requested.
