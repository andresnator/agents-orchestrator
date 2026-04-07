# Agents Orchestrator

A distribution pack of multi-agent definitions and Claude Code skills for fully automatic **Spec-Driven Development** using [OpenSpec](https://www.npmjs.com/package/@fission-ai/openspec).

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Claude%20Code%20%7C%20OpenCode-8A2BE2)](agents/sdd-agent-pack/)
[![Agents](https://img.shields.io/badge/Agents-6-green)](agents/sdd-agent-pack/)
[![Skills](https://img.shields.io/badge/Skills-9-orange)](skills/)

---

## Highlights

- **6 coordinated agents** that run a full SDD cycle automatically — from spec to squash commit
- **9 standalone skills** for everyday dev tasks (testing, documentation, refactoring, agile)
- **Two platforms**: works with both Claude Code and OpenCode
- **Zero runtime dependencies** — copy Markdown files into your project and go
- **Parallel-safe**: multiple SDD cycles can run concurrently on separate worktrees
- **Built on OpenSpec** for structured, scenario-based specifications (GIVEN/WHEN/THEN)

---

## Table of Contents

- [What's Included](#whats-included)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [How SDD Works](#how-sdd-works)
- [Skills Reference](#skills-reference)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Customization](#customization)
- [Contributing](#contributing)
- [License](#license)

---

## What's Included

### SDD Agent Pack

Six agents that work together to run a complete Spec-Driven Development cycle:

| Agent | Phase | Role |
|-------|:-----:|------|
| `sdd-orchestrator` | All | Master coordinator — delegates, manages git, never writes code |
| `sdd-scanner` | 1 | Read-only codebase and spec analysis |
| `sdd-spec-writer` | 2 | Creates proposal, delta specs, design, and task breakdown |
| `sdd-coder` | 4 | Implements code following specs and design |
| `sdd-test-writer` | 4 | Generates tests from spec scenarios |
| `sdd-verifier` | 5 | Validates code matches specs, runs tests |

All agents use **Opus 4.6** for maximum reasoning quality.

> See the full agent documentation: [`agents/sdd-agent-pack/README.md`](agents/sdd-agent-pack/README.md)

### Skills

Nine Claude Code skills for common development workflows:

| Skill | Category | Description |
|-------|----------|-------------|
| [`adr`](skills/adr/) | Documentation | Generate Architecture Decision Records in Markdown |
| [`rfc`](skills/rfc/) | Documentation | Interactive RFC document generator |
| [`spike`](skills/spike/) | Documentation | Jira Spike ticket generator for investigations |
| [`summarize`](skills/summarize/) | Documentation | Pedagogical book chapter synthesis with Cornell method |
| [`unit-tests`](skills/unit-tests/) | Testing | JUnit 5 + Mockito test generator following project conventions |
| [`test-legacy`](skills/test-legacy/) | Testing | Legacy code testing techniques (Feathers methodology) |
| [`tcr`](skills/tcr/) | Testing | Test && Commit &#124;&#124; Revert for ultra-short safe commits |
| [`refactor-java`](skills/refactor-java/) | Code Quality | 62+ refactoring techniques catalog (Fowler + Refactoring Guru) |
| [`write-ac`](skills/write-ac/) | Agile Workflow | Acceptance criteria in Gherkin format (Given/When/Then) |

---

## Quick Start

```bash
# 1. Install OpenSpec globally
npm install -g @fission-ai/openspec@latest

# 2. Initialize OpenSpec in your target project
cd your-project
openspec init

# 3. Copy agents (Claude Code)
mkdir -p .claude/agents
cp path/to/agents-orchestrator/agents/sdd-agent-pack/claude/*.md .claude/agents/

# 4. Copy skills (optional, Claude Code only)
mkdir -p .claude/skills
cp -r path/to/agents-orchestrator/skills/* .claude/skills/

# 5. Run your first SDD cycle
# In Claude Code:
@sdd-orchestrator Add user authentication with OAuth
```

> For OpenCode, copy from `agents/sdd-agent-pack/opencode/` to `.opencode/agents/` instead.

---

## Project Structure

```
agents-orchestrator/
├── agents/
│   └── sdd-agent-pack/
│       ├── README.md                ← Detailed agent documentation
│       ├── claude/                  ← Claude Code agents (canonical)
│       │   ├── sdd-orchestrator.md
│       │   ├── sdd-scanner.md
│       │   ├── sdd-spec-writer.md
│       │   ├── sdd-coder.md
│       │   ├── sdd-test-writer.md
│       │   └── sdd-verifier.md
│       └── opencode/                ← OpenCode agents (same body, different frontmatter)
│           ├── sdd-orchestrator.md
│           ├── sdd-scanner.md
│           ├── sdd-spec-writer.md
│           ├── sdd-coder.md
│           ├── sdd-test-writer.md
│           └── sdd-verifier.md
├── skills/                          ← Claude Code skills
│   ├── adr/                         ← Architecture Decision Records
│   ├── refactor-java/               ← Refactoring techniques catalog
│   ├── rfc/                         ← RFC document generator
│   ├── spike/                       ← Spike ticket generator
│   ├── summarize/                   ← Book chapter synthesis
│   ├── tcr/                         ← Test && Commit || Revert
│   ├── test-legacy/                 ← Legacy code testing
│   ├── unit-tests/                  ← JUnit 5 + Mockito generator
│   └── write-ac/                    ← Acceptance criteria (Gherkin)
├── CLAUDE.md                        ← Development guidance for this repo
├── LICENSE                          ← MIT
└── README.md                        ← You are here
```

---

## How SDD Works

**Spec-Driven Development** ensures every code change starts with a specification. The orchestrator manages an 8-phase cycle, delegating each phase to the appropriate subagent:

```
Setup → Explore → Propose → Review → Implement → Verify → Archive → Squash Merge
```

- **Fully automatic** — the orchestrator advances through all phases without manual approval; stops only on unresolvable errors
- **Progress tracking** — each cycle writes status to `.sdd-status/<change-name>.md` for live monitoring
- **Parallel-safe** — multiple cycles run on isolated worktrees; the orchestrator detects spec domain overlap and warns
- **Clean output** — every cycle produces one squash commit with all changes and verified spec artifacts

**Platform note**: The Claude Code orchestrator is the canonical, complete version. The OpenCode orchestrator is currently missing Phases 1 (Explore), 3 (Review), 5 (Verify), and 7 (Squash Merge).

> Full phase diagram, conflict handling, monitoring commands, and parallel execution examples: [`agents/sdd-agent-pack/README.md`](agents/sdd-agent-pack/README.md)

---

## Skills Reference

All skills are invoked via slash commands in Claude Code (e.g., `/adr`, `/spike`).

### Documentation

| Command | What it does |
|---------|-------------|
| `/adr` | Generates Architecture Decision Records with status tracking and RACI matrix |
| `/rfc` | Interactive RFC creation with problem statement, proposed solution, and alternatives |
| `/spike` | Creates structured Jira Spike tickets for technical investigations |
| `/summarize` | Synthesizes book chapters using Cornell method, key concepts, and reflection questions |

### Testing

| Command | What it does |
|---------|-------------|
| `/unit-tests` | Generates JUnit 5 + Mockito tests following your project's naming and assertion conventions |
| `/test-legacy` | Applies techniques from "Working Effectively with Legacy Code" (Feathers) to add test coverage |
| `/tcr` | Runs the Test && Commit &#124;&#124; Revert loop for safe micro-refactoring commits |

### Code Quality

| Command | What it does |
|---------|-------------|
| `/refactor-java` | Catalog of 62+ refactoring techniques with code smell diagnostics and step-by-step guides |

### Agile Workflow

| Command | What it does |
|---------|-------------|
| `/write-ac` | Generates acceptance criteria in Gherkin format (Given/When/Then) for Jira tickets |

---

## Prerequisites

| Requirement | Minimum Version | Purpose |
|-------------|:--------------:|---------|
| Node.js | 20.19.0+ | Required by OpenSpec CLI |
| Git | 2.20+ | Worktree support for isolated SDD cycles |
| [OpenSpec](https://www.npmjs.com/package/@fission-ai/openspec) | latest | Spec framework used by all agents |
| Claude Code or OpenCode | latest | Agent execution platform |

---

## Installation

### Installing Agents

#### Claude Code

```bash
# From your project root
mkdir -p .claude/agents
cp path/to/agents-orchestrator/agents/sdd-agent-pack/claude/*.md .claude/agents/

# Add worktree and status directories to .gitignore
echo ".claude/worktrees/" >> .gitignore
echo ".sdd-status/" >> .gitignore

# Initialize OpenSpec (if not already done)
openspec init
```

Verify: run `/agents` in Claude Code — you should see all 6 `sdd-*` agents listed.

#### OpenCode

```bash
mkdir -p .opencode/agents
cp path/to/agents-orchestrator/agents/sdd-agent-pack/opencode/*.md .opencode/agents/

echo ".opencode/worktrees/" >> .gitignore
echo ".sdd-status/" >> .gitignore

openspec init
```

### Installing Skills

Skills are **Claude Code only** and can be installed independently of agents.

```bash
# Install all skills
mkdir -p .claude/skills
cp -r path/to/agents-orchestrator/skills/* .claude/skills/

# Or cherry-pick individual skills
cp -r path/to/agents-orchestrator/skills/unit-tests .claude/skills/
cp -r path/to/agents-orchestrator/skills/refactor-java .claude/skills/
```

Verify: run `/skills` in Claude Code to see installed skills.

---

## Customization

- **Change the model**: edit the `model:` field in each agent's YAML frontmatter
- **Cherry-pick skills**: copy only the skill directories you need
- **Add new agents**: create `.md` files in `.claude/agents/` and reference them from the orchestrator via Task
- **Keep variants in sync**: the Claude Code version is canonical — edit it first, then copy the instruction body (below the frontmatter `---`) to the OpenCode variant, preserving each platform's frontmatter

---

## Contributing

Contributions are welcome. When submitting changes:

1. **Agent logic**: edit the Claude Code version first, then sync the instruction body to the OpenCode variant
2. **New skills**: follow the `SKILL.md` convention (see any existing skill as a template)
3. **Keep it Markdown**: this repo has no build system, no tests, no runtime code — keep it that way

Open an issue or pull request on GitHub.

---

## License

[MIT](LICENSE) &copy; 2026 Jose Andres Gonzalez Guevara
