# SDD Domain: Flujo del Orchestraitor

Un solo agente primario, `orchestraitor`, maneja todo el ciclo SDD. Sin comandos, sin triage automático: le dices "vamos con sdd" (o le pides cualquier desarrollo) y él pregunta cómo lo quieres.

## Kickoff

Una sola ronda de preguntas (omite lo que ya dijiste en el pedido):

| Pregunta | Opciones |
|---|---|
| Modo | `interactivo` (entrevista + gates de confirmación) / `automático` (redacta, implementa y resume al final) |
| TDD | test-first por tarea / tests junto a la implementación |
| Juicio | judgment-day al final / sin review adversarial |

Si el pedido es trivial (typo, rename, config), no hay kickoff ni artefactos: lo hace directo.

## Flujo

```
explore -> proposal -> specs || design -> tasks -> implement -> verify -> [judgment] -> archive
```

- **explore**: delega a `sdd-explore` si la zona es desconocida o grande; lee inline si es acotado.
- **proposal/specs/design/tasks**: en modo interactivo usa las skills `sdd-draft-*` (estilo grilling, una pregunta a la vez) con gates tras proposal y tras specs+design; en automático no redacta inline: arma un brief con sus decisiones y delega la escritura a drafters `general` por olas — proposal, luego specs y design en paralelo, luego tasks — de modo que la sesión principal solo ve el brief y los resúmenes; al final relee los artefactos y corrige la coherencia él mismo.
- **implement**: ejecuta `tasks.md` en orden; con TDD, test que falla primero. Trabajo **autocontenido** (tarea sin dependencias en vuelo, investigación lateral, suites pesadas) puede delegarlo al subagente built-in `general`, con `background: true` si no bloquea el siguiente paso.
- **verify**: contrasta la implementación con cada escenario de la spec.
- **judgment** (opcional): skill `judgment-day` — `jd-judge-a` y `jd-judge-b` en paralelo y ciegos; solo findings confirmados van a `jd-fix`; máximo 2 rondas.
- **archive**: fusiona los deltas en las specs canónicas y mueve el cambio a `archive/`.

## Archivos (.orchestraitor/)

```
.orchestraitor/
  project.md                     # contexto del proyecto
  specs/<capability>/spec.md     # specs canónicas: lo que el sistema hace hoy
  changes/<change>/
    proposal.md                  # por qué y qué cambia
    design.md                    # enfoque técnico (opcional si es simple)
    specs/<capability>/spec.md   # deltas ADDED / MODIFIED / REMOVED
    tasks.md                     # checklist de implementación
  changes/archive/<YYYY-MM-DD>-<change>/
```

Convención tomada de OpenSpec: las specs canónicas siempre reflejan lo construido; los cambios activos son propuestas en vuelo, y al archivar sus deltas se fusionan en las canónicas.

## Resume / contexto largo

Los artefactos son el estado; la conversación es desechable. Si la sesión se pone pesada a mitad de un cambio, ciérrala y en una sesión nueva di "continúa \<change\>": el orchestraitor relee `.orchestraitor/changes/<change>/` y retoma desde la primera tarea sin marcar, sin repetir el kickoff (las decisiones de modo/TDD/juicio quedan anotadas en `proposal.md`).
