---
name: dependency-security-audit
description: >
  Trigger: security audit, dependency audit, CVE scan, vulnerable libraries,
  outdated dependencies, logging posture. Audit dependency vulnerabilities and
  logging/observability posture with read-only commands, degrading to manifest
  inspection when tooling is unavailable.
license: MIT
metadata:
  author: andresnator
  version: "1.0.0"
  status: in-progress
---

# Dependency & Security Audit

## Activation Contract

Use this skill to audit a project's technical security posture: vulnerable dependencies, stale runtimes, committed secrets, and logging/observability health.

Do not use it for penetration testing, exploit work, or code-level secure-coding review of individual classes (`java-secure-coding` covers that per file).

## Hard Rules

- Read-only commands only: audit and dependency-tree listings. Never install tools, never modify manifests or lockfiles, never run fix/upgrade commands.
- Every command-backed result cites the command that produced it.
- When a command is unavailable or denied, degrade to manifest/lockfile inspection and mark the result `method: manifest-fallback` — reduced confidence, never a failure.
- Findings are ranked by severity with CVE/advisory IDs when known; unverifiable versions are flagged as `unknown`, not guessed.

## Audit Checklist

1. **Dependency CVEs**: run the ecosystem audit (`npm audit` / `pnpm audit` / `yarn audit`, `mvn dependency:tree` plus advisory knowledge, `pip-audit`, `osv-scanner`). Fallback: read manifests and lockfiles, flag dependencies with known-vulnerable version ranges.
2. **Freshness and EOL**: flag runtimes past or near end-of-life (Node, Java, Python) and dependencies pinned multiple majors behind. Flag only — no upgrade plan here.
3. **Secrets in repo**: grep heuristics for keys, tokens, passwords, and connection strings; committed `.env` or credential files; `.gitignore` coverage of secret-bearing files.
4. **Logging posture**: load `logging-observability` for the criteria — log levels used sensibly, correlation/trace IDs on request paths, no PII or secrets in log statements, health/readiness endpoints on services.

Per-ecosystem command ↔ fallback pairs live in `references/ecosystem-commands.md`.

## Output Contract

Return a severity-ranked table plus summary:

| Finding | Severity | Evidence | Method | Advisory |
|---|---|---|---|---|

- `Severity`: critical / high / medium / low.
- `Method`: the command used, or `manifest-fallback`.
- `Advisory`: CVE/GHSA ID when known, else `-`.

Close with: audited ecosystems, commands run vs fallbacks used, and explicit out-of-scope notes.

## Verification

- No state-changing command was run or proposed as part of the audit itself.
- Every finding has evidence and a method.
- Fallback results are marked as such.
- Secrets findings quote the location, never the secret value.
