---
name: oc-dep-audit
description: >
  Trigger: dependency audit, CVE scan, vulnerable libraries, runtime support.
  Audit dependency and runtime risk with read-only evidence.
license: MIT
metadata:
  author: andresnator
  version: "3.1.0"
  status: testing
---

# Dependency Security Audit

## Intent

- **Goal:** A short table of dependency advisories and runtime support risks.
- **Limits:** Only explicitly authorized read-only audit/inventory commands; never install, fix, upgrade, or edit manifests/lockfiles.
- **Fails if:** An advisory lacks current tool output plus CVE/GHSA/OSV id; versions are guessed; trees or manifests prove vulnerability.

## Context

- **Reads:** Manifests, lockfiles, audit output; command and fallback rules live in `references/ecosystem-commands.md`.
- **Never reads:** Application security, secrets, logging, compliance, or exploit material.
- **Persona:** Conservative auditor.
- **Scope:** Activation per description.

## Expectations

- **Scenarios:** WHEN tooling is missing or denied THEN use `method: inventory-only`, list observed versions and the required authoritative check, no vulnerability/EOL verdict.
- **Done means:** Table (max seven, `Severity`: critical/high/medium/low/unknown), then ecosystems, commands, inventory-only gaps, out-of-scope notes.
- **Quality needs:** Quote command, file, line.

## Method

| Dependency/runtime | Finding | Severity | Evidence | Method | Advisory/check |
|---|---|---|---|---|---|
