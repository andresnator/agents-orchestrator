# Dejar la adopción de CodeGraph lista para Goal

> **Estado: Ready for Goal.** Contrato cerrado para OpenCode `1.17.15` y CodeGraph `1.4.1`.

## Resultado

La adopción es opt-in, no bloqueante y recuperable:

- OpenCode queda disponible inmediatamente.
- CodeGraph consulta el estado e indexa en background solo con `OPENCODE_CODEGRAPH_AUTOINIT=1`.
- La TUI muestra únicamente un toast de inicio y otro de resultado.
- Un índice sano no produce notificaciones.
- Estados incompletos se informan, pero nunca se reparan automáticamente.
- El installer no gestiona el CLI ni `mcp.codegraph`; la configuración se fusiona manualmente.

## Alcance cerrado

| Superficie | Decisión |
|---|---|
| Instalación | Instalar solo `@colbymchenry/codegraph@1.4.1`. No ejecutar el wizard de OpenCode porque puede reemplazar el symlink administrado `~/.config/opencode/AGENTS.md`. |
| Configuración MCP | Fusionar manualmente `mcp.codegraph` en `opencode.jsonc`. La guía vive en `docs/codegraph.md`. |
| Plugin | `domains/common/plugins/codegraph-init.ts`, id `codegraph-init`; opt-in estricto, `spawn` sin shell y retorno inmediato. |
| Estado | Consultar `codegraph status <root> --json`, respetar `indexPath`/`CODEGRAPH_DIR` y aceptar solo `index.state=complete` como sano. |
| Concurrencia | Usar el lock nativo de CodeGraph. No crear lock propio. |
| UX | `input.client.tui.showToast`, ruta oficial `/tui/show-toast`; best-effort, sin TUI plugin adicional ni cambio en `tui.json`. |
| Recuperación | `partial`, `failed`, desconocido o `indexing` abandonado generan warning y comando manual; nunca auto-repair. |
| Política | Regla CodeGraph-first en `global/AGENTS.md`; las reglas SDD más estrictas prevalecen; `deep-planner` declara el orden MCP y fallback. |
| Skill | `scope-analysis` pasa de `1.0.0` a `1.0.1` y reconoce índices de grafo. |
| Installer | Sin cambios. El dominio `common` descubre el plugin automáticamente. |

## Contrato de notificaciones

| Evento | Variant | Duración | Mensaje/resultado |
|---|---|---:|---|
| Inicio | `info` | 5 s | `CodeGraph is indexing <repo> in the background. You can keep working.` |
| Éxito | `success` | 5 s | Índice listo, archivos procesados y tiempo transcurrido. |
| CLI ausente | `warning` | 8 s | Causa y comando de instalación. |
| Índice incompleto | `warning` | 8 s | Estado y `codegraph index <root> --force`. |
| Proceso fallido | `error` | 8 s | La sesión sigue operativa y se indica `codegraph status <root>`. |
| Opt-out o índice sano | — | — | Ningún toast. |

Los textos, duraciones, variables de entorno y estados se definen como constantes en el plugin.

## Archivos

- `domains/common/plugins/codegraph-init.ts`
- `scripts/test-codegraph-init.sh`
- `docs/codegraph.md`
- `README.md`
- `AGENTS.md`
- `global/AGENTS.md`
- `domains/common/README.md`
- `domains/meta/README.md`
- `domains/plan/agents/deep-planner.md`
- `skills/scope-analysis/SKILL.md`
- este plan

`installers/` queda fuera de alcance.

## Verificación obligatoria

1. `scripts/test-codegraph-init.sh`: HOME/XDG aislados, CodeGraph falso y listener `/global/event`.
2. Mientras el `init` falso espera una señal, `GET /config` responde y el evento `tui.toast.show` de inicio ya existe; tras liberarlo aparecen el marcador final y el toast de éxito.
3. El mismo contrato cubre opt-out, índice sano, CLI ausente, fallo de init, índices `partial`/`indexing`, `CODEGRAPH_DIR`, exclusión Git e idempotencia en una segunda sesión.
4. `scripts/validate-harness.sh`, `git diff --check`, dry-run e instalación scratch de `common` pasan.
5. Smoke real en `/tmp` con CodeGraph `1.4.1`: `init` seguido de `status --json` con estado `complete`.
6. El A/B documentado usa dos checkouts limpios y cuatro sesiones frescas por brazo; jamás renombra un índice activo.
7. `/judgment` corre en modo `full` sobre todo el diff: dos jueces ciegos, fixes solo para hallazgos confirmados, repetición de pruebas y máximo dos rondas.

El trabajo solo termina con `JUDGMENT: APPROVED`. Un escalamiento se reporta como bloqueo explícito.

## Objetivo copiable a Goal

```text
Implementa docs/codegraph-adoption-plan.md end-to-end. Preserva todos los cambios locales existentes; no modifiques la configuración real del usuario; no cambies installers/; no hagas commit. Verifica el background real de OpenCode mediante /global/event, ejecuta el harness, el test de contrato, dry-run, instalación scratch y smoke de CodeGraph 1.4.1. Después ejecuta judgment-day en modo full sobre todo el diff, corrige únicamente hallazgos confirmados y repite la verificación. No marques el Goal completo sin JUDGMENT: APPROVED; si el juicio escala, déjalo bloqueado con evidencia.
```
