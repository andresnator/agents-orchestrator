# Learning: cola paralela con Herdr

Copia el bloque completo. Los modelos, credenciales y gasto deben estar autorizados en la conversación de ejecución; este prompt no los autoriza. [Catálogo](../domains/learning/manual-tests.md) · [Preparación por ID](fixtures/learning/README.md).

```text
Ejecuta los tests manuales de Learning siguiendo domains/learning/manual-tests.md
 y manual-tests/fixtures/learning/README.md.

Configuración (admite los valores que indique el usuario):
- Casos: todos; acepta una lista de IDs y rechaza IDs desconocidos.
- Revisión Git: HEAD.
- Concurrencia: 4 como máximo; acepta un límite menor.
- Ejecutores: mismo tipo de agente que el coordinador.
- Revisar tras 5 minutos sin progreso; límite total 30 minutos por caso.
- Modelos y gasto: únicamente los autorizados en esta conversación,
  incluidos los workers. No presupongas autorización por nombres de presets.

Preparación:
1. Lee la skill Herdr, verifica HERDR_ENV=1 y consulta el CLI instalado.
   Si no estás dentro de Herdr, informa del bloqueo sin controlar otra sesión.
2. Resuelve la revisión una sola vez con git rev-parse <revision>^{commit}.
   Registra SHA, git status --short, versiones y configuración autorizada.
   Advierte de cambios locales excluidos; no los copies ni hagas commit.
   Comprueba que esa revisión contiene catálogo y fixtures. Si faltan,
   informa del bloqueo de revisión; no uses silenciosamente otro checkout.
3. Crea .ai/manual-test-runs/<run-id>/ en el coordinador, con run.json,
   report.md y directorios de evidencias por caso. Separa esta raíz de
   los entornos que se eliminarán. run.json registra los límites, SHA,
   IDs, tipo de agente, paneles propios y rutas de cada asignación.
4. Clasifica los pasos humanos o de fechas futuras como PENDING con
   condición de continuación. MODEL-VARIANCE sin modelos autorizados es
   PENDING. Otros casos sin configuración necesaria son BLOCKED.
   Ejecuta las partes disponibles y libera el panel sin esperar fechas.

Cola continua:
- Crea hasta cuatro paneles propios sin cambiar el foco del usuario.
  Mantén cola de IDs, asignaciones activas y resultados. No uses tandas.
- Para cada asignación, crea un worktree nuevo y separado desde el SHA
  fijado: git worktree add --detach <ruta-nueva> <SHA>. Prepara ese ID
  desde ese worktree en una raíz nueva; ejecuta validate.mjs. Cada variante
  tiene config, XDG, Learning, sesiones, materiales y servicios propios.
  Instala Learning desde ese worktree siguiendo la excepción standalone.
- En el panel disponible, verifica shell libre, cambia al worktree y
  arranca una sesión NUEVA del mismo tipo de agente que el coordinador.
  Nunca reanudes el agente del caso anterior. Usa herdr agent start con
  un nombre único y el kind real del coordinador. Entrega un único ID,
  SHA, rutas, configuración, variantes, evidencias y límites absolutos.
- Responde a interacciones de prueba según el caso documentado. Estas
  respuestas ya están autorizadas como entradas sintéticas de prueba;
  no equivalen a autorización para gasto, operaciones ajenas o aprendizaje
  humano. No cambies el producto para hacer pasar una prueba.
- Observa todas las asignaciones con esperas cortas, sin bloquear la cola
  esperando a un único agente. Progreso significa una nueva comprobación,
  evidencia o fase identificada; un cambio de estado idle/working no basta.
  Tras el umbral sin progreso, lee sesión, logs y UI; registra diagnóstico
  y resuelve interacciones documentadas. El límite total no se reinicia.
- Al agotar el tiempo, recoge evidencias parciales, detén únicamente los
  procesos propios y marca BLOCKED por tiempo agotado. Continúa la cola
  cuando un caso falle o se bloquee. Idle/done jamás equivalen a PASS.
- En cuanto un caso termina: recoge resultado y evidencias, comprueba
  cada aserción y variante, verifica los archivos archivados, detén sus
  servicios y finaliza la sesión del agente. Comprueba que el panel vuelve
  a shell libre. Asígnale inmediatamente el siguiente ID aunque los demás
  sigan activos. Si no puedes demostrar fin de procesos/sesión, no lo
  reutilices hasta resolverlo; registra el bloqueo de ese panel.

Informe y limpieza:
- Actualiza report.md al terminar cada caso. Incluye estado PASS, FAIL,
  BLOCKED o PENDING; comprobaciones/variantes realizadas y pendientes;
  inicio, fin, duración; modelo efectivo del padre y de cada worker;
  coste conocido o desconocido; worktree, SHA, sesiones, evidencias y
  motivo. FAIL requiere una violación observada; PASS exige todas las
  comprobaciones requeridas. Conserva los resultados parciales.
- Separa cuatro capas: validación de fixtures, protocolo simulado,
  comportamiento del modelo y observaciones humanas. Los datos sintéticos
  se etiquetan siempre. Obtén consentimientos y referencias objeto del
  test de la sesión y herramientas reales, nunca de IDs prefabricados.
- Guarda exportaciones y logs sin credenciales bajo la raíz del informe,
  verifica enlaces y checksums antes de borrar el origen. Detén servicios
  por identidad registrada; no mates procesos por nombre o puerto global.
- Elimina worktrees y entornos PASS propios tras archivar. Conserva los
  FAIL/BLOCKED y los PENDING necesarios para continuación, pero detén sus
  procesos. No borres estado real de un alumno. Cierra al final solo los
  paneles creados por esta ejecución. No hagas commit, push ni merge.

Al acabar la cola, entrega el enlace al informe, totales por estado y
problemas encontrados, indicando explícitamente qué capas se ejecutaron.
```
