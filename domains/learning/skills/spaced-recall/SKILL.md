---
name: spaced-recall
description: "Trigger: spaced repetition, review queue, repaso espaciado, repeticion espaciada, learn review. Review supplied cards with learner-selected grades and deterministic scheduling proposals."
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.0.0"
---

# Spaced Recall

## Activation

Review explicitly supplied cards with retrieval and learner-selected grades, or calculate proposed scheduling. Ungraded practice never changes a schedule.

## Inputs

Cards with cue and expected answer or an explicit answer source; optional queue, actual review history, and trustworthy current date. Answers need not come from Cornell notes. No directory discovery is required. Missing persistence does not prevent inline review.

## Method

Use an available deterministic calculator for due lists and dates. Report malformed or ambiguous queues before claiming no reviews are due; preserve all affected IDs. Without the calculator, review inline and label scheduling unsaved/unavailable; never invent dates or perform arithmetic for durable mutations.

Offer due review before new material; the learner may decline. Use manageable chunks, initially up to 15, mixing related or confusable concepts when useful. Ask one cue in normal chat and wait before revealing its expected answer.

Compare the actual attempt with the supplied rubric. Recommend `Again` for no recall, `Hard` for substantial missing understanding, `Good` for correct recall, or `Easy` for fluent correct recall; explain the evidence briefly. The learner chooses the grade explicitly. Do not recommend Good unconditionally.

Policy: new/Again → box 1; Hard → same box; Good → +1; Easy → +2, capped at 5. Intervals are 1, 3, 7, 14, 30 days. Successful box-5 cards remain in 30-day maintenance until explicit suspension/retirement.

Track cumulative Again failures since creation or last agreed reformulation from supplied history. At the third, reteach and offer reformulation or splitting; preview revised content before acceptance. Preserve history/lineage and never reuse retired IDs. A quiz or diagnostic gap can propose a review action but cannot grade a card automatically.

## Output

Return attempts, evidence-based recommendations, actual selected grades, repair proposals, and calculator-produced transitions when available. Clearly distinguish proposed/unsaved results from confirmed commits. No automatic card admission, sibling calls, task launches, or file writes. `assets/review-queue-template.md` is an optional presentation format.
