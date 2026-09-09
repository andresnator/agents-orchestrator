import assert from "node:assert/strict"
import { test } from "node:test"
import { learningRuntimeContracts } from "./learning-runtime.ts"

const MODULE_ID = "M-0001"
const PREVIEW_ID = "RETENTION-RECOVERY"
const REVISION = 7

function topicState(phase, disposition = "pending", preview) {
  return {
    schema_version: 1,
    revision: REVISION,
    topic: { slug: "retention-recovery", title: "Retention recovery", materials_language: "English", goal: "Recover a missing preview", status: "active" },
    concepts: [{ id: "K-0001", title: "Recovery", prerequisites: [], fundamental: true, learner_override: false, taught: true }],
    modules: [{
      id: MODULE_ID,
      title: "Recovery module",
      win: "Recover retention",
      phase,
      taught_concept_ids: ["K-0001"],
      class_evidence: "Class completed",
      attempt: { revision: 5, outcome: "done", evidence: "Practice completed" },
      consolidation: { revision: 6, learner_evidence: "Consolidated", blocking_gaps: [] },
      retention: { disposition, ...(preview ? { preview } : {}), selected_card_ids: [] },
      artifacts: { note: "notes/m-0001.md", exercise: "exercises/m-0001.md" },
    }],
    cards: [], card_changes: [], review_events: [], language_units: [],
    vocabulary: { candidates: [], exports: [] }, gaps: [], jobs: [], artifacts: {},
    applied_events: {}, consents: [], views: { revision: REVISION, status: "current" },
  }
}

function previewEvent() {
  return {
    type: "preview_cards",
    event_id: "TEST-RETENTION-RECOVERY",
    date: "2026-09-09",
    module_id: MODULE_ID,
    preview_id: PREVIEW_ID,
    source_revision: REVISION,
    cards: [],
  }
}

for (const phase of ["practice", "consolidation"]) {
  test(`shouldPreserveModuleEvidenceWhenRecoveringMissingPreviewIn${phase}`, () => {
    // Given
    const current = topicState(phase)
    const before = structuredClone(current)

    // When
    const { state } = learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, previewEvent())
    const updated = state.modules[0]

    // Then
    assert.deepEqual(current, before)
    assert.deepEqual({ ...updated, retention: before.modules[0].retention }, before.modules[0])
    assert.equal(updated.retention.preview.id, PREVIEW_ID)
    assert.equal(updated.retention.disposition, "pending")
  })
}

for (const phase of ["mission", "closed"]) {
  test(`shouldRejectPreviewWhenModuleIs${phase}`, () => {
    // Given
    const current = topicState(phase)

    // When / Then
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, previewEvent()), /preview_requires_class/)
  })
}

for (const disposition of ["none", "deferred", "selected"]) {
  test(`shouldRejectLatePreviewWhenRetentionIs${disposition}`, () => {
    // Given
    const current = topicState("consolidation", disposition)

    // When / Then
    assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, previewEvent()), /preview_requires_class/)
  })
}

test("shouldRejectLateReplacementWhenPreviewAlreadyExists", () => {
  // Given
  const existingPreview = { topic_slug: "retention-recovery", module_id: MODULE_ID, id: "EXISTING", source_revision: REVISION, digest: "digest", cards: [] }
  const current = topicState("consolidation", "pending", existingPreview)

  // When / Then
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, previewEvent()), /preview_requires_class/)
})

test("shouldStillRejectClosureWhenRetentionIsPending", () => {
  // Given
  const current = topicState("consolidation")
  const event = { type: "close_module", event_id: "TEST-CLOSE", date: "2026-09-09", module_id: MODULE_ID }

  // When / Then
  assert.throws(() => learningRuntimeContracts.applyLearningEvent(current, current.topic.slug, event), /module_close_requirements_not_met/)
})
