import { createHash, randomUUID } from "node:crypto"
import { constants } from "node:fs"
import { mkdir, open, readFile, readdir, realpath, rename, unlink } from "node:fs/promises"
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path"
import type { Plugin, ToolContext } from "@opencode-ai/plugin"
import { recallCalcContracts, recallCalcHost } from "./recall-calc.ts"

const PLUGIN_ID = "learning-runtime"
const MAX_INPUT_CHARS = 24_000
const MAX_RESULT_CHARS = 24_000
const MAX_STATE_BYTES = 1_000_000
const MAX_CHOICES = 12
const MAX_RECORDS = 200
const STATE_VERSION = 1
const TOPIC_SLUG = /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/
const SESSION_SCOPE = /^session:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/
const EVENT_ID = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,99}$/
const ARTIFACT_PATH = /^(?:resources\.md|(?:notes|exercises|quizzes|teachbacks|dialogues|maps|anki)\/[a-z0-9][a-z0-9._-]*\.(?:md|txt))$/
const WRITER_ARTIFACT_PATH = /^(?:resources\.md|(?:notes|exercises|quizzes|teachbacks|dialogues|maps)\/[a-z0-9][a-z0-9._-]*\.md)$/
const WORKERS = ["learning-researcher", "learning-writer", "learning-summarizer"] as const
const PURPOSES = ["cards", "readiness", "grade", "summary", "export", "retirement", "reformulation", "override", "gap", "mission"] as const
type Worker = (typeof WORKERS)[number]
type Purpose = (typeof PURPOSES)[number]
type JobStatus = "starting" | "running" | "completed" | "failed" | "cancelled" | "cancelling"
type ChoiceStatus = "pending" | "answered" | "dismissed" | "invalidated"

// The installer flattens plugin entries. Keep these private boundary types here.
interface ChoiceInput {
  purpose: Purpose
  revision: number
  subject_digest?: string
  subject_json?: string
  question: string
  options: { id: string; label: string; description: string }[]
  multiple?: boolean
}
interface Choice {
  id: string
  sessionID: string
  sourceMessageID: string
  input: ChoiceInput
  digest: string
  status: ChoiceStatus
  callID?: string
  requestID?: string
  selected?: string[]
}
interface Job {
  id: string
  parentID: string
  worker: Worker
  scope: string
  revision: number
  status: JobStatus
  promptMessageID?: string
  result?: string
  error?: string
  notified: boolean
  supersededRevision?: number
}

type LearningPhase = "mission" | "class" | "practice" | "consolidation" | "closed"
type RetentionDisposition = "pending" | "selected" | "none" | "deferred"
type CardStatus = "active" | "suspended" | "retired"
type LearningEvent =
  | { type: "create_topic"; event_id: string; date: string; title: string; materials_language: string; goal: string; target_language?: string; native_language?: string; production_required?: boolean; concepts: Array<{ id: string; title: string; prerequisites: string[]; fundamental: boolean }>; modules: Array<{ id: string; title: string; win: string }> }
  | { type: "record_class"; event_id: string; date: string; module_id: string; taught_concept_ids: string[]; evidence: string }
  | { type: "preview_cards"; event_id: string; date: string; module_id: string; preview_id: string; source_revision: number; cards: Array<{ proposal_id: string; cue: string; answer: string; concept_id: string; reason: string }> }
  | { type: "select_cards"; event_id: string; date: string; module_id: string; preview_id: string; interaction_id: string; disposition: Exclude<RetentionDisposition, "pending">; proposal_ids: string[] }
  | { type: "start_practice"; event_id: string; date: string; module_id: string; interaction_id: string }
  | { type: "record_attempt"; event_id: string; date: string; module_id: string; outcome: "pending" | "partial" | "stuck" | "done"; evidence: string; causal_explanation?: string; transfer_evidence?: string }
  | { type: "record_consolidation"; event_id: string; date: string; module_id: string; learner_evidence: string; blocking_gaps: string[] }
  | { type: "close_module"; event_id: string; date: string; module_id: string }
  | { type: "grade_card"; event_id: string; date: string; card_id: string; grade: "Again" | "Hard" | "Good" | "Easy"; evidence: string; interaction_id: string }
  | { type: "preview_card_change"; event_id: string; date: string; card_id: string; change_id: string; source_revision: number; kind: "edit" | "reformulate" | "split"; replacements: Array<{ cue: string; answer: string }> }
  | { type: "apply_card_change"; event_id: string; date: string; card_id: string; change_id: string; interaction_id: string }
  | { type: "set_card_status"; event_id: string; date: string; card_id: string; status: "active" | "suspended" | "retired"; interaction_id: string }
  | { type: "set_fundamental_override"; event_id: string; date: string; concept_id: string; enabled: boolean; interaction_id: string }
  | { type: "add_language_unit"; event_id: string; date: string; unit_id: string; passive_at: string; next_due: string; situation: string; target_text: string; native_text: string }
  | { type: "record_language_attempt"; event_id: string; date: string; unit_id: string; outcome: "needs-another-attempt" | "completed" | "input-only"; evidence: string; next_due?: string }
  | { type: "set_vocab_candidates"; event_id: string; date: string; candidates: Array<{ id: string; target_language: string; unit: string; row: string }> }
  | { type: "export_vocab"; event_id: string; date: string; interaction_id: string; candidate_ids: string[]; batch_path: string }
  | { type: "adopt_gap"; event_id: string; date: string; gap_id: string; interaction_id: string; adoption: "drill" | "practice" | "declined" }
  | { type: "record_gap"; event_id: string; date: string; gap_id: string; category: string; synthetic_pattern: string; occurrence_refs: string[] }
  | { type: "attach_artifact"; event_id: string; date: string; path: string; content: string; source_revision: number; job_id: string; module_id?: string; selected_card_ids?: string[] }
  | { type: "complete_topic"; event_id: string; date: string; evidence: string }

type EventType = LearningEvent["type"]
const EVENT_TYPES = [
  "create_topic", "record_class", "preview_cards", "select_cards", "start_practice", "record_attempt", "record_consolidation", "close_module",
  "grade_card", "preview_card_change", "apply_card_change", "set_card_status", "set_fundamental_override", "add_language_unit", "record_language_attempt",
  "set_vocab_candidates", "export_vocab", "adopt_gap", "record_gap", "attach_artifact", "complete_topic",
] as const satisfies readonly EventType[]

interface EventReference {
  event: Record<string, unknown>
  consent_subject?: Record<string, unknown> | string
  rules?: string[]
}

const EVENT_REFERENCE: Record<EventType, EventReference> = {
  create_topic: { event: { type: "create_topic", event_id: "EVENT_ID", date: "YYYY-MM-DD", title: "string", materials_language: "string", goal: "string", target_language: "optional string", native_language: "optional string", production_required: "optional boolean", concepts: [{ id: "K-0001", title: "string", prerequisites: [], fundamental: false }], modules: [{ id: "M-0001", title: "string", win: "string" }] }, rules: ["target_language and native_language appear together", "default fundamental count <= floor(concepts / 5)"] },
  record_class: { event: { type: "record_class", event_id: "EVENT_ID", date: "YYYY-MM-DD", module_id: "M-####", taught_concept_ids: ["K-####"], evidence: "actual teaching evidence" } },
  preview_cards: { event: { type: "preview_cards", event_id: "EVENT_ID", date: "YYYY-MM-DD", module_id: "M-####", preview_id: "string", source_revision: "current revision", cards: [{ proposal_id: "string", cue: "string", answer: "string", concept_id: "K-####", reason: "string" }] }, rules: ["zero to two taught fundamental concepts", "selected retention requires the explicit card-change workflow; it cannot be previewed or selected again"] },
  select_cards: { event: { type: "select_cards", event_id: "EVENT_ID", date: "YYYY-MM-DD", module_id: "M-####", preview_id: "string", interaction_id: "UUID", disposition: "selected | none | deferred", proposal_ids: ["proposal_id"] }, consent_subject: "exact stored module.retention.preview with digest omitted" },
  start_practice: { event: { type: "start_practice", event_id: "EVENT_ID", date: "YYYY-MM-DD", module_id: "M-####", interaction_id: "UUID" }, consent_subject: { topic_slug: "TOPIC_SLUG", module_id: "M-####" } },
  record_attempt: { event: { type: "record_attempt", event_id: "EVENT_ID", date: "YYYY-MM-DD", module_id: "M-####", outcome: "pending | partial | stuck | done", evidence: "actual learner evidence", causal_explanation: "optional string", transfer_evidence: "optional string" } },
  record_consolidation: { event: { type: "record_consolidation", event_id: "EVENT_ID", date: "YYYY-MM-DD", module_id: "M-####", learner_evidence: "string", blocking_gaps: ["string"] } },
  close_module: { event: { type: "close_module", event_id: "EVENT_ID", date: "YYYY-MM-DD", module_id: "M-####" } },
  grade_card: { event: { type: "grade_card", event_id: "EVENT_ID", date: "YYYY-MM-DD", card_id: "C-####", grade: "Again | Hard | Good | Easy", evidence: "actual answer evidence", interaction_id: "UUID" }, consent_subject: { topic_slug: "TOPIC_SLUG", card_id: "C-####" } },
  preview_card_change: { event: { type: "preview_card_change", event_id: "EVENT_ID", date: "YYYY-MM-DD", card_id: "C-####", change_id: "unique string", source_revision: "current revision", kind: "edit | reformulate | split", replacements: [{ cue: "string", answer: "string" }] }, rules: ["split has exactly two replacements; other kinds have one", "change_id is unique within the topic"] },
  apply_card_change: { event: { type: "apply_card_change", event_id: "EVENT_ID", date: "YYYY-MM-DD", card_id: "C-####", change_id: "string", interaction_id: "UUID" }, consent_subject: "exact stored card_changes entry with digest omitted" },
  set_card_status: { event: { type: "set_card_status", event_id: "EVENT_ID", date: "YYYY-MM-DD", card_id: "C-####", status: "active | suspended | retired", interaction_id: "UUID" }, consent_subject: { topic_slug: "TOPIC_SLUG", card_id: "C-####" } },
  set_fundamental_override: { event: { type: "set_fundamental_override", event_id: "EVENT_ID", date: "YYYY-MM-DD", concept_id: "K-####", enabled: "boolean", interaction_id: "UUID" }, consent_subject: { topic_slug: "TOPIC_SLUG", concept_id: "K-####" } },
  add_language_unit: { event: { type: "add_language_unit", event_id: "EVENT_ID", date: "YYYY-MM-DD", unit_id: "L-####", passive_at: "YYYY-MM-DD", next_due: "passive_at + 3 days", situation: "string", target_text: "string", native_text: "string" } },
  record_language_attempt: { event: { type: "record_language_attempt", event_id: "EVENT_ID", date: "YYYY-MM-DD", unit_id: "L-####", outcome: "needs-another-attempt | completed | input-only", evidence: "actual learner evidence", next_due: "required future YYYY-MM-DD only when another attempt is needed" } },
  set_vocab_candidates: { event: { type: "set_vocab_candidates", event_id: "EVENT_ID", date: "YYYY-MM-DD", candidates: [{ id: "V-####", target_language: "string", unit: "string", row: "five semicolon-separated fields" }] }, rules: ["reuse the existing candidate ID to edit an unexported row at the current revision, then preview and confirm again", "exported candidates are immutable; a new ID with an existing normalized key is skipped"] },
  export_vocab: { event: { type: "export_vocab", event_id: "EVENT_ID", date: "YYYY-MM-DD", interaction_id: "UUID", candidate_ids: ["selected V-####"], batch_path: "anki/<name>.txt" }, consent_subject: { topic_slug: "TOPIC_SLUG", candidates: [{ id: "V-####", target_language: "string", unit: "string", row: "exact stored row" }] }, rules: ["subject candidates include the full preview in choice-option order, not just the selected subset", "candidate option IDs are their V-#### IDs; optional edit/none choices do not export", "candidate_ids must match the host-selected subset exactly"] },
  adopt_gap: { event: { type: "adopt_gap", event_id: "EVENT_ID", date: "YYYY-MM-DD", gap_id: "G-####", interaction_id: "UUID", adoption: "drill | practice | declined" }, consent_subject: { topic_slug: "TOPIC_SLUG", gap_id: "G-####" } },
  record_gap: { event: { type: "record_gap", event_id: "EVENT_ID", date: "YYYY-MM-DD", gap_id: "G-####", category: "string", synthetic_pattern: "string", occurrence_refs: ["opaque EVENT_ID"] } },
  attach_artifact: { event: { type: "attach_artifact", event_id: "EVENT_ID", date: "YYYY-MM-DD", path: "approved relative artifact path", content: "exact writer content", source_revision: "current revision", job_id: "accepted child ID", module_id: "required for note/exercise", selected_card_ids: ["required exact module card IDs for note/exercise"] } },
  complete_topic: { event: { type: "complete_topic", event_id: "EVENT_ID", date: "YYYY-MM-DD", evidence: "actual capstone evidence" }, rules: ["completion evidence, date, and event ID are stored in topic.completion and rendered in mission.md", "completed topics cannot be completed again with a different event"] },
}

interface TopicState {
  schema_version: 1
  revision: number
  topic: { slug: string; title: string; materials_language: string; goal: string; status: "active" | "completed"; completion?: { date: string; event_id: string; evidence: string }; target_language?: string; native_language?: string; production_required?: boolean }
  concepts: Array<{ id: string; title: string; prerequisites: string[]; fundamental: boolean; learner_override: boolean; taught: boolean }>
  modules: Array<{
    id: string; title: string; win: string; phase: LearningPhase; taught_concept_ids: string[]; class_evidence?: string
    attempt?: { revision: number; outcome: "pending" | "partial" | "stuck" | "done"; evidence: string; causal_explanation?: string; transfer_evidence?: string }
    consolidation?: { revision: number; learner_evidence: string; blocking_gaps: string[] }
    retention: { disposition: RetentionDisposition; preview?: { topic_slug: string; module_id: string; id: string; source_revision: number; digest: string; cards: Array<{ proposal_id: string; cue: string; answer: string; concept_id: string; reason: string }> }; selected_card_ids: string[] }
    artifacts: { note?: string; exercise?: string; teachback?: string }
  }>
  cards: Array<{ id: string; cue: string; answer: string; concept_id: string; source_revision: number; box: number; last: string; next: string; status: CardStatus; again_count: number; lineage: string[] }>
  card_changes: Array<{ topic_slug: string; id: string; card_id: string; source_revision: number; digest: string; kind: "edit" | "reformulate" | "split"; replacements: Array<{ cue: string; answer: string }> }>
  review_events: Array<{ event_id: string; card_id: string; date: string; grade: string; evidence: string }>
  language_units: Array<{ id: string; passive_at: string; next_due: string; situation: string; target_text: string; native_text: string; status: "pending" | "needs-another-attempt" | "completed" | "input-only"; evidence?: string }>
  vocabulary: { candidates: Array<{ id: string; target_language: string; unit: string; duplicate_key: string; row: string; status: "candidate" | "exported" }>; exports: Array<{ event_id: string; path: string; candidate_ids: string[]; date: string }> }
  gaps: Array<{ id: string; category: string; synthetic_pattern: string; occurrence_refs: string[]; adoption: "pending" | "drill" | "practice" | "declined" }>
  jobs: Array<{ id: string; parent_id: string; worker: Worker; source_revision: number; status: JobStatus; result_digest?: string; error?: string; superseded_revision?: number }>
  artifacts: Record<string, { content: string; source_revision: number; job_id?: string; module_id?: string; selected_card_ids?: string[] }>
  applied_events: Record<string, string>
  consents: Array<{ interaction_id: string; purpose: Purpose; request_id: string; digest: string; selected: string[] }>
  views: { revision: number; status: "pending" | "current"; error?: string }
}

interface CommitResult {
  duplicate: boolean
  revision: number
  event_id: string
  views: "pending" | "current"
  changed: string[]
}

function validStoredState(value: unknown, slug: string): value is TopicState {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false
  const state = value as any
  const record = (item: unknown) => Boolean(item && typeof item === "object" && !Array.isArray(item))
  const strings = (item: unknown) => Array.isArray(item) && item.every((entry) => typeof entry === "string")
  const uniqueIDs = (items: any[]) => new Set(items.map((item) => item.id)).size === items.length
  if (state.schema_version !== STATE_VERSION || !Number.isSafeInteger(state.revision) || state.revision < 1) return false
  if (!record(state.topic) || state.topic.slug !== slug || !["active", "completed"].includes(state.topic.status)) return false
  if (![state.topic.title, state.topic.materials_language, state.topic.goal].every((item) => typeof item === "string" && item.trim())) return false
  if ((state.topic.target_language === undefined) !== (state.topic.native_language === undefined)) return false
  if (state.topic.target_language !== undefined && (typeof state.topic.target_language !== "string" || typeof state.topic.native_language !== "string")) return false
  if (state.topic.production_required !== undefined && typeof state.topic.production_required !== "boolean") return false
  if (!["concepts", "modules", "cards", "card_changes", "review_events", "language_units", "gaps", "jobs", "consents"].every((key) => Array.isArray(state[key]))) return false
  if (!record(state.vocabulary) || !Array.isArray(state.vocabulary.candidates) || !Array.isArray(state.vocabulary.exports)) return false
  if (!record(state.artifacts) || !record(state.applied_events) || !record(state.views)) return false
  if (state.topic.status === "completed") {
    const completion = state.topic.completion
    if (!record(completion) || !recallCalcContracts.isIsoDate(completion.date) || !EVENT_ID.test(completion.event_id) || !state.applied_events[completion.event_id] || typeof completion.evidence !== "string" || !completion.evidence.trim() || completion.evidence.length > MAX_INPUT_CHARS) return false
  } else if (state.topic.completion !== undefined) return false
  if (state.views.revision !== state.revision || !["pending", "current"].includes(state.views.status)) return false
  if (!uniqueIDs(state.concepts) || !uniqueIDs(state.modules) || !uniqueIDs(state.cards) || !uniqueIDs(state.card_changes) || !uniqueIDs(state.language_units) || !uniqueIDs(state.vocabulary.candidates) || !uniqueIDs(state.gaps) || !uniqueIDs(state.jobs)) return false
  const conceptIDs = new Set(state.concepts.map((item: any) => item.id))
  const moduleIDs = new Set(state.modules.map((item: any) => item.id))
  const cardIDs = new Set(state.cards.map((item: any) => item.id))
  if (!state.concepts.every((item: any) => record(item) && /^K-\d{4}$/.test(item.id) && typeof item.title === "string" && strings(item.prerequisites) && item.prerequisites.every((id: string) => conceptIDs.has(id) && id !== item.id) && typeof item.fundamental === "boolean" && typeof item.learner_override === "boolean" && typeof item.taught === "boolean")) return false
  if (!state.modules.every((item: any) => {
    if (!record(item) || !/^M-\d{4}$/.test(item.id) || typeof item.title !== "string" || typeof item.win !== "string" || !["mission", "class", "practice", "consolidation", "closed"].includes(item.phase)) return false
    if (!strings(item.taught_concept_ids) || !item.taught_concept_ids.every((id: string) => conceptIDs.has(id)) || !record(item.retention) || !["pending", "selected", "none", "deferred"].includes(item.retention.disposition)) return false
    if (!strings(item.retention.selected_card_ids) || !item.retention.selected_card_ids.every((id: string) => cardIDs.has(id)) || !record(item.artifacts)) return false
    if (![item.artifacts.note, item.artifacts.exercise, item.artifacts.teachback].every((path) => path === undefined || typeof path === "string")) return false
    if (item.retention.preview !== undefined) {
      const preview = item.retention.preview
      if (!record(preview) || preview.topic_slug !== slug || preview.module_id !== item.id || typeof preview.id !== "string" || !Number.isSafeInteger(preview.source_revision) || preview.source_revision > state.revision || !/^[a-f0-9]{64}$/.test(preview.digest) || !Array.isArray(preview.cards) || preview.cards.length > 2) return false
      if (!preview.cards.every((card: any) => record(card) && typeof card.proposal_id === "string" && typeof card.cue === "string" && card.cue.trim() && typeof card.answer === "string" && card.answer.trim() && conceptIDs.has(card.concept_id) && typeof card.reason === "string" && card.reason.trim())) return false
      if (new Set(preview.cards.map((card: any) => card.proposal_id)).size !== preview.cards.length) return false
      if (preview.digest !== digest({ topic_slug: preview.topic_slug, module_id: preview.module_id, id: preview.id, source_revision: preview.source_revision, cards: preview.cards })) return false
    }
    if (item.attempt !== undefined && (!record(item.attempt) || !Number.isSafeInteger(item.attempt.revision) || item.attempt.revision > state.revision || !["pending", "partial", "stuck", "done"].includes(item.attempt.outcome) || typeof item.attempt.evidence !== "string")) return false
    if (item.consolidation !== undefined && (!record(item.consolidation) || !Number.isSafeInteger(item.consolidation.revision) || item.consolidation.revision > state.revision || typeof item.consolidation.learner_evidence !== "string" || !strings(item.consolidation.blocking_gaps))) return false
    return true
  })) return false
  if (!state.cards.every((item: any) => record(item) && /^C-\d{4}$/.test(item.id) && typeof item.cue === "string" && item.cue.trim() && typeof item.answer === "string" && item.answer.trim() && conceptIDs.has(item.concept_id) && Number.isSafeInteger(item.source_revision) && item.source_revision <= state.revision && Number.isInteger(item.box) && item.box >= 1 && item.box <= 5 && recallCalcContracts.isIsoDate(item.last) && recallCalcContracts.isIsoDate(item.next) && ["active", "suspended", "retired"].includes(item.status) && Number.isInteger(item.again_count) && item.again_count >= 0 && strings(item.lineage) && new Set(item.lineage).size === item.lineage.length && item.lineage.every((id: string) => cardIDs.has(id) && id !== item.id))) return false
  if (!state.card_changes.every((item: any) => {
    if (!record(item) || item.topic_slug !== slug || typeof item.id !== "string" || !cardIDs.has(item.card_id) || state.cards.find((card: any) => card.id === item.card_id)?.status !== "active") return false
    if (!Number.isSafeInteger(item.source_revision) || item.source_revision > state.revision || !/^[a-f0-9]{64}$/.test(item.digest) || !["edit", "reformulate", "split"].includes(item.kind) || !Array.isArray(item.replacements)) return false
    if ((item.kind === "split" && item.replacements.length !== 2) || (item.kind !== "split" && item.replacements.length !== 1)) return false
    if (!item.replacements.every((replacement: any) => record(replacement) && typeof replacement.cue === "string" && replacement.cue.trim() && typeof replacement.answer === "string" && replacement.answer.trim())) return false
    return item.digest === digest({ topic_slug: item.topic_slug, id: item.id, card_id: item.card_id, source_revision: item.source_revision, kind: item.kind, replacements: item.replacements })
  })) return false
  if (!state.language_units.every((item: any) => record(item) && /^L-\d{4}$/.test(item.id) && recallCalcContracts.isIsoDate(item.passive_at) && recallCalcContracts.isIsoDate(item.next_due) && typeof item.situation === "string" && typeof item.target_text === "string" && typeof item.native_text === "string" && ["pending", "needs-another-attempt", "completed", "input-only"].includes(item.status))) return false
  if (!state.vocabulary.candidates.every((item: any) => record(item) && /^V-\d{4}$/.test(item.id) && typeof item.target_language === "string" && typeof item.unit === "string" && typeof item.duplicate_key === "string" && typeof item.row === "string" && ["candidate", "exported"].includes(item.status))) return false
  if (!state.vocabulary.exports.every((item: any) => record(item) && EVENT_ID.test(item.event_id) && /^anki\/[a-z0-9][a-z0-9._-]*\.txt$/.test(item.path) && strings(item.candidate_ids) && item.candidate_ids.length > 0 && item.candidate_ids.every((id: string) => state.vocabulary.candidates.some((candidate: any) => candidate.id === id && candidate.status === "exported")) && recallCalcContracts.isIsoDate(item.date)) || new Set(state.vocabulary.exports.map((item: any) => item.event_id)).size !== state.vocabulary.exports.length) return false
  if (!state.review_events.every((item: any) => record(item) && EVENT_ID.test(item.event_id) && cardIDs.has(item.card_id) && recallCalcContracts.isIsoDate(item.date) && ["Again", "Hard", "Good", "Easy", "Again+reformulate", "Again+split"].includes(item.grade) && typeof item.evidence === "string" && item.evidence.trim()) || new Set(state.review_events.map((item: any) => item.event_id)).size !== state.review_events.length) return false
  if (!state.gaps.every((item: any) => record(item) && /^G-\d{4}$/.test(item.id) && typeof item.category === "string" && item.category.trim() && typeof item.synthetic_pattern === "string" && item.synthetic_pattern.trim() && strings(item.occurrence_refs) && item.occurrence_refs.length > 0 && item.occurrence_refs.every((reference: string) => EVENT_ID.test(reference)) && ["pending", "drill", "practice", "declined"].includes(item.adoption))) return false
  if (!state.jobs.every((item: any) => record(item) && typeof item.id === "string" && typeof item.parent_id === "string" && (WORKERS as readonly string[]).includes(item.worker) && Number.isSafeInteger(item.source_revision) && item.source_revision <= state.revision && ["starting", "running", "completed", "failed", "cancelled", "cancelling"].includes(item.status))) return false
  if (!state.consents.every((item: any) => record(item) && typeof item.interaction_id === "string" && (PURPOSES as readonly string[]).includes(item.purpose) && typeof item.request_id === "string" && /^[a-f0-9]{64}$/.test(item.digest) && strings(item.selected)) || new Set(state.consents.map((item: any) => item.interaction_id)).size !== state.consents.length) return false
  if (!Object.entries(state.artifacts).every(([path, artifact]: [string, any]) => ARTIFACT_PATH.test(path) && record(artifact) && typeof artifact.content === "string" && Number.isSafeInteger(artifact.source_revision) && artifact.source_revision <= state.revision && (artifact.module_id === undefined || moduleIDs.has(artifact.module_id)) && (artifact.selected_card_ids === undefined || strings(artifact.selected_card_ids) && new Set(artifact.selected_card_ids).size === artifact.selected_card_ids.length && artifact.selected_card_ids.every((id: string) => cardIDs.has(id))))) return false
  if (!Object.entries(state.applied_events).every(([id, hash]) => EVENT_ID.test(id) && typeof hash === "string" && /^[a-f0-9]{64}$/.test(hash))) return false
  return true
}

function canonicalJSON(value: unknown): string {
  return JSON.stringify(value, (_key, item) => item && typeof item === "object" && !Array.isArray(item)
    ? Object.fromEntries(Object.keys(item).sort().map((key) => [key, item[key]])) : item)
}

function digest(value: unknown): string {
  return createHash("sha256").update(canonicalJSON(value)).digest("hex")
}

function requireTeacher(context: ToolContext) {
  if (context.agent !== "mentor") throw new Error("learning_teacher_required")
}

function boundedText(value: string, limit: number) {
  if (!value.trim() || value.length > limit) throw new Error("invalid_bounded_text")
}

function requiredString(value: unknown, name: string, limit = MAX_INPUT_CHARS): string {
  if (typeof value !== "string" || !value.trim() || value.length > limit) throw new Error(`invalid_${name}`)
  return value
}

function requiredDate(value: unknown, name = "date"): string {
  const date = requiredString(value, name, 10)
  if (!recallCalcContracts.isIsoDate(date)) throw new Error(`invalid_${name}`)
  return date
}

function requiredArray<T>(value: unknown, name: string, limit = MAX_RECORDS): T[] {
  if (!Array.isArray(value) || value.length > limit) throw new Error(`invalid_${name}`)
  return value as T[]
}

function requiredBoolean(value: unknown, name: string): boolean {
  if (typeof value !== "boolean") throw new Error(`invalid_${name}`)
  return value
}

function requiredEnum<const T extends readonly string[]>(value: unknown, name: string, allowed: T): T[number] {
  if (typeof value !== "string" || !(allowed as readonly string[]).includes(value)) throw new Error(`invalid_${name}`)
  return value as T[number]
}

function requiredRecord(value: unknown, name: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`invalid_${name}`)
  return value as Record<string, unknown>
}

function requiredID(value: unknown, prefix: string): string {
  const id = requiredString(value, `${prefix.toLowerCase()}_id`, 32)
  if (!new RegExp(`^${prefix}-\\d{4}$`).test(id)) throw new Error(`invalid_${prefix.toLowerCase()}_id`)
  return id
}

function unique(values: string[], name: string) {
  if (new Set(values).size !== values.length) throw new Error(`duplicate_${name}`)
}

function sameStrings(left: string[], right: string[]) {
  return left.length === right.length && left.every((value, index) => value === right[index])
}

function normalizeVocabKey(language: string, unit: string) {
  const normalized = (value: string) => value.normalize("NFKC").toLowerCase().trim().replace(/\s+/g, " ")
  return `${normalized(language)}:${normalized(unit)}`
}

function slugText(value: string) {
  const slug = value.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 48)
  return slug || "summary"
}

function artifactKind(path: string): string | undefined {
  if (path === "resources.md") return "resources"
  return ({ notes: "note", exercises: "exercise", quizzes: "quiz", teachbacks: "teachback", dialogues: "dialogue", maps: "map" } as Record<string, string>)[path.split("/", 1)[0]]
}

function eventDigest(event: LearningEvent) {
  return digest(event)
}

function validateConsent(choice: Choice | undefined, purpose: Purpose, eventInteraction: string, selected: string[], subject: Record<string, unknown>) {
  if (!choice || choice.id !== eventInteraction || choice.status !== "answered" || !choice.requestID || !choice.selected) {
    throw new Error("verified_interaction_required")
  }
  if (choice.input.purpose !== purpose) throw new Error("interaction_purpose_mismatch")
  const subjectDigest = digest(subject)
  if (choice.input.subject_digest !== subjectDigest || choice.input.subject_json !== canonicalJSON(subject)) {
    throw new Error("interaction_subject_mismatch")
  }
  unique(selected, "selection")
  if (selected.length !== choice.selected.length || selected.some((id) => !choice.selected!.includes(id))) {
    throw new Error("interaction_selection_mismatch")
  }
}

function storedSubject<T extends { digest: string }>(value: T): Omit<T, "digest"> {
  const { digest: _digest, ...subject } = value
  return subject
}

function requireValidState(state: TopicState, slug: string) {
  if (!validStoredState(state, slug)) throw new Error("resulting_state_malformed")
}

function initialState(slug: string, event: Extract<LearningEvent, { type: "create_topic" }>): TopicState {
  if (!TOPIC_SLUG.test(slug) || slug === "summaries") throw new Error("invalid_topic_slug")
  requiredDate(event.date)
  requiredString(event.title, "title", 200)
  requiredString(event.materials_language, "materials_language", 80)
  requiredString(event.goal, "goal")
  const concepts = requiredArray<Extract<LearningEvent, { type: "create_topic" }>["concepts"][number]>(event.concepts, "concepts")
  const modules = requiredArray<Extract<LearningEvent, { type: "create_topic" }>["modules"][number]>(event.modules, "modules")
  if (!concepts.length || !modules.length) throw new Error("concepts_and_modules_required")
  unique(concepts.map((item) => requiredID(requiredRecord(item, "concept").id, "K")), "concept_id")
  unique(modules.map((item) => requiredID(requiredRecord(item, "module").id, "M")), "module_id")
  const conceptIDs = new Set(concepts.map((item) => item.id))
  for (const concept of concepts) {
    requiredString(concept.title, "concept_title", 200)
    requiredBoolean(concept.fundamental, "fundamental")
    concept.prerequisites = requiredArray<string>(concept.prerequisites, "prerequisites").map((id) => requiredID(id, "K"))
    unique(concept.prerequisites, "prerequisite")
    if (concept.prerequisites.some((id) => !conceptIDs.has(id) || id === concept.id)) throw new Error("invalid_prerequisite")
  }
  const fundamental = concepts.filter((item) => item.fundamental).length
  if (fundamental > Math.floor(concepts.length / 5)) throw new Error("fundamental_budget_exceeded")
  for (const module of modules) {
    requiredString(module.title, "module_title", 200)
    requiredString(module.win, "module_win", 500)
  }
  if ((event.target_language === undefined) !== (event.native_language === undefined)) throw new Error("language_pair_required")
  if (event.target_language !== undefined) requiredString(event.target_language, "target_language", 80)
  if (event.native_language !== undefined) requiredString(event.native_language, "native_language", 80)
  if (event.production_required !== undefined) requiredBoolean(event.production_required, "production_required")
  return {
    schema_version: STATE_VERSION,
    revision: 0,
    topic: {
      slug, title: event.title, materials_language: event.materials_language, goal: event.goal, status: "active",
      ...(event.target_language ? { target_language: event.target_language } : {}),
      ...(event.native_language ? { native_language: event.native_language } : {}),
      ...(event.production_required !== undefined ? { production_required: event.production_required } : {}),
    },
    concepts: concepts.map((item) => ({ ...structuredClone(item), learner_override: false, taught: false })),
    modules: modules.map((item) => ({ ...structuredClone(item), phase: "mission", taught_concept_ids: [], retention: { disposition: "pending", selected_card_ids: [] }, artifacts: {} })),
    cards: [], card_changes: [], review_events: [], language_units: [], vocabulary: { candidates: [], exports: [] }, gaps: [], jobs: [], artifacts: {}, applied_events: {}, consents: [], views: { revision: 0, status: "pending" },
  }
}

function parseEvent(value: unknown): LearningEvent {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("invalid_event")
  const event = structuredClone(value) as LearningEvent
  requiredString(event.type, "event_type", 80)
  const eventID = requiredString(event.event_id, "event_id", 100)
  if (!EVENT_ID.test(eventID)) throw new Error("invalid_event_id")
  requiredDate(event.date)
  return event
}

function applyLearningEvent(current: TopicState | undefined, slug: string, rawEvent: unknown, choice?: Choice): { state: TopicState; result: CommitResult } {
  const event = parseEvent(rawEvent)
  if (!current) {
    if (event.type !== "create_topic") throw new Error("topic_not_initialized")
    const state = initialState(slug, event)
    state.revision = 1
    state.applied_events[event.event_id] = eventDigest(event)
    state.views = { revision: state.revision, status: "pending" }
    requireValidState(state, slug)
    return { state, result: { duplicate: false, revision: state.revision, event_id: event.event_id, views: "pending", changed: ["state", "mission", "path"] } }
  }
  if (current.schema_version !== STATE_VERSION || current.topic.slug !== slug || !Number.isSafeInteger(current.revision)) throw new Error("state_malformed")
  const known = current.applied_events[event.event_id]
  if (known) {
    if (known !== eventDigest(event)) throw new Error("event_id_conflict")
    return { state: structuredClone(current), result: { duplicate: true, revision: current.revision, event_id: event.event_id, views: current.views.status, changed: [] } }
  }
  if (event.type === "create_topic") throw new Error("topic_already_initialized")
  const state = structuredClone(current)
  const changed = new Set<string>(["state"])
  const module = "module_id" in event ? state.modules.find((item) => item.id === event.module_id) : undefined
  const card = "card_id" in event ? state.cards.find((item) => item.id === event.card_id) : undefined
  if ("module_id" in event && !module) throw new Error("unknown_module")
  if ("card_id" in event && !card) throw new Error("unknown_card")

  switch (event.type) {
    case "record_class": {
      if (!module || !["mission", "class"].includes(module.phase)) throw new Error("invalid_phase_transition")
      if (module.retention.disposition === "selected") throw new Error("selected_cards_require_explicit_edit")
      event.taught_concept_ids = requiredArray<string>(event.taught_concept_ids, "taught_concepts").map((id) => requiredID(id, "K"))
      unique(event.taught_concept_ids, "taught_concept")
      if (event.taught_concept_ids.some((id) => !state.concepts.some((concept) => concept.id === id))) throw new Error("unknown_taught_concept")
      module.phase = "class"
      module.taught_concept_ids = event.taught_concept_ids
      module.class_evidence = requiredString(event.evidence, "class_evidence")
      delete module.artifacts.note
      if (module.retention.disposition === "pending") delete module.retention.preview
      for (const concept of state.concepts) if (event.taught_concept_ids.includes(concept.id)) concept.taught = true
      changed.add("mission"); changed.add("path")
      break
    }
    case "preview_cards": {
      if (!module || module.phase !== "class") throw new Error("preview_requires_class")
      if (module.retention.disposition === "selected") throw new Error("selected_cards_require_explicit_edit")
      requiredString(event.preview_id, "preview_id", 100)
      event.cards = requiredArray<Extract<LearningEvent, { type: "preview_cards" }>["cards"][number]>(event.cards, "card_preview", 2)
      if (event.source_revision !== current.revision) throw new Error("stale_source_revision")
      for (const proposal of event.cards) requiredRecord(proposal, "card_proposal")
      unique(event.cards.map((item) => item.proposal_id), "proposal_id")
      for (const proposal of event.cards) {
        requiredString(proposal.proposal_id, "proposal_id", 100)
        requiredString(proposal.cue, "cue", 1000); requiredString(proposal.answer, "answer", 4000); requiredString(proposal.reason, "reason", 500)
        requiredID(proposal.concept_id, "K")
        const concept = state.concepts.find((item) => item.id === proposal.concept_id)
        if (!concept?.taught || !concept.fundamental || !module.taught_concept_ids.includes(concept.id)) throw new Error("ineligible_card_concept")
      }
      const preview = { topic_slug: state.topic.slug, module_id: module.id, id: event.preview_id, source_revision: event.source_revision, cards: event.cards }
      module.retention = { disposition: "pending", preview: structuredClone({ ...preview, digest: digest(preview) }), selected_card_ids: [] }
      changed.add("path")
      break
    }
    case "select_cards": {
      if (!module?.retention.preview || module.retention.preview.id !== event.preview_id) throw new Error("unknown_card_preview")
      if (module.retention.disposition === "selected") throw new Error("selected_cards_require_explicit_edit")
      requiredEnum(event.disposition, "retention_disposition", ["selected", "none", "deferred"] as const)
      event.proposal_ids = requiredArray<string>(event.proposal_ids, "proposal_ids", 2).map((id) => requiredString(id, "proposal_id", 100))
      validateConsent(choice, "cards", event.interaction_id, event.disposition === "selected" ? event.proposal_ids : [event.disposition], storedSubject(module.retention.preview))
      if (choice!.input.revision !== current.revision) throw new Error("stale_interaction_revision")
      unique(event.proposal_ids, "proposal_id")
      if (event.disposition === "selected" && !event.proposal_ids.length) throw new Error("selected_cards_required")
      if (event.disposition !== "selected" && event.proposal_ids.length) throw new Error("unselected_cards_present")
      const proposals = event.proposal_ids.map((id) => module.retention.preview!.cards.find((item) => item.proposal_id === id))
      if (proposals.some((item) => !item)) throw new Error("unknown_card_proposal")
      const selected: string[] = []
      for (const proposal of proposals) {
        const id = `C-${String(state.cards.length + 1).padStart(4, "0")}`
        selected.push(id)
        state.cards.push({ id, cue: proposal!.cue, answer: proposal!.answer, concept_id: proposal!.concept_id, source_revision: module.retention.preview.source_revision, box: 1, last: event.date, next: recallCalcContracts.addDays(event.date, 1), status: "active", again_count: 0, lineage: [] })
      }
      module.retention.disposition = event.disposition
      module.retention.selected_card_ids = selected
      state.consents.push({ interaction_id: choice!.id, purpose: choice!.input.purpose, request_id: choice!.requestID!, digest: choice!.digest, selected: [...choice!.selected!] })
      changed.add("path"); changed.add("review-queue")
      break
    }
    case "start_practice": {
      if (!module || module.phase !== "class") throw new Error("practice_requires_class")
      validateConsent(choice, "readiness", event.interaction_id, ["ready"], { topic_slug: state.topic.slug, module_id: module.id })
      if (choice!.input.revision !== current.revision) throw new Error("stale_interaction_revision")
      module.phase = "practice"
      state.consents.push({ interaction_id: choice!.id, purpose: choice!.input.purpose, request_id: choice!.requestID!, digest: choice!.digest, selected: [...choice!.selected!] })
      changed.add("path")
      break
    }
    case "record_attempt": {
      if (!module || module.phase !== "practice") throw new Error("attempt_requires_practice")
      requiredEnum(event.outcome, "attempt_outcome", ["pending", "partial", "stuck", "done"] as const)
      if (event.causal_explanation !== undefined) requiredString(event.causal_explanation, "causal_explanation")
      if (event.transfer_evidence !== undefined) requiredString(event.transfer_evidence, "transfer_evidence")
      module.attempt = { revision: current.revision + 1, outcome: event.outcome, evidence: requiredString(event.evidence, "attempt_evidence"), ...(event.causal_explanation ? { causal_explanation: event.causal_explanation } : {}), ...(event.transfer_evidence ? { transfer_evidence: event.transfer_evidence } : {}) }
      if (event.outcome === "done") module.phase = "consolidation"
      changed.add("path")
      break
    }
    case "record_consolidation": {
      if (!module || module.phase !== "consolidation" || module.attempt?.outcome !== "done") throw new Error("consolidation_requires_completed_practice")
      event.blocking_gaps = requiredArray<string>(event.blocking_gaps, "blocking_gaps")
      module.consolidation = { revision: current.revision + 1, learner_evidence: requiredString(event.learner_evidence, "learner_evidence"), blocking_gaps: event.blocking_gaps.map((gap) => requiredString(gap, "gap", 1000)) }
      changed.add("path")
      break
    }
    case "close_module": {
      if (!module || module.phase !== "consolidation" || module.attempt?.outcome !== "done" || !module.consolidation || module.consolidation.blocking_gaps.length || module.retention.disposition === "pending") throw new Error("module_close_requirements_not_met")
      if (!state.topic.target_language) {
        const records = [module.artifacts.note, module.artifacts.exercise].map((path) => path ? state.artifacts[path] : undefined)
        if (records.some((record) => !record || record.source_revision < module.consolidation!.revision || record.module_id !== module.id || !record.selected_card_ids || !sameStrings(record.selected_card_ids, module.retention.selected_card_ids))) {
          throw new Error("module_artifacts_not_current")
        }
      }
      module.phase = "closed"
      changed.add("path")
      break
    }
    case "grade_card": {
      if (!card || card.status !== "active") throw new Error("card_not_active")
      requiredEnum(event.grade, "grade", ["Again", "Hard", "Good", "Easy"] as const)
      validateConsent(choice, "grade", event.interaction_id, [event.grade], { topic_slug: state.topic.slug, card_id: card.id })
      if (choice!.input.revision !== current.revision) throw new Error("stale_interaction_revision")
      if (event.grade === "Again" && card.again_count === 2) throw new Error("third_again_requires_repair_choice")
      const transition = recallCalcContracts.applyGrade(event.grade, card.box, event.date)
      card.box = transition.to_box!
      card.last = transition.last
      card.next = transition.next!
      if (event.grade === "Again") card.again_count += 1
      state.review_events.push({ event_id: event.event_id, card_id: card.id, date: event.date, grade: event.grade, evidence: requiredString(event.evidence, "review_evidence") })
      state.consents.push({ interaction_id: choice!.id, purpose: choice!.input.purpose, request_id: choice!.requestID!, digest: choice!.digest, selected: [...choice!.selected!] })
      changed.add("review-queue")
      break
    }
    case "preview_card_change": {
      if (!card || card.status !== "active" || event.source_revision !== current.revision) throw new Error("invalid_or_stale_card_change")
      requiredString(event.change_id, "change_id", 100)
      if (state.card_changes.some((item) => item.id === event.change_id && item.card_id !== card.id)) throw new Error("duplicate_card_change_id")
      requiredEnum(event.kind, "card_change_kind", ["edit", "reformulate", "split"] as const)
      event.replacements = requiredArray<Extract<LearningEvent, { type: "preview_card_change" }>["replacements"][number]>(event.replacements, "replacements", 2)
      if ((event.kind === "split" && event.replacements.length !== 2) || (event.kind !== "split" && event.replacements.length !== 1)) throw new Error("invalid_card_change_shape")
      if (event.kind !== "edit" && card.again_count !== 2) throw new Error("repair_requires_third_again")
      for (const replacement of event.replacements) {
        requiredRecord(replacement, "card_replacement")
        requiredString(replacement.cue, "cue", 1000)
        requiredString(replacement.answer, "answer", 4000)
      }
      const preview = { topic_slug: state.topic.slug, id: event.change_id, card_id: card.id, source_revision: event.source_revision, kind: event.kind, replacements: event.replacements }
      state.card_changes = state.card_changes.filter((item) => item.card_id !== card.id)
      state.card_changes.push(structuredClone({ ...preview, digest: digest(preview) }))
      changed.add("review-queue")
      break
    }
    case "apply_card_change": {
      if (!card || card.status !== "active") throw new Error("card_not_active")
      const preview = state.card_changes.find((item) => item.id === event.change_id && item.card_id === card.id)
      if (!preview || preview.source_revision + 1 !== current.revision) throw new Error("unknown_or_stale_card_change")
      const purpose = preview.kind === "edit" ? "cards" : "reformulation"
      validateConsent(choice, purpose, event.interaction_id, [preview.id], storedSubject(preview))
      if (choice!.input.revision !== current.revision) throw new Error("stale_interaction_revision")
      card.status = "retired"
      if (preview.kind !== "edit") {
        card.again_count = 3
        state.review_events.push({ event_id: event.event_id, card_id: card.id, date: event.date, grade: `Again+${preview.kind}`, evidence: preview.kind })
      }
      const replacementIDs: string[] = []
      for (const replacement of preview.replacements) {
        const id = `C-${String(state.cards.length + 1).padStart(4, "0")}`
        replacementIDs.push(id)
        state.cards.push({ id, cue: replacement.cue, answer: replacement.answer, concept_id: card.concept_id, source_revision: current.revision, box: 1, last: event.date, next: recallCalcContracts.addDays(event.date, 1), status: "active", again_count: 0, lineage: [...card.lineage, card.id] })
      }
      for (const item of state.modules) item.retention.selected_card_ids = item.retention.selected_card_ids.flatMap((selected) => selected === card.id ? replacementIDs : [selected])
      state.card_changes = state.card_changes.filter((item) => item.id !== preview.id)
      state.consents.push({ interaction_id: choice!.id, purpose: choice!.input.purpose, request_id: choice!.requestID!, digest: choice!.digest, selected: [...choice!.selected!] })
      changed.add("path"); changed.add("review-queue")
      break
    }
    case "set_card_status": {
      if (!card) throw new Error("unknown_card")
      requiredEnum(event.status, "card_status", ["active", "suspended", "retired"] as const)
      validateConsent(choice, "retirement", event.interaction_id, [event.status], { topic_slug: state.topic.slug, card_id: card.id })
      if (choice!.input.revision !== current.revision) throw new Error("stale_interaction_revision")
      card.status = event.status
      state.card_changes = state.card_changes.filter((item) => item.card_id !== card.id)
      state.consents.push({ interaction_id: choice!.id, purpose: choice!.input.purpose, request_id: choice!.requestID!, digest: choice!.digest, selected: [...choice!.selected!] })
      changed.add("review-queue")
      break
    }
    case "set_fundamental_override": {
      const concept = state.concepts.find((item) => item.id === event.concept_id)
      if (!concept?.taught) throw new Error("taught_concept_required")
      requiredBoolean(event.enabled, "override_enabled")
      validateConsent(choice, "override", event.interaction_id, [event.enabled ? "enable" : "disable"], { topic_slug: state.topic.slug, concept_id: concept.id })
      if (choice!.input.revision !== current.revision) throw new Error("stale_interaction_revision")
      concept.fundamental = event.enabled
      concept.learner_override = true
      for (const candidate of state.modules) {
        if (candidate.retention.disposition === "pending" && candidate.retention.preview?.cards.some((card) => card.concept_id === concept.id)) delete candidate.retention.preview
      }
      state.consents.push({ interaction_id: choice!.id, purpose: choice!.input.purpose, request_id: choice!.requestID!, digest: choice!.digest, selected: [...choice!.selected!] })
      changed.add("mission")
      break
    }
    case "add_language_unit": {
      if (!state.topic.target_language || !state.topic.native_language) throw new Error("language_topic_required")
      requiredID(event.unit_id, "L")
      if (state.language_units.some((item) => item.id === event.unit_id)) throw new Error("duplicate_language_unit")
      requiredDate(event.passive_at, "passive_at"); requiredDate(event.next_due, "next_due")
      if (event.next_due !== recallCalcContracts.addDays(event.passive_at, 3)) throw new Error("initial_language_due_must_be_three_days")
      state.language_units.push({ id: event.unit_id, passive_at: event.passive_at, next_due: event.next_due, situation: requiredString(event.situation, "situation"), target_text: requiredString(event.target_text, "target_text"), native_text: requiredString(event.native_text, "native_text"), status: "pending" })
      changed.add("path")
      break
    }
    case "record_language_attempt": {
      const unit = state.language_units.find((item) => item.id === event.unit_id)
      if (!unit) throw new Error("unknown_language_unit")
      requiredEnum(event.outcome, "language_outcome", ["needs-another-attempt", "completed", "input-only"] as const)
      if (event.date < unit.next_due && event.outcome !== "input-only") throw new Error("language_unit_not_due")
      unit.status = event.outcome
      unit.evidence = requiredString(event.evidence, "language_evidence")
      if (event.outcome === "needs-another-attempt") {
        if (!event.next_due || event.next_due <= event.date) throw new Error("valid_next_due_required")
        unit.next_due = requiredDate(event.next_due, "next_due")
      } else if (event.next_due !== undefined) throw new Error("unexpected_next_due")
      changed.add("path")
      break
    }
    case "set_vocab_candidates": {
      if (!state.topic.target_language) throw new Error("language_topic_required")
      event.candidates = requiredArray<Extract<LearningEvent, { type: "set_vocab_candidates" }>["candidates"][number]>(event.candidates, "vocab_candidates")
      for (const candidate of event.candidates) requiredRecord(candidate, "vocab_candidate")
      unique(event.candidates.map((item) => item.id), "candidate_id")
      for (const candidate of event.candidates) {
        requiredID(candidate.id, "V")
        const existing = state.vocabulary.candidates.find((item) => item.id === candidate.id)
        if (existing?.status === "exported") throw new Error("exported_candidate_immutable")
        const language = requiredString(candidate.target_language, "target_language", 80)
        const unit = requiredString(candidate.unit, "unit", 500)
        if (normalizeVocabKey(language, "") !== normalizeVocabKey(state.topic.target_language, "")) throw new Error("candidate_language_mismatch")
        const key = normalizeVocabKey(language, unit)
        const fields = requiredString(candidate.row, "vocab_row", 4000).split(";")
        if (fields.length !== 5 || fields.some((field) => !field || field.includes('"') || field.includes("\n"))) throw new Error("invalid_vocab_row")
        if (normalizeVocabKey(language, fields[0]) !== key) throw new Error("vocab_anchor_mismatch")
        const duplicate = state.vocabulary.candidates.find((item) => item.duplicate_key === key && item.id !== candidate.id)
        if (duplicate) {
          if (existing) throw new Error("candidate_key_conflict")
          continue
        }
        const updated = { id: candidate.id, target_language: language, unit, row: candidate.row, duplicate_key: key, status: "candidate" as const }
        if (existing) Object.assign(existing, updated)
        else state.vocabulary.candidates.push(updated)
      }
      changed.add("vocabulary")
      break
    }
    case "export_vocab": {
      event.candidate_ids = requiredArray<string>(event.candidate_ids, "candidate_ids").map((id) => requiredID(id, "V"))
      const preview = (choice?.input.options ?? []).filter((option) => /^V-\d{4}$/.test(option.id)).map((option) => {
        const candidate = state.vocabulary.candidates.find((item) => item.id === option.id && item.status === "candidate")
        if (!candidate) throw new Error("unknown_or_exported_candidate")
        const { id, target_language, unit, row } = candidate
        return { id, target_language, unit, row }
      })
      validateConsent(choice, "export", event.interaction_id, event.candidate_ids, { topic_slug: state.topic.slug, candidates: preview })
      if (choice!.input.revision !== current.revision) throw new Error("stale_interaction_revision")
      unique(event.candidate_ids, "candidate_id")
      if (!/^anki\/[a-z0-9][a-z0-9._-]*\.txt$/.test(event.batch_path)) throw new Error("invalid_batch_path")
      if (state.artifacts[event.batch_path] || state.vocabulary.exports.some((item) => item.path === event.batch_path)) throw new Error("batch_path_exists")
      const candidates = event.candidate_ids.map((id) => state.vocabulary.candidates.find((item) => item.id === id && item.status === "candidate"))
      if (!candidates.length || candidates.some((item) => !item)) throw new Error("unknown_or_exported_candidate")
      const batch = `${candidates.map((item) => item!.row).join("\n")}\n`
      if (batch.length > MAX_RESULT_CHARS) throw new Error("vocab_batch_too_large")
      for (const candidate of candidates) candidate!.status = "exported"
      state.vocabulary.exports.push({ event_id: event.event_id, path: event.batch_path, candidate_ids: event.candidate_ids, date: event.date })
      state.artifacts[event.batch_path] = { content: batch, source_revision: current.revision }
      state.consents.push({ interaction_id: choice!.id, purpose: choice!.input.purpose, request_id: choice!.requestID!, digest: choice!.digest, selected: [...choice!.selected!] })
      changed.add("vocabulary"); changed.add(event.batch_path)
      break
    }
    case "adopt_gap": {
      const gap = state.gaps.find((item) => item.id === event.gap_id)
      if (!gap) throw new Error("unknown_gap")
      requiredEnum(event.adoption, "gap_adoption", ["drill", "practice", "declined"] as const)
      validateConsent(choice, "gap", event.interaction_id, [event.adoption], { topic_slug: state.topic.slug, gap_id: gap.id })
      if (choice!.input.revision !== current.revision) throw new Error("stale_interaction_revision")
      gap.adoption = event.adoption
      state.consents.push({ interaction_id: choice!.id, purpose: choice!.input.purpose, request_id: choice!.requestID!, digest: choice!.digest, selected: [...choice!.selected!] })
      changed.add("gaps")
      break
    }
    case "record_gap": {
      if (!state.topic.target_language) throw new Error("language_topic_required")
      requiredID(event.gap_id, "G")
      const existing = state.gaps.find((item) => item.id === event.gap_id)
      event.occurrence_refs = requiredArray<string>(event.occurrence_refs, "gap_occurrences").map((item) => {
        const reference = requiredString(item, "gap_occurrence", 100)
        if (!EVENT_ID.test(reference)) throw new Error("invalid_gap_occurrence_ref")
        return reference
      })
      unique(event.occurrence_refs, "gap_occurrence")
      if (!event.occurrence_refs.length) throw new Error("gap_occurrence_required")
      if (existing) {
        if (existing.category !== event.category || existing.synthetic_pattern !== event.synthetic_pattern) throw new Error("gap_id_conflict")
        existing.occurrence_refs = [...new Set([...existing.occurrence_refs, ...event.occurrence_refs])]
      } else {
        state.gaps.push({ id: event.gap_id, category: requiredString(event.category, "gap_category", 100), synthetic_pattern: requiredString(event.synthetic_pattern, "synthetic_pattern", 500), occurrence_refs: event.occurrence_refs, adoption: "pending" })
      }
      changed.add("gaps")
      break
    }
    case "attach_artifact": {
      const content = requiredString(event.content, "artifact_content", MAX_RESULT_CHARS)
      if (!WRITER_ARTIFACT_PATH.test(event.path) || event.source_revision !== current.revision) throw new Error("invalid_or_stale_artifact")
      requiredString(event.job_id, "job_id", 100)
      const kind = artifactKind(event.path)
      let ownership: { module_id?: string; selected_card_ids?: string[] } = {}
      if (kind === "note" || kind === "exercise") {
        if (!module) throw new Error("module_artifact_owner_required")
        const selected = requiredArray<string>(event.selected_card_ids, "artifact_selected_card_ids").map((id) => requiredID(id, "C"))
        if (!sameStrings(selected, module.retention.selected_card_ids)) throw new Error("artifact_retention_mismatch")
        module.artifacts[kind] = event.path
        ownership = { module_id: module.id, selected_card_ids: selected }
        changed.add("path")
      } else if (kind === "teachback" && module) {
        module.artifacts.teachback = event.path
        ownership = { module_id: module.id }
        changed.add("path")
      } else if (event.module_id !== undefined || event.selected_card_ids !== undefined) {
        throw new Error("unexpected_artifact_ownership")
      }
      state.artifacts[event.path] = { content, source_revision: event.source_revision, job_id: event.job_id, ...ownership }
      changed.add(event.path)
      break
    }
    case "complete_topic": {
      if (state.topic.status === "completed") throw new Error("topic_already_completed")
      if (state.modules.some((item) => item.phase !== "closed")) throw new Error("topic_has_open_modules")
      if (state.topic.production_required && state.language_units.some((item) => item.status !== "completed")) throw new Error("language_production_criteria_pending")
      state.topic.completion = { date: event.date, event_id: event.event_id, evidence: requiredString(event.evidence, "completion_evidence") }
      state.topic.status = "completed"
      changed.add("mission")
      break
    }
    default:
      throw new Error("unsupported_event_type")
  }
  state.revision = current.revision + 1
  state.applied_events[event.event_id] = eventDigest(event)
  state.views = { revision: state.revision, status: "pending" }
  requireValidState(state, slug)
  return { state, result: { duplicate: false, revision: state.revision, event_id: event.event_id, views: "pending", changed: [...changed] } }
}

function questionFor(choice: Choice) {
  const exactSubject = choice.input.subject_json === undefined
    ? ""
    : `\n\nExact stored preview:\n${JSON.stringify(JSON.parse(choice.input.subject_json), null, 2)}`
  return {
    questions: [{
      header: `Learning ${choice.id.slice(0, 8)}`,
      question: `${choice.input.question}${exactSubject}`,
      options: choice.input.options.map(({ label, description }) => ({ label, description })),
      multiple: choice.input.multiple ?? false,
    }],
  }
}

// This ledger accepts only host hook/events, never a model-provided approval.
// It deliberately does not persist learner state; durable transitions layer on it.
function createInteractions() {
  const choices = new Map<string, Choice>()
  const active = new Map<string, string>()
  const requests = new Map<string, string>()

  function stage(context: ToolContext, input: ChoiceInput): Choice {
    requireTeacher(context)
    // The host validates plugin schemas without applying Zod defaults.
    input = { ...input, multiple: input.multiple ?? false }
    boundedText(input.question, MAX_INPUT_CHARS)
    if (!Number.isSafeInteger(input.revision) || input.revision < 0) throw new Error("invalid_revision")
    if (input.subject_json === undefined && input.subject_digest !== undefined) throw new Error("subject_json_required")
    if (input.subject_json !== undefined) {
      if (input.subject_json.length > MAX_INPUT_CHARS) throw new Error("invalid_subject_json")
      let subject: unknown
      try { subject = JSON.parse(input.subject_json) } catch { throw new Error("invalid_subject_json") }
      if (!subject || typeof subject !== "object" || Array.isArray(subject)) throw new Error("invalid_subject_json")
      const computed = digest(subject)
      if (input.subject_digest !== undefined && input.subject_digest !== computed) throw new Error("subject_digest_mismatch")
      input.subject_digest = computed
      input.subject_json = canonicalJSON(subject)
    }
    const ids = new Set(input.options.map((option) => option.id))
    const labels = new Set(input.options.map((option) => option.label))
    if (input.options.length < 1 || input.options.length > MAX_CHOICES || ids.size !== input.options.length || labels.size !== ids.size) {
      throw new Error("invalid_choice_options")
    }
    const existing = active.get(context.sessionID)
    if (existing) {
      const previous = choices.get(existing)!
      if (previous.status === "pending" && previous.digest === digest(input)) return previous
      if (previous.status === "pending") previous.status = "invalidated"
    }
    const pending = [...choices.values()].filter((item) => item.status === "pending").length
    if (pending >= MAX_RECORDS) throw new Error("interaction_limit_reached")
    const choice: Choice = {
      id: randomUUID(), sessionID: context.sessionID, sourceMessageID: context.messageID,
      input: structuredClone(input), digest: digest(input), status: "pending",
    }
    choices.set(choice.id, choice)
    active.set(context.sessionID, choice.id)
    return choice
  }

  function prepare(sessionID: string, callID: string, args: { questions?: { header?: string }[] }) {
    const id = active.get(sessionID)
    const choice = id ? choices.get(id) : undefined
    if (!choice || choice.status !== "pending") return
    if (args.questions?.[0]?.header !== questionFor(choice).questions[0].header) return
    if (choice.callID && choice.callID !== callID) throw new Error("interaction_already_shown")
    choice.callID = callID
    // Exact staged display replaces all model-authored wording at the host boundary.
    Object.assign(args, questionFor(choice))
  }

  function onEvent(event: { type: string; properties: any }): Choice | undefined {
    const data = event.properties
    if (event.type === "question.asked") {
      const id = active.get(data.sessionID)
      const choice = id ? choices.get(id) : undefined
      if (!choice || choice.status !== "pending" || !choice.callID || data.tool?.callID !== choice.callID) return
      const shown = data.questions?.map(({ question, header, options, multiple }: any) => ({ question, header, options, multiple: multiple ?? false }))
      if (digest(shown) !== digest(questionFor(choice).questions)) return
      if (choice.requestID && choice.requestID !== data.id) return
      choice.requestID = data.id
      requests.set(data.id, choice.id)
      return
    }
    if (event.type !== "question.replied" && event.type !== "question.rejected") return
    const id = requests.get(data.requestID)
    const choice = id ? choices.get(id) : undefined
    if (!choice || choice.sessionID !== data.sessionID || choice.status !== "pending") return
    if (event.type === "question.rejected") {
      choice.status = "dismissed"
      active.delete(choice.sessionID)
      requests.delete(data.requestID)
      return choice
    }
    if (!Array.isArray(data.answers) || data.answers.length !== 1 || !Array.isArray(data.answers[0])) return
    const answers: string[] = data.answers[0]
    const selected = choice.input.options.filter((option) => answers.includes(option.label)).map((option) => option.id)
    if (selected.length !== answers.length || new Set(answers).size !== answers.length || (!choice.input.multiple && selected.length !== 1)) return
    choice.selected = selected
    choice.status = "answered"
    active.delete(choice.sessionID)
    requests.delete(data.requestID)
    return choice
  }

  function get(sessionID: string, id: string) {
    const choice = choices.get(id)
    if (!choice || choice.sessionID !== sessionID) throw new Error("unknown_interaction")
    return structuredClone(choice)
  }

  function find(sessionID: string, id: string) {
    const choice = choices.get(id)
    return choice?.sessionID === sessionID ? structuredClone(choice) : undefined
  }

  function consume(sessionID: string, id: string) {
    const choice = choices.get(id)
    if (!choice || choice.sessionID !== sessionID) return
    choices.delete(id)
    if (choice.requestID) requests.delete(choice.requestID)
    if (active.get(sessionID) === id) active.delete(sessionID)
  }

  return { stage, prepare, onEvent, get, find, consume }
}

function choiceResponse(choice: Choice) {
  if (choice.status !== "pending") return choice
  if (choice.requestID) return { ...choice, next_action: "Wait for the displayed native question to be answered or dismissed. Do not poll." }
  return {
    id: choice.id, revision: choice.input.revision, digest: choice.digest, subject_digest: choice.input.subject_digest,
    status: "not_shown",
    next_action: "Call question now with next_args to open the native UI. Staging did not show a question. Do not poll learning_choice_result or ask the learner to click an interface that is not open.",
    next_tool: "question",
    next_args: questionFor(choice),
  }
}

function markdown(value: string) {
  return value.replaceAll("|", "\\|").replaceAll("\n", " ")
}

function renderViews(state: TopicState): Record<string, string> {
  const concepts = state.concepts.map((item) => `| ${item.id} | ${markdown(item.title)} | ${item.prerequisites.join(", ") || "none"} | ${item.fundamental ? "yes" : "no"} | ${item.learner_override ? "yes" : "no"} | ${item.taught ? "yes" : "no"} |`).join("\n")
  const modules = state.modules.map((item) => `| ${item.id} | ${markdown(item.title)} | ${markdown(item.win)} | ${item.phase} | ${item.artifacts.note ?? "—"} | ${item.artifacts.exercise ?? "—"} | ${item.retention.disposition} | ${item.retention.selected_card_ids.join(", ") || "[]"} |`).join("\n")
  const active = state.cards.filter((item) => item.status === "active").map((item) => `| ${item.id} | ${markdown(item.cue)} | ${item.box} | ${item.last} | ${item.next} | ${item.concept_id}@r${item.source_revision} |`).join("\n")
  const inactive = state.cards.filter((item) => item.status !== "active").map((item) => `| ${item.id} | ${markdown(item.cue)} | ${item.status} | ${item.last} | ${item.lineage.join(", ") || "—"} |`).join("\n")
  const candidates = state.vocabulary.candidates.map((item) => `| ${markdown(item.target_language)} | ${markdown(item.duplicate_key)} | ${markdown(item.unit)} | ${item.status} |`).join("\n")
  const gaps = state.gaps.map((item) => `| ${item.id} | ${markdown(item.category)} | ${markdown(item.synthetic_pattern)} | ${item.occurrence_refs.length} | ${item.adoption} |`).join("\n")
  const language = state.language_units.map((item) => `| ${item.id} | ${item.passive_at} | ${item.next_due} | ${item.status} | ${markdown(item.situation)} |`).join("\n")
  const completion = state.topic.completion
  const completionRecord = completion ? `\n## Completion\n\nDate: ${completion.date} · Event: ${completion.event_id}\n\n${completion.evidence}\n` : ""
  return {
    "mission.md": `# Mission — ${state.topic.title}\n\n> Status: ${state.topic.status} · Materials language: ${state.topic.materials_language}\n\n## Observable goal\n\n${state.topic.goal}\n\n## Concepts\n\n| ID | Concept | Prerequisites | Fundamental | Learner override | Taught |\n| --- | --- | --- | --- | --- | --- |\n${concepts}\n${completionRecord}`,
    "path.md": `# Learning Path — ${state.topic.title}\n\n> State revision: ${state.revision}\n\n## Modules\n\n| ID | Module | Tangible win | Phase | Note | Exercise | Retention | Selected cards |\n| --- | --- | --- | --- | --- | --- | --- | --- |\n${modules}\n${language ? `\n## Language units\n\n| ID | Passive at | Next due | Status | Situation |\n| --- | --- | --- | --- | --- |\n${language}\n` : ""}`,
    "review-queue.md": `# Review Queue — ${state.topic.title}\n\n> State revision: ${state.revision}. Box 5 remains on 30-day maintenance until explicit suspension or retirement.\n\n## Queue\n\n| ID | Cue | Box | Last | Next | Source |\n| --- | --- | --- | --- | --- | --- |\n${active}\n\n## Suspended / retired\n\n| ID | Cue | Status | Last | Lineage |\n| --- | --- | --- | --- | --- |\n${inactive}\n`,
    "vocabulary.md": `# Vocabulary — ${state.topic.title}\n\n> Candidates and exports are distinct. Export status does not prove Anki import.\n\n| Target language | Duplicate key | Unit | Status |\n| --- | --- | --- | --- |\n${candidates}\n`,
    "gaps.md": `# Synthetic gaps — ${state.topic.title}\n\n> No raw corrections. Adoption and card admission are separate choices.\n\n| ID | Category | Synthetic pattern | Distinct occurrences | Adoption |\n| --- | --- | --- | --- | --- |\n${gaps}\n`,
    ...Object.fromEntries(Object.entries(state.artifacts).map(([path, artifact]) => [path, artifact.content])),
  }
}

async function writeAtomic(path: string, content: string) {
  await mkdir(dirname(path), { recursive: true })
  const temporary = `${path}.${randomUUID()}.tmp`
  let handle: Awaited<ReturnType<typeof open>> | undefined
  try {
    handle = await open(temporary, "wx", 0o600)
    await handle.writeFile(content, "utf8")
    await handle.sync()
    await handle.close()
    handle = undefined
    await rename(temporary, path)
  } catch (error) {
    await handle?.close().catch(() => undefined)
    await unlink(temporary).catch(() => undefined)
    throw error
  }
}

async function processIsAlive(pid: number) {
  try {
    process.kill(pid, 0)
    return true
  } catch (error: any) {
    return error?.code === "EPERM"
  }
}

function createStateStore(directory: string) {
  let workspace: string | undefined

  async function learningRoot() {
    if (!workspace) workspace = await realpath(directory)
    const root = join(workspace, ".ai", "learning")
    await mkdir(root, { recursive: true, mode: 0o700 })
    const canonical = await realpath(root)
    const part = relative(workspace, canonical)
    if (!part || part === ".." || part.startsWith(`..${sep}`) || isAbsolute(part)) throw new Error("learning_root_outside_workspace")
    return canonical
  }

  async function topicRoot(slug: string, create = false) {
    if (!TOPIC_SLUG.test(slug) || slug === "summaries") throw new Error("invalid_topic_slug")
    const root = await learningRoot()
    const target = join(root, slug)
    if (create) await mkdir(target, { recursive: true, mode: 0o700 })
    const canonical = await realpath(target).catch(() => undefined)
    if (!canonical) return undefined
    const part = relative(root, canonical)
    if (!part || part === ".." || part.startsWith(`..${sep}`) || isAbsolute(part)) throw new Error("topic_outside_learning_root")
    return canonical
  }

  async function readState(slug: string): Promise<TopicState | undefined> {
    const root = await topicRoot(slug)
    if (!root) return undefined
    const path = join(root, ".state.json")
    let canonical: string
    try {
      canonical = await realpath(path)
    } catch (error: any) {
      if (error?.code === "ENOENT") {
        const entries = (await readdir(root)).filter((entry) => entry !== ".state.lock")
        if (entries.length) throw new Error("unsupported_existing_topic_without_state")
        return undefined
      }
      throw error
    }
    const part = relative(root, canonical)
    if (part !== ".state.json" || isAbsolute(part)) throw new Error("state_file_outside_topic")
    let source: string
    const handle = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW).catch((error: any) => {
      if (error?.code === "ELOOP") throw new Error("state_file_symlink")
      throw error
    })
    try {
      const metadata = await handle.stat()
      if (!metadata.isFile()) throw new Error("state_file_not_regular")
      if (metadata.size > MAX_STATE_BYTES) throw new Error("state_too_large")
      source = await handle.readFile("utf8")
    } finally {
      await handle.close()
    }
    let state: TopicState
    try { state = JSON.parse(source) } catch { throw new Error("state_malformed_json") }
    if (!validStoredState(state, slug)) throw new Error("state_malformed")
    return state
  }

  async function acquire(root: string) {
    const lockPath = join(root, ".state.lock")
    for (let attempt = 0; attempt < 2; attempt++) {
      const token = randomUUID()
      try {
        const handle = await open(lockPath, "wx", 0o600)
        await handle.writeFile(JSON.stringify({ pid: process.pid, token, acquired_at: new Date().toISOString() }), "utf8")
        await handle.sync()
        return async () => {
          await handle.close()
          try {
            const stored = JSON.parse(await readFile(lockPath, "utf8"))
            if (stored.token === token) await unlink(lockPath)
          } catch { /* Never remove a lock we cannot prove is ours. */ }
        }
      } catch (error: any) {
        if (error?.code !== "EEXIST" || attempt > 0) throw new Error("topic_busy")
        let stored: { pid: number; token: string }
        try {
          stored = JSON.parse(await readFile(lockPath, "utf8"))
          if (!Number.isInteger(stored.pid) || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(stored.token)) throw new Error("invalid_lock")
        } catch { throw new Error("ambiguous_topic_lock") }
        if (await processIsAlive(stored.pid)) throw new Error("topic_busy")
        const claimPath = `${lockPath}.reclaim-${stored.token}`
        let claim: Awaited<ReturnType<typeof open>>
        try {
          claim = await open(claimPath, "wx", 0o600)
        } catch (claimError: any) {
          if (claimError?.code === "EEXIST") throw new Error("topic_busy")
          throw claimError
        }
        try {
          await claim.writeFile(JSON.stringify({ pid: process.pid, stale_token: stored.token }), "utf8")
          await claim.sync()
          const current = JSON.parse(await readFile(lockPath, "utf8"))
          if (current.pid !== stored.pid || current.token !== stored.token || await processIsAlive(current.pid)) throw new Error("topic_busy")
          await unlink(lockPath)
        } finally {
          await claim.close().catch(() => undefined)
          await unlink(claimPath).catch(() => undefined)
        }
      }
    }
    throw new Error("topic_busy")
  }

  async function writeState(root: string, state: TopicState) {
    const source = `${JSON.stringify(state, null, 2)}\n`
    if (Buffer.byteLength(source, "utf8") > MAX_STATE_BYTES) throw new Error("state_too_large")
    await writeAtomic(join(root, ".state.json"), source)
  }

  async function generate(root: string, state: TopicState) {
    for (const [relativePath, content] of Object.entries(renderViews(state))) {
      if (!["mission.md", "path.md", "review-queue.md", "vocabulary.md", "gaps.md"].includes(relativePath) && !ARTIFACT_PATH.test(relativePath)) throw new Error("invalid_view_path")
      const target = resolve(root, relativePath)
      const part = relative(root, target)
      if (!part || part === ".." || part.startsWith(`..${sep}`) || isAbsolute(part)) throw new Error("view_outside_topic")
      await mkdir(dirname(target), { recursive: true, mode: 0o700 })
      const parent = await realpath(dirname(target))
      const parentPart = relative(root, parent)
      if (parentPart === ".." || parentPart.startsWith(`..${sep}`) || isAbsolute(parentPart)) throw new Error("view_parent_outside_topic")
      await writeAtomic(target, content)
    }
    state.views = { revision: state.revision, status: "current" }
    await writeState(root, state)
  }

  async function commit(slug: string, expectedRevision: number, rawEvent: unknown, choice?: Choice): Promise<CommitResult> {
    const root = await topicRoot(slug, true)
    if (!root) throw new Error("topic_directory_unavailable")
    const release = await acquire(root)
    try {
      const current = await readState(slug)
      const event = parseEvent(rawEvent)
      const known = current?.applied_events[event.event_id]
      if (!known && expectedRevision !== (current?.revision ?? 0)) throw new Error(`revision_conflict:expected=${expectedRevision}:actual=${current?.revision ?? 0}`)
      const applied = applyLearningEvent(current, slug, event, choice)
      if (applied.result.duplicate) {
        if (applied.state.views.status === "pending") await generate(root, applied.state)
        return { ...applied.result, views: applied.state.views.status }
      }
      await writeState(root, applied.state)
      try {
        await generate(root, applied.state)
        applied.result.views = "current"
      } catch (error: any) {
        applied.state.views = { revision: applied.state.revision, status: "pending", error: String(error?.message ?? error) }
        await writeState(root, applied.state)
      }
      return applied.result
    } finally {
      await release()
    }
  }

  async function recover(slug: string) {
    const root = await topicRoot(slug)
    if (!root) throw new Error("unknown_topic")
    const release = await acquire(root)
    try {
      const state = await readState(slug)
      if (!state) throw new Error("topic_not_initialized")
      await generate(root, state)
      return { revision: state.revision, views: state.views.status }
    } finally { await release() }
  }

  async function read(slug: string) {
    const state = await readState(slug)
    if (!state) throw new Error("unknown_topic")
    return structuredClone(state)
  }

  async function syncJob(job: Job) {
    if (!TOPIC_SLUG.test(job.scope) || job.scope === "summaries") return
    const root = await topicRoot(job.scope)
    if (!root) throw new Error("job_topic_not_initialized")
    const release = await acquire(root)
    try {
      const state = await readState(job.scope)
      if (!state) throw new Error("job_topic_not_initialized")
      if (job.revision > state.revision) throw new Error("job_source_revision_ahead")
      const record = {
        id: job.id, parent_id: job.parentID, worker: job.worker, source_revision: job.revision, status: job.status,
        ...(job.result ? { result_digest: digest(job.result) } : {}), ...(job.error ? { error: job.error } : {}),
        ...(job.supersededRevision !== undefined ? { superseded_revision: job.supersededRevision } : {}),
      }
      const index = state.jobs.findIndex((item) => item.id === job.id)
      if (index >= 0) state.jobs[index] = record
      else state.jobs.push(record)
      await writeState(root, state)
    } finally { await release() }
  }

  return { read, commit, recover, syncJob, root: learningRoot }
}

function createJobs(client: Parameters<Plugin>[0]["client"], onChange: (job: Job) => Promise<void> = async () => undefined) {
  const jobs = new Map<string, Job>()
  const launching = new Set<string>()
  const available = ["create", "promptAsync", "messages", "status", "abort"].every((name) => typeof (client.session as any)?.[name] === "function")

  function ownerKey(parentID: string, worker: Worker, scope: string) {
    const topicScoped = TOPIC_SLUG.test(scope) && scope !== "summaries"
    return topicScoped ? `topic:${scope}:${worker}` : `parent:${parentID}:${scope}:${worker}`
  }

  async function sync(job: Job) {
    const priorSyncError = job.error === "job_state_sync_failed; inspect the accepted child before replacement"
    if (priorSyncError) delete job.error
    try {
      await onChange(job)
    } catch {
      if (priorSyncError || !job.error) job.error = "job_state_sync_failed; inspect the accepted child before replacement"
    }
  }

  function get(parentID: string, id: string) {
    const job = jobs.get(id)
    if (!job || job.parentID !== parentID) throw new Error("unknown_learning_job")
    return job
  }

  function restore(record: TopicState["jobs"][number], scope: string) {
    const existing = jobs.get(record.id)
    if (existing) return existing
    const job: Job = { id: record.id, parentID: record.parent_id, worker: record.worker, scope, revision: record.source_revision, status: record.status, notified: false, ...(record.error ? { error: record.error } : {}), ...(record.superseded_revision !== undefined ? { supersededRevision: record.superseded_revision } : {}) }
    jobs.set(job.id, job)
    return job
  }

  async function launch(context: ToolContext, input: { worker: Worker; scope: string; revision: number; prompt: string }) {
    requireTeacher(context)
    if (!available) throw new Error("async_session_api_unavailable")
    boundedText(input.prompt, MAX_INPUT_CHARS)
    const key = ownerKey(context.sessionID, input.worker, input.scope)
    const existing = [...jobs.values()].find((job) => ownerKey(job.parentID, job.worker, job.scope) === key && ["starting", "running", "cancelling"].includes(job.status))
    if (existing) {
      if (input.revision > existing.revision) {
        existing.supersededRevision = Math.max(existing.supersededRevision ?? input.revision, input.revision)
        await sync(existing)
        return structuredClone(existing)
      }
      throw new Error(`learning_job_pending:${existing.id}`)
    }
    if (launching.has(key)) throw new Error("learning_job_starting")
    if (jobs.size >= MAX_RECORDS) throw new Error("job_limit_reached")
    launching.add(key)
    try {
      const agents = await client.app.agents({ throwOnError: true })
      const worker = agents.data?.find((agent) => agent.name === input.worker)
      if (!worker) throw new Error(`learning_worker_unavailable:${input.worker}`)
      const parentMessage = await client.session.message({ path: { id: context.sessionID, messageID: context.messageID }, throwOnError: true })
      const parent = parentMessage.data?.info
      if (!parent || parent.role !== "assistant") throw new Error("assistant_context_required")
      const body = {
        parentID: context.sessionID, title: `${input.worker}: ${input.scope}`,
        permission: [{ permission: "edit", pattern: "*", action: "deny" }, { permission: "bash", pattern: "*", action: "deny" }, { permission: "task", pattern: "*", action: "deny" }],
      }
      const created = await client.session.create({ body, throwOnError: true })
      if (!created.data?.id) throw new Error("child_session_not_created")
      const job: Job = { id: created.data.id, parentID: context.sessionID, worker: input.worker, scope: input.scope, revision: input.revision, status: "starting", notified: false }
      jobs.set(job.id, job)
      try {
        await client.session.promptAsync({ path: { id: job.id }, body: {
          agent: input.worker,
          model: worker.model ?? { providerID: parent.providerID, modelID: parent.modelID },
          parts: [{ type: "text", text: input.prompt }],
        }, throwOnError: true })
        if (job.status === "starting") job.status = "running"
      } catch {
        // A lost HTTP response does not prove that the prompt was rejected.
        job.error = "launch_observation_failed; inspect the existing child before replacement"
      }
      await sync(job)
      return structuredClone(job)
    } finally {
      launching.delete(key)
    }
  }

  async function inspect(job: Job) {
    if (["failed", "cancelled"].includes(job.status) || (job.status === "completed" && job.result !== undefined)) return structuredClone(job)
    const messages = await client.session.messages({ path: { id: job.id }, throwOnError: true })
    const prompt = messages.data?.find((message) => message.info.role === "user")
    if (prompt) job.promptMessageID = prompt.info.id
    const final = messages.data?.findLast((message) => message.info.role === "assistant" && message.info.parentID === job.promptMessageID && message.info.time.completed && (message.info.error || (message.info.finish && message.info.finish !== "tool-calls")))
    const statuses = await client.session.status({ throwOnError: true })
    // Another lifecycle callback may have settled this job while reads awaited.
    if (["failed", "cancelled"].includes(job.status) || (job.status === "completed" && job.result !== undefined)) return structuredClone(job)
    const live = statuses.data?.[job.id]
    if (live && live.type !== "idle") return structuredClone(job)
    if (final?.info.role === "assistant") {
      if (job.status === "cancelling") job.status = "cancelled"
      else if (final.info.error) { job.status = "failed"; job.error = final.info.error.name }
      else {
        const text = final.parts.filter((part) => part.type === "text").map((part) => part.type === "text" ? part.text : "").join("\n")
        if (text.length > MAX_RESULT_CHARS) { job.status = "failed"; job.error = "worker_result_too_large" }
        else { job.status = "completed"; job.result = text }
      }
    } else if (job.status === "cancelling") job.status = "cancelled"
    // Absence from the busy map alone is not proof of successful completion.
    await sync(job)
    return structuredClone(job)
  }

  async function cancel(parentID: string, id: string) {
    const job = get(parentID, id)
    if (["completed", "failed", "cancelled"].includes(job.status)) return structuredClone(job)
    job.status = "cancelling"
    await client.session.abort({ path: { id: job.id }, throwOnError: true })
    return inspect(job)
  }

  async function onEvent(event: { type: string; properties: any }) {
    const job = jobs.get(event.properties?.sessionID)
    if (!job || !["session.idle", "session.error", "session.status"].includes(event.type)) return
    if (event.type === "session.status" && event.properties.status?.type !== "idle") return
    try {
      await inspect(job)
    } catch { /* An observation error leaves the accepted child pending. */ }
  }

  function notices(parentID: string) {
    const settled = [...jobs.values()].filter((job) => job.parentID === parentID && !job.notified && ["completed", "failed", "cancelled"].includes(job.status))
    for (const job of settled) job.notified = true
    return settled.map((job) => ({ id: job.id, worker: job.worker, scope: job.scope, revision: job.revision, status: job.status }))
  }

  return {
    available, launch,
    inspect: (parentID: string, id: string) => inspect(get(parentID, id)),
    inspectAny: (id: string) => {
      const job = jobs.get(id)
      if (!job) throw new Error("unknown_learning_job")
      return inspect(job)
    },
    cancel,
    cancelAny: async (id: string) => {
      const job = jobs.get(id)
      if (!job) throw new Error("unknown_learning_job")
      return cancel(job.parentID, id)
    },
    onEvent, notices, restore,
  }
}

export const learningRuntimeContracts = { createInteractions, createJobs, applyLearningEvent, createStateStore, renderViews, normalizeVocabKey }

export const LearningRuntimePlugin: Plugin = async ({ client, directory }) => {
  const tool = await recallCalcHost.loadTool(directory)
  const schema = tool.schema
  const interactions = createInteractions()
  const state = createStateStore(directory)
  const jobs = createJobs(client, (job) => state.syncJob(job))
  const consumedSummaries = new Set<string>()
  return {
    tool: {
      learning_context: tool({
        description: "Learning date and installed deterministic capabilities.",
        args: {},
        async execute() {
          return JSON.stringify({ today: recallCalcContracts.localToday(), calculator: true, async_sessions: jobs.available, interactions: "host_question_events", durable_state: true, state_schema: STATE_VERSION, existing_markdown_supported: false })
        },
      }),
      learning_event_reference: tool({
        description: "Return the complete validated payload and exact consent-subject contract for one Learning event, or the full event catalog when omitted. Read-only.",
        args: { event_type: schema.enum(EVENT_TYPES).optional() },
        async execute({ event_type }, context) {
          requireTeacher(context)
          return JSON.stringify({
            base_rules: ["Every event requires type, unique EVENT_ID event_id, and local YYYY-MM-DD date.", "Use the current state revision as expected_revision.", "For consent events, fill the consent_subject placeholders with exact current IDs and pass it as subject_json to learning_choice. The runtime canonicalizes it and returns its SHA-256; when state already supplies a digest, pass that digest too."],
            events: event_type ? { [event_type]: EVENT_REFERENCE[event_type] } : EVENT_REFERENCE,
          }, null, 2)
        },
      }),
      learning_state_read: tool({
        description: "Read the authoritative versioned state for one Learning topic. Existing Markdown without state is unsupported.",
        args: { topic_slug: schema.string().regex(TOPIC_SLUG) },
        async execute({ topic_slug }, context) {
          requireTeacher(context)
          return JSON.stringify(await state.read(topic_slug), null, 2)
        },
      }),
      learning_commit: tool({
        description: "Apply one event from learning_event_reference at an expected revision, validate the resulting snapshot, atomically replace state, then regenerate views.",
        args: {
          topic_slug: schema.string().regex(TOPIC_SLUG),
          expected_revision: schema.number().int().nonnegative(),
          event: schema.object({ type: schema.string(), event_id: schema.string().min(1).max(100), date: schema.string() }).passthrough(),
        },
        async execute({ topic_slug, expected_revision, event }, context) {
          requireTeacher(context)
          const parsed = parseEvent(event)
          const interactionID = "interaction_id" in parsed ? parsed.interaction_id : undefined
          const choice = interactionID ? interactions.find(context.sessionID, interactionID) : undefined
          if (parsed.type === "attach_artifact") {
            const snapshot = await state.read(topic_slug)
            const record = snapshot.jobs.find((item) => item.id === parsed.job_id)
            if (!record) throw new Error("job_not_owned_by_topic")
            jobs.restore(record, topic_slug)
            const job = await jobs.inspectAny(parsed.job_id)
            if (job.worker !== "learning-writer" || job.scope !== topic_slug || job.status !== "completed" || job.revision !== parsed.source_revision || !job.result) throw new Error("unsettled_or_stale_writer")
            let output: any
            try { output = JSON.parse(job.result) } catch { throw new Error("malformed_writer_result") }
            const content = output.content ?? output.markdown
            const destination = output.destination_hint ?? output.path
            const kind = artifactKind(parsed.path)
            if (output.kind !== kind || output.source_revision !== parsed.source_revision || destination !== parsed.path || content !== parsed.content) throw new Error("writer_result_mismatch")
            if (output.module_id !== parsed.module_id) throw new Error("writer_owner_mismatch")
            if (kind === "note" || kind === "exercise") {
              const outputCards = requiredArray<string>(output.selected_card_ids, "writer_selected_card_ids")
              if (!parsed.selected_card_ids || !sameStrings(outputCards, parsed.selected_card_ids)) throw new Error("writer_retention_mismatch")
            } else if (output.selected_card_ids !== undefined) throw new Error("unexpected_writer_retention")
          }
          const result = await state.commit(topic_slug, expected_revision, parsed, choice)
          if (interactionID && !result.duplicate) interactions.consume(context.sessionID, interactionID)
          return JSON.stringify(result, null, 2)
        },
      }),
      learning_recover: tool({
        description: "Regenerate missing or stale Markdown views from committed state. It never reapplies a logical event.",
        args: { topic_slug: schema.string().regex(TOPIC_SLUG) },
        async execute({ topic_slug }, context) {
          requireTeacher(context)
          return JSON.stringify(await state.recover(topic_slug), null, 2)
        },
      }),
      learning_due: tool({
        description: "Return active cards and language units due on a supplied date, including finite-course tail units. Read-only.",
        args: { topic_slug: schema.string().regex(TOPIC_SLUG), today: schema.string() },
        async execute({ topic_slug, today }, context) {
          requireTeacher(context)
          requiredDate(today, "today")
          const snapshot = await state.read(topic_slug)
          const cards = snapshot.cards.filter((item) => item.status === "active" && item.next <= today).sort((a, b) => a.next.localeCompare(b.next) || a.id.localeCompare(b.id))
          const language_units = snapshot.language_units.filter((item) => ["pending", "needs-another-attempt", "input-only"].includes(item.status) && item.next_due <= today).sort((a, b) => a.next_due.localeCompare(b.next_due) || a.id.localeCompare(b.id))
          const next_dates = [...snapshot.cards.filter((item) => item.status === "active").map((item) => item.next), ...snapshot.language_units.filter((item) => ["pending", "needs-another-attempt", "input-only"].includes(item.status)).map((item) => item.next_due)].filter((date) => date > today).sort()
          return JSON.stringify({ revision: snapshot.revision, today, cards, language_units, next_upcoming: next_dates[0] ?? null }, null, 2)
        },
      }),
      learning_choice: tool({
        description: "Prepare a closed choice; this does NOT open any UI. Immediately call the native question tool using returned next_args, then read learning_choice_result after it returns. No files change.",
        args: {
          purpose: schema.enum(PURPOSES), revision: schema.number().int().nonnegative(),
          subject_digest: schema.string().regex(/^[a-f0-9]{64}$/).optional().describe("Optional asserted digest; required only when the stored subject already supplies one"),
          subject_json: schema.string().max(MAX_INPUT_CHARS).optional().describe("Exact structured subject displayed and bound to the choice; the runtime canonicalizes and hashes it"),
          question: schema.string().min(1).max(MAX_INPUT_CHARS),
          options: schema.array(schema.object({ id: schema.string().min(1).max(80), label: schema.string().min(1).max(80), description: schema.string().max(1000) })).min(1).max(MAX_CHOICES),
          multiple: schema.boolean().default(false),
        },
        async execute(input, context) {
          const choice = interactions.stage(context, input)
          return JSON.stringify(choiceResponse(choice))
        },
      }),
      learning_choice_result: tool({
        description: "Read the host-correlated selection after question returns. If not_shown, call question with next_args immediately; polling cannot open the UI or record chat replies.",
        args: { id: schema.string().uuid() },
        async execute({ id }, context) {
          requireTeacher(context)
          return JSON.stringify(choiceResponse(interactions.get(context.sessionID, id)))
        },
      }),
      learning_job_start: tool({
        description: "Launch bounded independent research or composition. Returns the accepted child ID immediately; no synthetic parent turn on completion.",
        args: {
          worker: schema.enum(WORKERS), scope: schema.string().min(1).max(100), revision: schema.number().int().nonnegative(),
          prompt: schema.string().min(1).max(MAX_INPUT_CHARS),
        },
        async execute(input, context) {
          if (input.worker === "learning-summarizer" && input.scope !== "summaries") throw new Error("summarizer_scope_required")
          if (input.worker === "learning-writer" && (!TOPIC_SLUG.test(input.scope) || input.scope === "summaries")) throw new Error("writer_topic_scope_required")
          if (input.worker === "learning-researcher" && input.scope === "summaries") throw new Error("researcher_scope_invalid")
          if (input.worker === "learning-researcher" && !TOPIC_SLUG.test(input.scope) && !SESSION_SCOPE.test(input.scope)) throw new Error("researcher_scope_invalid")
          if (TOPIC_SLUG.test(input.scope) && input.scope !== "summaries") {
            const snapshot = await state.read(input.scope)
            if (snapshot.revision !== input.revision) throw new Error("stale_worker_source_revision")
            const recorded = snapshot.jobs.find((item) => item.worker === input.worker && ["starting", "running", "cancelling"].includes(item.status))
            if (recorded) {
              const restored = jobs.restore(recorded, input.scope)
              const inspected = await jobs.inspectAny(restored.id)
              if (["starting", "running", "cancelling"].includes(inspected.status) && input.revision <= inspected.revision) throw new Error(`learning_job_pending:${inspected.id}`)
            }
          }
          return JSON.stringify(await jobs.launch(context, input))
        },
      }),
      learning_job_result: tool({
        description: "Read one accepted worker on a normal learner turn, or cancel it and verify settlement. Observation failure never permits replacement.",
        args: { id: schema.string(), action: schema.enum(["inspect", "cancel"]), topic_slug: schema.string().regex(TOPIC_SLUG).optional() },
        async execute({ id, action, topic_slug }, context) {
          requireTeacher(context)
          if (topic_slug) {
            const snapshot = await state.read(topic_slug)
            const record = snapshot.jobs.find((item) => item.id === id)
            if (!record) throw new Error("job_not_owned_by_topic")
            jobs.restore(record, topic_slug)
            return JSON.stringify(await (action === "cancel" ? jobs.cancelAny(id) : jobs.inspectAny(id)))
          }
          return JSON.stringify(await (action === "cancel" ? jobs.cancel(context.sessionID, id) : jobs.inspect(context.sessionID, id)))
        },
      }),
      learning_summary_create: tool({
        description: "Exclusively create one explicitly approved standalone summary from a settled summarizer result.",
        args: { job_id: schema.string(), interaction_id: schema.string().uuid() },
        async execute({ job_id, interaction_id }, context) {
          requireTeacher(context)
          if (consumedSummaries.has(interaction_id)) throw new Error("summary_interaction_already_used")
          const choice = interactions.get(context.sessionID, interaction_id)
          validateConsent(choice, "summary", interaction_id, ["save"], { scope: "summaries" })
          consumedSummaries.add(interaction_id)
          let target: string | undefined
          try {
            const job = await jobs.inspect(context.sessionID, job_id)
            if (job.worker !== "learning-summarizer" || job.scope !== "summaries" || job.status !== "completed" || !job.result) throw new Error("settled_summary_job_required")
            let output: any
            try { output = JSON.parse(job.result) } catch { throw new Error("malformed_summary_result") }
            if (output.kind !== "summary") throw new Error("invalid_summary_kind")
            const title = requiredString(output.title, "summary_title", 200)
            requiredString(output.language, "summary_language", 80)
            const content = requiredString(output.markdown, "summary_markdown", MAX_RESULT_CHARS)
            const root = await state.root()
            const summariesPath = join(root, "summaries")
            await mkdir(summariesPath, { recursive: true, mode: 0o700 })
            const summaries = await realpath(summariesPath)
            const summariesPart = relative(root, summaries)
            if (!summariesPart || summariesPart === ".." || summariesPart.startsWith(`..${sep}`) || isAbsolute(summariesPart)) throw new Error("summary_root_outside_learning")
            const now = new Date()
            const timestamp = `${recallCalcContracts.localToday(now)}-${String(now.getHours()).padStart(2, "0")}${String(now.getMinutes()).padStart(2, "0")}${String(now.getSeconds()).padStart(2, "0")}`
            const filename = `${timestamp}-${slugText(title)}-${randomUUID().slice(0, 8)}.md`
            target = join(summaries, filename)
            const handle = await open(target, "wx", 0o600)
            try { await handle.writeFile(content, "utf8"); await handle.sync() } finally { await handle.close() }
            interactions.consume(context.sessionID, interaction_id)
            return JSON.stringify({ status: "created", path: `.ai/learning/summaries/${filename}`, interaction_id, job_id })
          } catch (error) {
            if (target) await unlink(target).catch(() => undefined)
            consumedSummaries.delete(interaction_id)
            throw error
          }
        },
      }),
    },
    "tool.execute.before": async (input, output) => {
      if (input.tool === "question") interactions.prepare(input.sessionID, input.callID, output.args)
    },
    event: async ({ event }) => {
      interactions.onEvent(event)
      await jobs.onEvent(event)
    },
    "chat.message": async (input, output) => {
      if (!output.parts.some((part) => part.type === "text" && !part.synthetic && !part.ignored)) return
      const notices = jobs.notices(input.sessionID)
      if (!notices.length) return
      const first = output.parts[0]
      output.parts.push({
        id: `prt_${randomUUID().replaceAll("-", "")}`, sessionID: input.sessionID, messageID: first.messageID,
        type: "text", synthetic: true,
        text: `Learning worker state (not a learner answer; no progression or saved-artifact claim): ${JSON.stringify(notices)}`,
      })
    },
  }
}

export default { id: PLUGIN_ID, server: LearningRuntimePlugin }
