# Skills

Reusable, runtime-agnostic skill contracts for agent workflows.

Each skill lives under `skills/{domain}/{skill}/SKILL.md`. Lifecycle state is tracked in `metadata.status`; changing state means editing that field and bumping `metadata.version`, not moving directories.

## engineering

| Skill | Status | Purpose |
|---|---|---|
| `design-patterns-pragmatic` | `backlog` | Trigger: design patterns, GoF patterns, Java patterns, strategy, adapter, factory, builder, decorator, observer. Choose patterns only when they solve real design forces. |
| `domain-modeling` | `in-progress` | Build and sharpen a project's domain model. Use when the user wants to pin down domain terminology or a ubiquitous language, record an architectural decision, or when another skill needs to maintain the domain model. |
| `judgment-day` | `in-progress` | Parallel adversarial review protocol that launches two independent blind judge sub-agents simultaneously to review the same target, synthesizes their findings, applies fixes, and re-judges until both pass or escalates after 2 iterations. |
| `programming-practices-core` | `backlog` | Trigger: programming best practices, clean code, DRY, KISS, YAGNI, readability, maintainability. Evaluate general code quality without depending on language-specific skills. |
| `refactor` | `backlog` | Cross-language catalog of 62+ refactoring techniques based on Martin Fowler's "Refactoring" and Alexander Shvets' "Refactoring Guru". Detects the project's language automatically and provides idiomatic examples. Works with Java, Python, TypeScript, JavaScript, C#, Go, Kotlin, Ruby, PHP, Rust, Swift. Use this skill whenever the user asks to refactor code, improve code quality, eliminate code smells, simplify conditionals, restructure classes, improve API design, or apply any named refactoring technique. Also trigger when the user mentions code smells, legacy code improvement, clean code practices, SOLID principles, or asks "how can I improve this code". Even if the user just pastes code and asks for improvement suggestions, use this skill to identify applicable techniques. También se activa en castellano: "refactorizar", "refactorizar código", mejorar este código", "malos olores del código", "olores de código", código sucio", "limpiar código", "simplificar condicionales", "principios SOLID", cómo mejorar este código", "código limpio", "reestructurar clase", mejorar calidad del código", "técnica de refactorización", "extraer método", renombrar variable", "mover método", "eliminar código duplicado", reducir complejidad", "mejorar legibilidad", "reorganizar código". Includes general Java detection; Java examples should follow the project's Java version and idioms. |
| `service-boundary-analysis` | `backlog` | Trigger: service boundary analysis, microservice inputs/outputs, API/consumer/output mapping. Inspect backend service boundaries with evidence and confidence. |
| `tcr` | `backlog` | Implements the TCR (Test && Commit || Revert) methodology for ultra-short, safe commits during refactoring and development. Use this skill whenever the user wants to apply TCR, make atomic commits after each green test, commit frequently during refactoring, or follow a test-driven commit workflow. Also trigger when the user mentions "TCR", test and commit", "commit after each test", "atomic commits", "micro commits", revert on red", or asks for a disciplined commit cadence during code changes. También se activa en castellano: "test y commit", "commitear tras cada test", commits atómicos", "micro commits", "revertir en rojo", "commits pequeños", flujo TCR", "metodología TCR", "test verde y commit". |
| `work-unit-commits` | `in-progress` | Plan commits as reviewable work units. |

## java

| Skill | Status | Purpose |
|---|---|---|
| `java-api-design` | `backlog` | Trigger: Java API design, public API, encapsulation, modules, visibility, contracts, binary compatibility. Design Java APIs with clear boundaries. |
| `java-clean-code` | `backlog` | Trigger: Java clean code, Java naming, Java readability, Java style, Java maintainability. Improve Java code clarity using modern Java and official guidance. |
| `java-exception-robustness` | `backlog` | Trigger: Java exceptions, error handling, try-with-resources, resource cleanup, checked exceptions, robustness. Design Java failure handling safely. |
| `java-immutability-modeling` | `backlog` | Trigger: Java immutability, records, value objects, defensive copies, mutable collections, DTO modeling. Model Java data safely and clearly. |
| `java-secure-coding` | `backlog` | Trigger: Java secure coding, Oracle Secure Coding Guidelines, input validation, trust boundaries, deserialization, least privilege, sensitive data. Review Java code for secure implementation practices. |
| `java-solid-design` | `backlog` | Trigger: Java SOLID, Java OO design, SRP, OCP, LSP, ISP, DIP, composition over inheritance. Evaluate Java object-oriented design tradeoffs. |
| `java-testing` | `backlog` | Trigger: Java tests, JUnit, Mockito, AssertJ, legacy code, characterization tests, seams. Generate and retrofit Java tests safely. |

## knowledge

| Skill | Status | Purpose |
|---|---|---|
| `english-tutor` | `backlog` | Trigger: explicit English tutoring, correction, practice, or /english. Improve user-provided English while preserving intent and privacy. |
| `summarize` | `in-progress` | Expert in pedagogical book chapter synthesis. Use this skill WHENEVER the user wants to summarize a book chapter, analyze text or document content, study a chapter, extract key ideas from a reading, or when they mention words like "summary", "chapter", "book", "analyze this text", "summarize this", "cornell", "TL;DR" of long-form content. Also trigger when the user uploads a PDF, EPUB, or document and asks to understand or study it in parts. También se activa en castellano: "resumen", "resumen del capítulo", "resumir esto", resumir el capítulo", "analizar este texto", "capítulo", "libro", "ideas clave", resumen del libro", "estudiar el capítulo", "síntesis", "notas cornell", extraer ideas principales", "dame un resumen", "qué dice este capítulo", resumir documento", "analizar lectura". |
| `whisper-extract` | `in-progress` | Extract, transcribe, and summarize audio or video files using OpenAI Whisper. Use this skill whenever the user wants to transcribe audio or video, extract what was said in a recording, get a transcript of a meeting/interview/lecture/podcast, or generate a summary of spoken content. Also trigger when the user mentions files like .mp3, .mp4, .wav, .m4a, .ogg, .flac, .webm, .mkv, .mov and wants text out of them. Generates a .md file with an AI summary followed by the full literal transcript. También se activa en castellano: "transcribir", "transcripción", "extraer audio", qué dice este audio", "transcribir reunión", "transcribir entrevista", pasar audio a texto", "resumir grabación", "transcribir este video", extraer texto de audio", "transcript", "whisper", "grabar y resumir". |

## meta

| Skill | Status | Purpose |
|---|---|---|
| `cognitive-output-refiner` | `in-progress` | Trigger: refine output, summarize output, compact logs, reduce cognitive load, remove duplicates. Refines heavy textual output into a concise, faithful, non-duplicative version. |
| `native-question-ux` | `in-progress` | Trigger: native question ux, portable question presentation. Present a delegated flow's questions via the runtime's native UX with chat fallback. |
| `prompt-evaluator` | `backlog` | Trigger: prompt review, prompt evaluation, improve prompt, evaluar prompt. Refine prompts for clearer LLM execution. |
| `prompt-structure-writer` | `backlog` | Trigger: improve prompt, rewrite prompt, prompt structure, prompt para agente, ordenar instrucciones, convertir idea en prompt. Convert loose ideas, rough instructions, or messy text into clear, brief, executable prompts for local agents such as Codex, Claude Code, OpenCode, and similar runtimes. |
| `skill-creator` | `in-progress` | Creates new AI agent skills following the Agent Skills spec. |
| `skill-registry` | `in-progress` | Create or update the skill registry for the current project. Scans user skills and project conventions, then writes .atl/skill-registry.md. |

## product-docs

| Skill | Status | Purpose |
|---|---|---|
| `adr` | `done` | Trigger: ADR, architecture decision record, technical decision. Create ADRs that document context, options, rationale, consequences, and trade-offs. |
| `buildable-issue` | `backlog` | Creates agent-ready GitHub issues that are ready to build. Formerly framed as sdd-issue / SDD-ready issue creation. Use when creating a buildable issue, implementation-ready ticket, SDD-ready issue, preparing work for an orchestrator, or when the user says "create an issue", "write a ticket", or I need to build X". Also use when the user references an existing issue and wants it enriched with scope, constraints, acceptance scenarios, and technical context. |
| `cognitive-doc-design` | `in-progress` | Design docs that reduce cognitive load. |
| `jira-spike` | `testing` | Create or refine Jira Spike tickets in Jira Markup. Use when the user wants a Spike, research ticket, investigation ticket, technical exploration, discovery work, research question, or SDD-ready Spike input. |
| `jira-task` | `testing` | Create or refine Jira Task tickets in Jira Markup. Use when the user wants a Jira Task, technical task, implementation task, maintenance task, operational work item, developer-ready task, acceptance criteria for a task, or SDD-ready Task input. |
| `jira-user-story` | `testing` | Create or refine Jira User Story tickets in Jira Markup. Use when the user wants a user story, story ticket, product capability, end-user outcome, acceptance criteria for a story, developer-ready story, or SDD-ready User Story input. |
| `prd` | `testing` | Trigger: PRD, product requirements, technical product spec. Create rigorous PRDs for high-stakes, cross-team, regulated, or security-sensitive work. |
| `prd-light` | `testing` | Trigger: PRD light, quick PRD, lightweight PRD, MVP requirements. Create lightweight PRDs for small features, internal tools, and early ideas. |
| `rfc` | `testing` | Trigger: RFC, request for comments, technical proposal. Create RFCs for feature designs, engineering changes, trade-offs, alternatives, and open questions. |
| `usm` | `testing` | Trigger: USM, user story map, story map, mapa de historias, MVP slice. Create journey-first story maps with MVP slicing and Mermaid output. |

## sdd

| Skill | Status | Purpose |
|---|---|---|
| `grill` | `in-progress` | Trigger: grill me, grill with docs, grill me sdd, grill code, grill docs open, entrevistame, entrevistame sdd. Router for relentless interview modes: plain, docs, or SDD planning. |
| `grilling` | `in-progress` | Interview the user relentlessly about a plan or design. Use when the user wants to stress-test a plan before building, or uses any 'grill' trigger phrases. |
| `sdd-draft-design` | `in-progress` | Trigger: draft design, borrador de diseño, SDD design interview. Explore the codebase, interview, then draft design.md; plan-only, write on approval. |
| `sdd-draft-proposal` | `in-progress` | Trigger: draft proposal, borrador de propuesta, SDD proposal interview. Interview, then draft an OpenSpec proposal.md; plan-only, write on approval. |
| `sdd-draft-spec` | `in-progress` | Trigger: draft spec, borrador de spec, SDD delta spec interview. Interview, then draft delta specs with scenarios; plan-only, write on approval. |
| `sdd-draft-tasks` | `in-progress` | Trigger: draft tasks, borrador de tareas, SDD tasks interview. Draft ordered, verifiable tasks from spec and design; plan-only, write on approval. |
