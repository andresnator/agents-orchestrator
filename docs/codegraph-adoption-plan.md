# CodeGraph: instalación documentada + plugin de auto-init + adopción CodeGraph-first

> **Estado: pendiente de ejecución.** Plan aprobado el 2026-07-13; investigación y decisiones ya cerradas — ejecutar tal cual las secciones de Cambios y Verification.

## Context

Investigación previa (2 agentes: repo interno + landscape web) estableció:

- **"Graphify" ≈ Graphiti (getzep)** es un grafo de conocimiento *temporal* (memoria de agente), NO entiende código → descartado. **CodeGraph (colbymchenry/codegraph, ~60k stars, v1.4.1)** es el grafo de *estructura de código* correcto: Tree-sitter → SQLite local `.codegraph/codegraph.db`, 20+ lenguajes, sin DB externa, auto-sync tras el init.
- **CodeGraph ya es el mecanismo primario del dominio SDD** como prosa ("CodeGraph-first" en `sdd-explore.md:15-25`, `sdd-design.md:26-34`, `jd-judge-a/b.md:46`, `jd-fix.md:24`), pero nada lo instala ni lo indexa, y los dominios architecture/refactor/plan navegan solo con grep/glob/lsp aunque hacen exactamente el trabajo que un grafo acelera (ciclos, fan-out, callers, blast-radius).
- **Decisión con el usuario** (esta sesión): NO tocar el installer. El wizard oficial `npx @colbymchenry/codegraph` ya autodetecta OpenCode y escribe la config MCP solo → basta documentarlo (README + docs). El `codegraph init` per-proyecto se automatiza con un **plugin OpenCode estilo skill-registry** (`domains/meta/plugins/skill-registry.ts` es el patrón: corre al cargar sesión, background, idempotente, git-exclude de su output).

### Veredicto de viabilidad (ahorro de tokens)

Real pero condicional. Una query al grafo reemplaza N rondas de grep/read que vuelcan archivos completos al contexto. Benchmark del vendor en 7 repos reales: **58% menos tool calls, lecturas de archivo ~0 vs 9, 22% más rápido** (Django 77% menos calls, VS Code 81%). Condiciones: índice per-proyecto presente y fresco, y beneficio concentrado en fases exploration-heavy sobre repos medianos/grandes; marginal en repos pequeños. Procedimiento A/B de validación en §4.

### Datos técnicos confirmados

- Instalación: `npx @colbymchenry/codegraph` (wizard interactivo; autodetecta OpenCode, pregunta global vs por-proyecto). Config manual equivalente en `~/.config/opencode/opencode.json`:
  ```json
  { "mcp": { "codegraph": { "type": "local", "command": ["codegraph", "serve", "--mcp"], "enabled": true } } }
  ```
- Tool MCP por defecto: `codegraph_explore` (símbolos + call-paths + blast-radius en una llamada); tools extra opt-in vía `CODEGRAPH_MCP_TOOLS=explore,callers,impact,...`.
- `codegraph init [path]` crea `.codegraph/` y construye el grafo completo en un paso; después auto-sync. CLI read-only: `status|query|explore|callers|callees|impact|affected`.
- Config de proyecto OpenCode = `opencode.json` en la raíz del repo (NO `.opencode/opencode.json`); el registro global cubre todos los proyectos.

## Cambios

### 1. Documentación de instalación (sin tocar el installer)

- **`README.md`**: sección breve "CodeGraph (optional)" tras el bloque de instalación: qué aporta (1 línea, con la cifra del benchmark), one-liner `npx @colbymchenry/codegraph`, y link a `docs/codegraph.md` y al repo upstream.
- **`docs/codegraph.md`** (nuevo, estilo de `docs/agent-models.md`): wizard vs config manual (bloque JSON de arriba), `CODEGRAPH_MCP_TOOLS`, cómo funciona el plugin de auto-init (guards, env de escape, `.git/info/exclude`), qué agentes son CodeGraph-first, y el procedimiento A/B de tokens (§4).
- **`AGENTS.md`** (symlink `CLAUDE.md`): línea en Repo Shape para `docs/codegraph.md` y el nuevo plugin; una frase en Validation si aplica. **`domains/meta/README.md:32`**: actualizar — la config MCP sigue siendo runtime-local (instalada por el wizard upstream, documentada en docs/codegraph.md) y el auto-init per-proyecto lo hace el nuevo plugin meta.

### 2. Plugin `domains/meta/plugins/codegraph-init.ts` (patrón skill-registry)

Espejo estructural de `skill-registry.ts:301-324` (mismo shape de export `{ id, server }`, mismo `projectRoot()` fallback, `void run()` no bloqueante, errores a `console.error` con prefijo `[codegraph-init]`). Lógica de `run()`:

1. **Guards, en orden**: env de escape (`OPENCODE_CODEGRAPH_AUTOINIT === "0"` → skip); raíz válida (worktree no-root, mismo helper que skill-registry); `.codegraph/` ya existe → skip (idempotencia); binario `codegraph` disponible (`spawn` de `codegraph --version` o lookup en PATH; si falta → skip silencioso con un `console.error` informativo una sola vez).
2. **Init**: `codegraph init <root>` vía `node:child_process` en background, stdio descartado/logueado; sin bloquear el arranque de la sesión.
3. **Exclude**: al éxito, añadir `.codegraph/` a `.git/info/exclude` (mismo helper `ensureInfoExclude` adaptado; no-git → skip).
4. **Concurrencia**: el check de existencia de `.codegraph/` es el guard; si dos sesiones inician a la vez el peor caso es un init duplicado que CodeGraph tolera — documentado, sin lockfile.

Restricción de imports (memoria del repo): los plugins se instalan como symlinks → **solo builtins `node:*` e imports type-only** (`import type { Plugin } from "@opencode-ai/plugin"`), exactamente como skill-registry.

El installer descubre plugins automáticamente → cero cambios en `installers/`.

### 3. Adopción CodeGraph-first en architecture / refactor / plan (prosa)

Replicar el patrón validado de `sdd-explore.md:15-25` (tool MCP como *ejemplo* con fallback genérico — cumple la regla agent-agnostic de `AGENTS.md:63`). Bloque corto por agente:

> CodeGraph-first: si existe `.codegraph/`, usa la tool MCP `codegraph_explore` (callers/callees/impact) antes de grep o file crawling. Nunca ejecutes comandos de ciclo de vida de CodeGraph (init/update): mutan estado. Sin grafo disponible, continúa con lsp/grep/glob como hoy.

Archivos (solo cuerpo, sin tocar frontmatter):
- `domains/architecture/agents/architect.md`, `arch-analyzer.md` (mapas, ciclos y fan-out son queries de grafo directas). NO tocar `boundary-inspector.md` (por diseño solo lee material provisto por el caller).
- `domains/refactor/agents/refactor-planner.md`, `refactor-analyzer.md` (scope de callers/contratos y la batería de lenses reutilizan el índice). `refactor-analyzer` es `bash: deny` → solo tool MCP, sin fallback CLI.
- `domains/plan/agents/deep-planner.md` (línea ~43 "Explore inline (read/grep/glob/lsp)" → grafo como primera opción).

Los agentes sdd quedan intactos: su regla "init solo con autorización del orchestraitor" sigue siendo válida como fallback; el plugin hace que normalmente ya no haga falta.

### 4. Skill `scope-analysis` (bump patch)

`skills/scope-analysis/SKILL.md:20` ("references, imports, routes, or LSP when available") → añadir "or a code-graph index (e.g. CodeGraph MCP/CLI) when available" + bump **patch** de `metadata.version`. No tocar las demás skills de lens: describen *qué* detectar; la navegación la gobierna la prosa del agente.

### 5. Validación del ahorro de tokens (A/B, documentado en docs/codegraph.md)

1. Repo mediano real con `codegraph init` hecho.
2. Misma tarea de exploración (brief tipo sdd-explore o `/arch-*`) en dos sesiones limpias: con `.codegraph/` presente y renombrado.
3. Comparar tokens de sesión y nº de tool calls (stats de OpenCode). Éxito: reducción material (>30%) de input tokens en exploración, en línea con el benchmark (58% menos calls).

## Archivos a modificar

| Archivo | Cambio |
|---|---|
| `README.md` | sección "CodeGraph (optional)" |
| `docs/codegraph.md` | **nuevo** — setup, plugin, A/B |
| `AGENTS.md`, `domains/meta/README.md` | doc del plugin y política MCP |
| `domains/meta/plugins/codegraph-init.ts` | **nuevo** plugin auto-init |
| `domains/architecture/agents/architect.md`, `arch-analyzer.md` | bloque CodeGraph-first |
| `domains/refactor/agents/refactor-planner.md`, `refactor-analyzer.md` | bloque CodeGraph-first |
| `domains/plan/agents/deep-planner.md` | bloque CodeGraph-first |
| `skills/scope-analysis/SKILL.md` | mención code-graph + bump patch |

Sin cambios en `installers/` ni en frontmatter de agentes.

## Verification

1. `scripts/validate-harness.sh` (frontmatter intacto, SemVer de scope-analysis, symlinks) — pasa.
2. `installers/opencode.sh install --dry-run` muestra el plugin nuevo descubierto; install real a `--target /tmp/oc-test` lo enlaza en `plugins/`.
3. Plugin end-to-end: abrir OpenCode en un repo pequeño sin `.codegraph/` con el binario instalado → el init corre en background, aparece `.codegraph/` y la línea en `.git/info/exclude`; segunda sesión no re-inicia (idempotente); `OPENCODE_CODEGRAPH_AUTOINIT=0` lo salta; sin binario, la sesión arranca sin error.
4. Prosa: en un repo indexado, pedir a `arch-analyzer` o `refactor-planner` una exploración y observar que la primera llamada es `codegraph_explore`; en repo sin índice, degrada a lsp/grep sin fricción.
5. Docs: inspección directa del Markdown (cambio doc-only según CLAUDE.md).
6. A/B de tokens según §5 (manual, posterior).
