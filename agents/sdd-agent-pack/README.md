# SDD Agent Pack — Fully Automatic Spec-Driven Development

A complete multi-agent system for **Spec-Driven Development** using **OpenSpec**.
Works with **OpenCode**.

---

## What's Inside

```
agents-orchestrator/
├── agents/
│   └── sdd-agent-pack/
│       └── opencode/                ← Copy contents to .opencode/agents/
│           ├── sdd-orchestrator.md
│           ├── sdd-scanner.md
│           ├── sdd-spec-writer.md
│           ├── sdd-coder.md
│           ├── sdd-test-writer.md
│           └── sdd-verifier.md
│
├── skills/                  ← Claude Code skills (copy to .claude/skills/)
│
├── README.md                ← This file
└── LICENSE
```

## How It Works

```
@sdd-orchestrator Add user authentication with OAuth

  Phase 0: SETUP
  ├─ Creates worktree: sdd/add-user-auth
  ├─ Creates .sdd-status/add-user-auth.md
  │
  Phase 1: EXPLORE
  ├─ Delegates to → sdd-scanner
  │  Scans codebase, specs, parallel work
  │  Returns: structured analysis report
  │
  Phase 2: PROPOSE
  ├─ Delegates to → sdd-spec-writer
  │  Creates proposal.md, delta specs, design.md, tasks.md
  │  Returns: creation summary
  │
  Phase 3: REVIEW
  ├─ Orchestrator verifies artifact consistency
  │
  Phase 4: IMPLEMENT
  ├─ Delegates to → sdd-coder (per task phase)
  │  Implements code following specs and design
  ├─ Delegates to → sdd-test-writer
  │  Generates tests from spec scenarios
  │
  Phase 5: VERIFY
  ├─ Delegates to → sdd-verifier
  │  Compares every scenario vs code, runs tests
  │
  Phase 6: ARCHIVE
  ├─ Orchestrator merges deltas into specs/
  │
  Phase 7: MERGE
  ├─ git merge --no-ff → origin branch
  ├─ Merge commit preserving full history
  └─ Cleanup: removes worktree + branch + status
```

**All fully automatic.** The orchestrator only stops on unresolvable errors.

---

## Prerequisites

```bash
# Node.js 20.19.0+
node --version

# Git 2.20+
git --version

# OpenSpec
npm install -g @fission-ai/openspec@latest

# Initialize OpenSpec in your project
cd your-project
openspec init
```

---

## Installation

### OpenCode

```bash
# From your project root:
mkdir -p .opencode/agents
cp agents-orchestrator/agents/sdd-agent-pack/opencode/*.md .opencode/agents/

# Add to .gitignore
echo ".opencode/worktrees/" >> .gitignore
echo ".sdd-status/" >> .gitignore
```

---

## Usage

### Start an SDD cycle

```bash
# Claude Code
@sdd-orchestrator Add dark mode theme support

# Or start a session as the orchestrator
claude --agent sdd-orchestrator
> Add dark mode theme support

# OpenCode
@sdd-orchestrator Add dark mode theme support
```

The orchestrator runs the entire cycle automatically.

### Monitor progress

```bash
# From any terminal
cat .sdd-status/add-dark-mode.md

# Live monitoring
watch -n 5 cat .sdd-status/add-dark-mode.md

# All active cycles
watch -n 5 'for f in .sdd-status/*.md; do echo "═══"; cat "$f"; done'

# From the main Claude/OpenCode session
> Read .sdd-status/ and summarize all active SDD cycles
```

### Progress file example

```markdown
# SDD: add-dark-mode
**Updated**: 2026-04-07 14:32:15
**Phase**: 4 - Implement
**Branch**: sdd/add-dark-mode
**Mode**: Automatic

## Progress
| # | Task | Status |
|---|------|--------|
| 1.1 | Add theme context provider | ✅ Done |
| 1.2 | Create toggle component | ✅ Done |
| 2.1 | Add CSS variables | 🔄 In progress |
| 2.2 | Wire up localStorage | ⏳ Pending |
| 3.1 | Add theme tests | ⏳ Pending |

## Summary
- **Completed**: 2/5 tasks
- **Current**: 2.1 - Adding CSS variables
- **Subagent**: sdd-coder (Phase 2)
- **Errors**: none

## Spec Domains
- specs/ui/
```

### Run multiple cycles in parallel

```bash
# Terminal 1
@sdd-orchestrator Add OAuth login        # → specs/auth/

# Terminal 2 (or Ctrl+B to background)
@sdd-orchestrator Add dark mode          # → specs/ui/

# Terminal 3
@sdd-orchestrator Add notifications     # → specs/notifications/

# Monitor all from terminal 4
watch -n 5 'for f in .sdd-status/*.md; do echo "═══"; cat "$f"; done'
```

The orchestrator detects parallel cycles and warns if they touch the same spec domain.

---

## Conflict Handling

### At merge time:

| Conflict type | Action |
|---------------|--------|
| **No conflicts** | Commits and cleans up |
| **Code only** | Resolves, runs tests, retries if needed |
| **Specs affected** | Resolves text, re-runs verifier, stops if incompatible |

If spec conflicts are unresolvable, the orchestrator stops and writes the error to
`.sdd-status/<change-name>.md` for you to review.

---

## Agent Roles

| Agent | Phase | Role | Writes Code? |
|-------|-------|------|:---:|
| `sdd-orchestrator` | All | Coordinates, delegates, manages git | No |
| `sdd-scanner` | 1 | Analyzes codebase and specs | No |
| `sdd-spec-writer` | 2 | Creates proposals and spec deltas | Specs only |
| `sdd-coder` | 4 | Implements features following specs | Yes |
| `sdd-test-writer` | 4 | Generates tests from spec scenarios | Tests only |
| `sdd-verifier` | 5 | Verifies code matches specs | No |

Orchestrator, scanner, and spec-writer use **Opus 4.6** for maximum reasoning quality. Coder, test-writer, and verifier use **Sonnet 4.6** for fast execution.

---

## Git Result

Each SDD cycle produces **a merge commit preserving full commit history** on your branch:

```
a1b2c3d feat(add-oauth): Add OAuth authentication

         Spec-Driven Development cycle completed.

         Changes:
         - Added: OAuth config, social login, token exchange
         - Modified: Session creation, login flow
         Artifacts: archived. All scenarios verified and passing.
```

---

## Customization

### Change the model
Edit the `model:` field in each agent's frontmatter.

### Reduce automation
Change the orchestrator to semi-auto by adding approval gates
(see previous versions of this agent).

### Add more subagents
Create new `.md` files in `.claude/agents/` or `.opencode/agents/`
and reference them from the orchestrator via Task.

---

> Inspired by the agent orchestration patterns from [Gentleman Programming](https://github.com/Gentleman-Programming).
