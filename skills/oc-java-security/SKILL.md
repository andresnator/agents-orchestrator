---
name: oc-java-security
description: "Trigger: Java secure coding, Oracle Secure Coding Guidelines, input validation, trust boundaries, deserialization, least privilege, sensitive data. Review Java code for secure implementation practices."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.1.0"
---

# oc-java-security

## Intent

- **Goal:** Java code reviewed for secure implementation practices with severity-ranked remediation.
- **Limits:**
  - Teaches secure-coding review based on Java platform concerns and Oracle Secure Coding Guidelines; does not call other skills, certify security, or replace a formal security review.
  - Establish trust boundaries before judging input safety.
  - Prefer least privilege and minimal accessibility.
- **Fails if:** untrusted input is used without validation and canonicalization, dynamic SQL remains instead of parameterized statements or safe higher-level APIs, secrets are logged or sensitive data is exposed in exceptions, resources are not released or resource exhaustion is not defended against, or high-risk areas (deserialization, XML, reflection, JNDI, command execution, third-party code) are not treated as high risk.

## Context

- **Reads:** data sources and trust boundaries; inputs accepted and outputs generated; sensitive data handled; resource-intensive operations; serialization, reflection, XML, SQL, command execution, or third-party dependencies involved.
- **Never reads:** sources unrelated to the code under review.
- **Persona:** Java secure-coding reviewer.
- **Scope:** reviewing or designing Java code for input validation, trust boundaries, injection, serialization/deserialization, sensitive data, resource exhaustion, mutability, access control, and third-party code risk. Not for full threat modeling, compliance audits, cryptography design, infrastructure hardening, or non-Java security work.

## Expectations

- **Scenarios:** WHEN trust boundaries and untrusted data are identified THEN check injection, inclusion, deserialization, resource, sensitive-data, mutability, access, and privilege risks.
- **Done means:** secure-coding verdict `low_risk`, `needs_hardening`, or `high_risk`; findings with severity and evidence; recommended remediation; residual risks and assumptions; areas requiring formal security review, if any.
- **Quality needs:** every finding carries evidence.

## Method

| Condition | Action |
|---|---|
| Untrusted input crosses boundary | Validate type, range, size, format, and canonical form. |
| SQL uses string concatenation | Replace with parameterized query shape. |
| XML or deserialization is involved | Require restrictive parser/filter configuration. |
| Sensitive data appears in logs/exceptions | Remove, redact, or sanitize. |
| Resource size depends on input | Add limits and overflow-safe checks. |
| Public/extensible surface exposes internals | Reduce accessibility or document/guard contract. |

Reference: `references/java-secure-coding-guidance.md` — Java secure-coding checklist based on official guidance themes.
