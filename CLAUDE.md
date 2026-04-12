# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A distribution pack of **6 multi-agent definitions** for fully automatic Spec-Driven Development (SDD) using OpenSpec. No build system, no tests, no runtime code — only Markdown agent definition files. Licensed MIT.

Agent definitions live in `agents/sdd-agent-pack/opencode/` with OpenCode frontmatter (`description`, `mode`, `permission`).

**Usage in target projects**: copy agent files to `.opencode/agents/`, then invoke with `@sdd-orchestrator <request>`. Target projects must have OpenSpec initialized (`npm install -g @fission-ai/openspec@latest && openspec init`).

## Agent Architecture

The orchestrator delegates phases to specialized subagents via Task tool. No agent implements outside its role.

```
sdd-orchestrator (coordinator, no code)
  ├─ Phase 0: Setup        — orchestrator handles (worktree, git)
  ├─ Phase 1: Explore      → sdd-scanner (read-only codebase analysis)
  ├─ Phase 2: Propose      → sdd-spec-writer (creates proposal, delta specs, design, tasks)
  ├─ Phase 3: Review       — orchestrator handles (artifact consistency check)
  ├─ Phase 4: Implement    → sdd-coder (per task phase) + sdd-test-writer
  ├─ Phase 5: Verify       → sdd-verifier (code vs spec comparison)
  ├─ Phase 6: Archive      — orchestrator handles (merge deltas into specs/)
  └─ Phase 7: Merge — orchestrator handles (merge to origin preserving history)
```

Agent permissions by role:
| Agent | Writes code? | Writes specs? | Read-only? |
|-------|:---:|:---:|:---:|
| orchestrator | No | No (minor fixes only) | No — manages git |
| scanner | No | No | Yes |
| spec-writer | No | Yes | No |
| coder | Yes | Updates if divergence | No |
| test-writer | Tests only | No | No |
| verifier | No | No | Yes |

## Key Conventions

- **OpenSpec** (`openspec/` dir in target projects) is the spec framework. Changes live in `openspec/changes/<change-name>/` with: `proposal.md`, `specs/<domain>/spec.md` (delta format), `design.md`, `tasks.md`.
- **Delta spec format** uses `## ADDED Requirements`, `## MODIFIED Requirements`, `## REMOVED Requirements` sections. Every requirement must have at least one `#### Scenario:` with GIVEN/WHEN/THEN.
- **Git commit prefixes**: `spec(name):` for spec phases, `feat(name):` for implementation, `test(name):` for tests.
- **Progress tracking**: `.sdd-status/<change-name>.md` in the origin directory, updated after every phase transition.
- **Worktrees**: SDD cycles run in isolated git worktrees at `.claude/worktrees/sdd-<name>` (Claude Code) or `.opencode/worktrees/` (OpenCode).
- Orchestrator, scanner, and spec-writer use **claude-opus-4-6**. Coder, test-writer, and verifier use **claude-sonnet-4-6**.

## Parallel Safety

Multiple SDD cycles can run concurrently. The orchestrator enforces:
1. Each cycle checks `.sdd-status/` for active cycles at Phase 0
2. Warns if two cycles touch the same spec domain
3. First to finish merges first; second must pull + rebase before merge
4. Spec conflicts at merge time trigger mandatory re-verification or halt

## Editing Agents

Agent definitions use **OpenCode** frontmatter (`agents/sdd-agent-pack/opencode/*.md`):
```yaml
description: ...
mode: primary | subagent
permission:
  edit: allow | deny
  bash: allow | ask
  webfetch: allow | deny
```

## Known Gap

The OpenCode orchestrator (`agents/sdd-agent-pack/opencode/sdd-orchestrator.md`) is currently missing Phases 1 (Explore), 3 (Review), and 5 (Verify).
