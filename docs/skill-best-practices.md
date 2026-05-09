# Skill Best Practices

Skills are reusable instruction contracts. They teach an agent how to perform a bounded workflow; they should not become a hidden agent, command, or encyclopedia.

## Quick Path

1. Define the trigger and the negative trigger.
2. Keep `SKILL.md` short and executable.
3. Move deep material to `references/` and reusable files to `assets/`.
4. Declare the output contract.
5. Validate behavior with scenarios or golden cases.

## What Belongs Where

| Location | Use for | Avoid |
|---|---|---|
| `SKILL.md` | Activation, hard rules, decision gates, execution steps, output contract | Long catalogs, full tutorials, large examples |
| `references/` | Local docs, extended explanations, decision tables, technique catalogs | Web-only links, templates meant to be copied |
| `assets/` | Templates, schemas, sample files, reusable snippets | Conceptual documentation |
| `scenarios/` | Golden cases and expected behavior | Implementation notes |

## Required Sections

- **Activation Contract**: when to use and when not to use the skill.
- **Responsibility**: what the skill owns and what remains agent/user responsibility.
- **Required Context**: minimum context needed before applying the skill.
- **Hard Rules**: policy or safety rules that must not be violated.
- **Decision Gates**: branches that change the workflow.
- **Execution Steps**: the happy path.
- **Output Contract**: exact format the agent must return.
- **References / Assets**: local supporting material.
- **Validation Scenarios**: happy path, ambiguity, conflict, out-of-scope, and missing context.

## Context Budget

Prefer progressive disclosure: load the smallest useful instruction first, then reference deeper material only when needed. If reading `SKILL.md` forces the agent to absorb a full catalog every time, the skill is too heavy.

## Correct Use of `references/`

Use `references/` for local, stable, human-readable guidance that supports the skill but is not always needed. Good examples:

- technique catalogs
- framework-specific notes
- decision tables
- extended examples
- local architecture or process docs

Do not use `references/` for files the agent should copy verbatim. Those belong in `assets/`.

## Correct Use of `assets/`

Use `assets/` for reusable artifacts:

- Markdown templates
- JSON schemas
- config examples
- prompt/evaluation fixtures
- sample files

If the file is meant to be copied, filled in, or machine-read, it is probably an asset.

## Runtime Coupling

Avoid hardcoding a tool, MCP name, absolute path, or hosted environment unless the skill is explicitly for that runtime. Prefer capability language:

- Instead of: “Call `ask_user_input`.”
- Prefer: “Ask one clarifying question and wait.”

- Instead of: “Write to `/mnt/user-data/outputs/`.”
- Prefer: “Write to the project-approved output directory, or return inline if no output directory is configured.”

This keeps the skill portable across OpenCode, Claude Code, local agents, and future harnesses.

## Evaluation Checklist

- [ ] Trigger is specific enough to avoid accidental loading.
- [ ] Negative trigger exists for common false positives.
- [ ] Skill does not contradict `AGENTS.md` or higher-priority policies.
- [ ] `SKILL.md` stays concise; deep content is referenced.
- [ ] `references/` points to local documentation only.
- [ ] `assets/` contains templates or reusable artifacts, not prose docs.
- [ ] Output contract is explicit.
- [ ] Scenarios cover happy path, ambiguity, conflict, out-of-scope, and missing context.

## Repository Remediation Plan

| Priority | Action | Target |
|---|---|---|
| P0 | Align TCR commit trailer rules with repository policy and global Git identity handling | `skills/tcr/SKILL.md` |
| P0 | Remove the broken `spike-output` reference and replace it with a local findings template | `skills/spike/` |
| P1 | Strengthen the base skill template with context budget, negative triggers, references/assets, and validation | `templates/skill.md` |
| P1 | Add golden scenarios for high-impact skills | `scenarios/` |
| P2 | Replace runtime-specific assumptions with capability-based wording | `skills/rfc/`, `skills/summarize/` |
