# Ecosystem Command ↔ Fallback Matrix

Read-only audit commands per ecosystem, with the manifest fallback used when the command is unavailable or denied. Never install a missing tool; use the fallback and mark `method: manifest-fallback`.

| Ecosystem | Evidence files | Audit command | Fallback inspection |
|---|---|---|---|
| npm | `package.json`, `package-lock.json` | `npm audit --json` | Read lockfile versions; flag known-vulnerable ranges and majors far behind. |
| pnpm | `package.json`, `pnpm-lock.yaml` | `pnpm audit --json` | Same as npm on `pnpm-lock.yaml`. |
| yarn | `package.json`, `yarn.lock` | `yarn audit --json` | Same as npm on `yarn.lock`. |
| Maven | `pom.xml` | `mvn dependency:tree` | Read `<dependencies>` + `<properties>` versions; flag EOL frameworks and known-vulnerable ranges. |
| Gradle | `build.gradle(.kts)`, `gradle/libs.versions.toml` | `./gradlew dependencies` (or `gradle dependencies`) | Read version catalogs and build files. |
| Python | `pyproject.toml`, `requirements*.txt`, lockfiles | `pip-audit` | Read pinned versions; flag known-vulnerable ranges. |
| Any | whole repo | `osv-scanner .` | Per-ecosystem fallback above. |

## Runtime EOL quick reference

Check the declared runtime against its support window; flag past-EOL as high, within ~6 months of EOL as medium:

- Node: `engines` in `package.json`, `.nvmrc` — even-numbered LTS lines only; odd lines are always flagged.
- Java: `java.version`/`release` in `pom.xml`, `sourceCompatibility` in Gradle — LTS lines are 8/11/17/21/25.
- Python: `requires-python` — versions get ~5 years from release.

When training-data knowledge of current CVEs or EOL dates may be stale, say so and recommend the authoritative check (`endoflife.date`, the ecosystem advisory DB) instead of asserting.

## Secrets heuristics (grep, case-insensitive)

- Key/token shapes: `AKIA[0-9A-Z]{16}`, `ghp_[A-Za-z0-9]{36}`, `xox[bap]-`, `-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----`, `eyJhbGci` (JWTs).
- Assignments: `(password|passwd|secret|api[_-]?key|token)\s*[:=]\s*["'][^"']{8,}`.
- Files: committed `.env*` (except `.env.example`), `*.pem`, `*.p12`, `credentials*`; verify `.gitignore` covers them.

Quote the file and line, never the matched value.
