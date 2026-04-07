---
name: sdd-issue
description: >
  Creates agent-ready GitHub issues structured for Spec-Driven Development (SDD).
  The issue contains all the information the SDD orchestrator needs to run a full
  automated cycle: intent, scope, constraints, acceptance scenarios, and technical context.
  Trigger: When creating a GitHub issue for SDD, writing a buildable issue, preparing
  work for the orchestrator, or when the user says "create an issue", "write a ticket",
  "I need to build X". Also trigger when the user references an existing issue number
  and wants to enrich it for SDD consumption.
license: MIT
metadata:
  author: andresnator
  version: "2.0"
---

# SDD Issue Creator

You create GitHub issues that serve as the **entry contract** for an SDD orchestrator cycle.
The issue must contain enough structured information so that an agent can run:

```
@sdd-orchestrator build the issue <number>
```

and execute the full SDD lifecycle (Explore → Propose → Implement → Verify → Archive → Merge)
without asking clarifying questions.

## Why Structure Matters

The SDD orchestrator delegates to specialized subagents:

| Subagent | What it reads from the issue |
|----------|------------------------------|
| **sdd-scanner** | Intent, scope, and technical context to know WHERE to look in the codebase |
| **sdd-spec-writer** | Intent, scope, constraints, and acceptance scenarios to write proposal.md, delta specs, design.md, and tasks.md |
| **sdd-coder** | Indirectly — the specs and tasks derived from the issue |
| **sdd-verifier** | Acceptance scenarios become the verification checklist |

A vague issue forces the orchestrator to guess. A well-structured issue lets it run autonomously.

## Issue Template

Every SDD issue MUST follow this structure. Fill ALL sections — empty sections cause the
orchestrator to halt or make assumptions.

````markdown
## Intent

<!-- WHY this change is needed. 2-3 sentences. The orchestrator uses this to generate
     the change-name and the proposal.md intent section. -->

## Type

<!-- One of: feature | bugfix | refactor | chore -->

## Scope

### In Scope
<!-- Bullet list of what WILL be built or changed. Be specific about:
     - Components, modules, or layers affected
     - New endpoints, entities, or UI elements
     - Behavioral changes -->

### Out of Scope
<!-- Bullet list of what will NOT be done. This prevents scope creep during the
     automated cycle. The spec-writer uses this to set boundaries. -->

## Acceptance Scenarios

<!-- Each scenario becomes a GIVEN/WHEN/THEN in the delta specs and a verification
     checkpoint. Write at least 2 scenarios per in-scope item. -->

### Scenario: <descriptive name>
- GIVEN <precondition>
- WHEN <action or trigger>
- THEN <observable expected result>

### Scenario: <descriptive name>
- GIVEN <precondition>
- WHEN <action or trigger>
- THEN <observable expected result>

## Technical Context

<!-- Information the scanner needs to find relevant code faster. Optional but highly
     valuable for large codebases. -->

- **Affected files/modules**: <!-- e.g., src/auth/, api/routes/users.ts -->
- **Related specs**: <!-- e.g., openspec/specs/auth/spec.md -->
- **Dependencies**: <!-- e.g., needs jsonwebtoken library -->
- **Breaking changes**: <!-- e.g., changes the User entity schema -->

## Constraints

<!-- Non-functional requirements, architectural rules, or team conventions the
     orchestrator must respect. -->

- <!-- e.g., Must maintain backward compatibility with v2 API -->
- <!-- e.g., No new external dependencies without approval -->
- <!-- e.g., Must support PostgreSQL and SQLite -->

## Priority

<!-- One of: critical | high | medium | low -->
````

## Workflow

```
1. Gather requirements from the user (interview if needed)
2. Search existing issues for duplicates: gh issue list --search "keyword"
3. Fill ALL template sections — leave nothing as placeholder
4. Validate: every in-scope item has at least 2 acceptance scenarios
5. Create the issue with appropriate labels
6. Return the issue URL to the user
```

## Creating the Issue

Use `gh issue create` with the filled template. Apply labels based on type:

| Type | Labels |
|------|--------|
| feature | `enhancement`, `sdd-ready` |
| bugfix | `bug`, `sdd-ready` |
| refactor | `refactor`, `sdd-ready` |
| chore | `chore`, `sdd-ready` |

The `sdd-ready` label signals that the issue has the structure needed for automated SDD consumption.

```bash
gh issue create \
  --title "<type>(<scope>): <concise description>" \
  --label "<type-label>,sdd-ready" \
  --body "$(cat <<'EOF'
<filled template content>
EOF
)"
```

### Title Convention

Follow the commit convention: `<type>(<scope>): <description>`

Examples:
- `feat(auth): add OAuth2 social login with Google and GitHub`
- `fix(api): resolve race condition in concurrent task updates`
- `refactor(db): migrate from raw SQL to repository pattern`

## Enriching an Existing Issue

When the user references an existing issue number (e.g., "enrich issue #7 for SDD"):

1. Fetch the issue: `gh issue view <number>`
2. Extract whatever information exists
3. Interview the user to fill gaps in the template
4. Update the issue: `gh issue edit <number> --body "$(cat <<'EOF'...EOF)"`
5. Add the `sdd-ready` label: `gh issue edit <number> --add-label "sdd-ready"`

## Quality Checklist

Before submitting, verify:

- [ ] Intent explains WHY, not just WHAT
- [ ] Every in-scope item has at least 2 acceptance scenarios
- [ ] Scenarios use GIVEN/WHEN/THEN format (the spec-writer depends on this)
- [ ] Out of scope is explicitly defined (prevents orchestrator scope creep)
- [ ] Type is one of: feature, bugfix, refactor, chore
- [ ] Title follows `type(scope): description` convention
- [ ] No placeholder text remains in the body

## Example: Complete SDD-Ready Issue

```markdown
## Intent

Users currently authenticate only with email/password. We need to add OAuth2 social login
with Google and GitHub to reduce signup friction and improve conversion rates.

## Type

feature

## Scope

### In Scope
- OAuth2 authorization code flow for Google and GitHub providers
- New `/auth/oauth/callback` endpoint to handle provider redirects
- User entity extension to store provider ID and linked accounts
- Login page UI buttons for "Sign in with Google" and "Sign in with GitHub"
- Account linking: if an OAuth email matches an existing account, link them

### Out of Scope
- Other OAuth providers (Apple, Microsoft) — future iteration
- OAuth token refresh for API access to provider data
- Migration of existing users to OAuth

## Acceptance Scenarios

### Scenario: First-time Google OAuth login creates account
- GIVEN a user with no existing account
- WHEN the user clicks "Sign in with Google" and authorizes the app
- THEN a new user account is created with the Google email and provider ID

### Scenario: GitHub OAuth login with existing email links accounts
- GIVEN a user with an existing email/password account matching the GitHub email
- WHEN the user clicks "Sign in with GitHub" and authorizes the app
- THEN the GitHub provider is linked to the existing account without creating a duplicate

### Scenario: OAuth callback with invalid state parameter
- GIVEN an OAuth callback request with a tampered or expired state parameter
- WHEN the callback endpoint receives the request
- THEN it returns 403 Forbidden and logs the attempt as a security event

### Scenario: OAuth provider is unavailable
- GIVEN the Google OAuth service is unreachable
- WHEN the user clicks "Sign in with Google"
- THEN the user sees an error message and can still log in with email/password

## Technical Context

- **Affected files/modules**: src/auth/, src/users/user.entity.ts, src/web/pages/login.tsx
- **Related specs**: openspec/specs/auth/spec.md
- **Dependencies**: needs passport-google-oauth20 and passport-github2 libraries
- **Breaking changes**: adds columns to the User table (non-destructive migration)

## Constraints

- Must not break existing email/password authentication
- OAuth secrets must come from environment variables, never hardcoded
- Must work in both development (localhost redirect) and production environments

## Priority

high
```

## Decision Tree

```
User wants to create something new     → feature issue
User reports broken behavior           → bugfix issue
User wants to improve existing code    → refactor issue
User wants infra/tooling/config change → chore issue
User has a vague idea                  → Interview first, then create issue
User references existing issue number  → Enrich the existing issue for SDD
```

---

> Inspired by the issue workflow from [Gentleman Programming](https://github.com/Gentleman-Programming).
