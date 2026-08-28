# AGENTS.md

This repository stores reusable OpenCode agent artifacts, not application code. Keep changes compact, contract-focused, and organized by domain. Start with [README.md](README.md), then read the README for the domain you change.

## Repository contract

- Write documentation, descriptions, prompts, and comments in English.
- Preserve literal runtime triggers such as `"ejecuta el plan <change>"` and Spanish skill triggers. They are activation contracts, not prose to translate.
- `domains/` owns agents, commands, repository plugins, external-plugin locks, and skills used by one domain.
- `skills/` owns only skill bodies shared by multiple domains.
- `global/AGENTS.md` is the installable runtime rules file. Root `AGENTS.md` is maintainer guidance; do not merge their roles.
- `installers/opencode.sh` discovers and installs components. Adding a component must not require installer edits.
- `.ai/` and other runtime-state directories are ignored state, not repository artifacts.
- `CLAUDE.md` must remain a symlink to this file.

## Agents and commands

Store fused OpenCode files at `domains/<domain>/agents/<name>.md` and `domains/<domain>/commands/<name>.md`. Names must be globally unique within their type.

Agent frontmatter order:

```text
description, mode, temperature?, permission, tools?, disable?
```

Command frontmatter order:

```text
description, agent?, model?, subtask?, argument-hint?
```

Do not add `name`, `prompt`, `license`, or `metadata` to agent or command frontmatter. Agent `mode` is `primary` or `subagent`. Do not hardcode agent models or provider options; users configure those in OpenCode.

Keep prompts short: role, accepted operation, ownership and safety boundaries, happy path, real stop conditions, artifact paths, and compact return contract. Put fork attribution outside executable frontmatter.

Open-ended interviews, debriefs, teach-backs, and other free-text questions use normal chat: ask one direct question, add `Recommendation: ...` only when useful, then wait. Do not require question headings, numbering, rationale blocks, or interview-length estimates. Reserve the `question` tool for closed choices such as confirmations, modes, ratings, and enumerated options.

## Skills

Each skill has exactly one body. A skill used by one domain lives directly at `domains/<domain>/skills/<skill>/SKILL.md`. A skill used by multiple domains lives at `skills/<skill>/SKILL.md`, and every owning domain declares it with a relative `domains/<domain>/skills/<skill>` symlink. Do not copy skill bodies or keep an exclusive skill at the top level.

Skill frontmatter contains `name`, `description`, `license`, and `metadata.author`, strict SemVer `metadata.version`, and `metadata.status`. Status is `backlog`, `in-progress`, `testing`, or `done`.

Bump the version whenever a skill changes: patch for wording or internal fixes, minor for additive capability, major for breaking activation or output behavior. Keep the runtime contract concise; place concrete templates in `assets/` and extended guidance in `references/`.

## Keeping the catalog accurate

Every domain README uses this H2 sequence: `## Quick path`, `## Entry points`, then `## Components`. Keep the introduction to at most two sentences, the quick path to two or three steps, entry points compact, and component purposes to 3-8 words. `## Components` is the final authoritative section; do not add Mermaid diagrams to domain READMEs.

When adding, removing, or moving a component, update the owning domain README's single `## Components` table. Update the root domain table only when entry points or domain purpose change. For GitHub-bundled external plugins, update the version, commit, artifact, and SHA-256 lock together. For npm plugins, keep the package, exact version pin, and runtime target aligned.

## Validation

Run the narrowest relevant check, then the structural harness:

```bash
installers/opencode.sh install --dry-run
scripts/validate-harness.sh
```

Use the touched script's syntax/test command for executable changes. External-plugin changes use `scripts/test-external-plugin-install.sh contracts`; remote lock verification is opt-in. Model-backed orchestration flows spend credits and run only when explicitly authorized; see [docs/orchestration-test-plan.md](docs/orchestration-test-plan.md).

Do not commit unless explicitly asked.
