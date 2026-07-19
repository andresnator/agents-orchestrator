import assert from "node:assert/strict"
import { RecallCalcPlugin, recallCalcContracts } from "../domains/learning/plugins/recall-calc.ts"

const { BOX_INTERVAL_DAYS, MAX_BOX, isIsoDate, addDays, localToday, parseQueue, dueReport, applyGrade } =
  recallCalcContracts

let passed = 0

function pass(name: string): void {
  passed += 1
  console.log(`ok - ${name}`)
}

const QUEUE_FIXTURE = `# Review Queue — Spring Security

> Boxes: 1→+1d · 2→+3d · 3→+7d · 4→+14d · 5→+30d
> Grades: Again→box 1 · Hard→same box · Good→box+1 · Easy→box+2 (max 5) · Good/Easy at box 5 → Mastered

## Queue

| ID | Cue | Box | Last | Next | Note |
| --- | --- | --- | --- | --- | --- |
| C-0001 | What does the filter chain decide per request? | 2 | 2026-07-10 | 2026-07-13 | \`notes/0001-filter-chain.md\` |
| C-0002 | ⚠ leech Why is CSRF disabled for stateless APIs? | 1 | 2026-07-17 | 2026-07-18 | \`notes/0001-filter-chain.md\` |
| C-0003 | Which bean owns authentication decisions? | 4 | 2026-07-05 | 2026-07-19 | \`notes/0002-auth-manager.md\` |
| C-9999 | Row with an impossible box | 7 | 2026-07-01 | 2026-07-02 | \`notes/bad.md\` |
| X-0004 | Row with a foreign id | 2 | 2026-07-01 | 2026-07-04 | \`notes/bad.md\` |
| C-0005 | Row with an impossible date | 2 | 2026-07-01 | 2026-02-30 | \`notes/bad.md\` |

## Mastered

| ID | Cue | Mastered on | Note |
| --- | --- | --- | --- |
| C-0000 | What is a servlet filter? | 2026-06-30 | \`notes/0000-servlets.md\` |
`

function shouldValidateIsoDates(): void {
  assert.equal(isIsoDate("2026-07-18"), true)
  assert.equal(isIsoDate("2028-02-29"), true)
  assert.equal(isIsoDate("2026-02-30"), false)
  assert.equal(isIsoDate("2026-13-01"), false)
  assert.equal(isIsoDate("2026-1-01"), false)
  assert.equal(isIsoDate("not-a-date"), false)
  pass("shouldValidateIsoDates")
}

function shouldAddDaysAcrossMonthAndYearBoundaries(): void {
  assert.equal(addDays("2026-01-31", 1), "2026-02-01")
  assert.equal(addDays("2026-07-18", 14), "2026-08-01")
  assert.equal(addDays("2026-11-30", 3), "2026-12-03")
  assert.equal(addDays("2026-12-31", 30), "2027-01-30")
  assert.equal(addDays("2028-02-28", 1), "2028-02-29")
  assert.equal(addDays("2027-02-28", 1), "2027-03-01")
  assert.throws(() => addDays("2026-02-30", 1), /invalid date/)
  pass("shouldAddDaysAcrossMonthAndYearBoundaries")
}

function shouldFormatLocalToday(): void {
  assert.match(localToday(), /^\d{4}-\d{2}-\d{2}$/)
  assert.equal(localToday(new Date(2026, 6, 18, 23, 59)), "2026-07-18")
  pass("shouldFormatLocalToday")
}

function shouldParseQueueRowsAndReportMalformedOnes(): void {
  const parsed = parseQueue(QUEUE_FIXTURE)
  assert.deepEqual(
    parsed.cards.map((card) => card.id),
    ["C-0001", "C-0002", "C-0003"],
  )
  assert.deepEqual(parsed.cards[0], {
    id: "C-0001",
    cue: "What does the filter chain decide per request?",
    box: 2,
    last: "2026-07-10",
    next: "2026-07-13",
    note: "`notes/0001-filter-chain.md`",
  })
  assert.equal(parsed.malformed.length, 3)
  assert.match(parsed.malformed[0], /box must be an integer 1-5/)
  assert.match(parsed.malformed[1], /bad card id "X-0004"/)
  assert.match(parsed.malformed[2], /bad Next date "2026-02-30"/)
  pass("shouldParseQueueRowsAndReportMalformedOnes")
}

function shouldExcludeMasteredSectionFromSchedule(): void {
  const parsed = parseQueue(QUEUE_FIXTURE)
  assert.equal(parsed.cards.some((card) => card.id === "C-0000"), false)
  assert.equal(parsed.malformed.some((row) => row.includes("C-0000")), false)
  pass("shouldExcludeMasteredSectionFromSchedule")
}

function shouldReportDueCardsOldestFirstWithUpcomingDate(): void {
  const report = dueReport(parseQueue(QUEUE_FIXTURE), "2026-07-18")
  assert.equal(report.scheduled, 3)
  assert.equal(report.due_count, 2)
  assert.deepEqual(
    report.due.map((card) => card.id),
    ["C-0001", "C-0002"],
  )
  assert.equal(report.next_upcoming, "2026-07-19")
  assert.equal(report.malformed.length, 3)
  const quiet = dueReport(parseQueue(QUEUE_FIXTURE), "2026-07-12")
  assert.equal(quiet.due_count, 0)
  assert.equal(quiet.next_upcoming, "2026-07-13")
  const drained = dueReport(parseQueue(QUEUE_FIXTURE), "2026-07-19")
  assert.equal(drained.due_count, 3)
  assert.equal(drained.next_upcoming, null)
  assert.throws(() => dueReport(parseQueue(QUEUE_FIXTURE), "18/07/2026"), /invalid today/)
  pass("shouldReportDueCardsOldestFirstWithUpcomingDate")
}

function shouldApplyLeitnerTransitions(): void {
  const today = "2026-07-18"
  assert.deepEqual(applyGrade("New", undefined, today), {
    grade: "New",
    from_box: null,
    to_box: 1,
    mastered: false,
    last: today,
    next: "2026-07-19",
  })
  assert.deepEqual(applyGrade("Again", 4, today), {
    grade: "Again",
    from_box: 4,
    to_box: 1,
    mastered: false,
    last: today,
    next: "2026-07-19",
  })
  assert.deepEqual(applyGrade("Hard", 3, today), {
    grade: "Hard",
    from_box: 3,
    to_box: 3,
    mastered: false,
    last: today,
    next: "2026-07-25",
  })
  assert.deepEqual(applyGrade("Good", 2, today), {
    grade: "Good",
    from_box: 2,
    to_box: 3,
    mastered: false,
    last: today,
    next: "2026-07-25",
  })
  assert.deepEqual(applyGrade("Easy", 2, today), {
    grade: "Easy",
    from_box: 2,
    to_box: 4,
    mastered: false,
    last: today,
    next: "2026-08-01",
  })
  assert.deepEqual(applyGrade("Easy", 4, today), {
    grade: "Easy",
    from_box: 4,
    to_box: 5,
    mastered: false,
    last: today,
    next: "2026-08-17",
  })
  assert.deepEqual(applyGrade("Good", 4, today), {
    grade: "Good",
    from_box: 4,
    to_box: 5,
    mastered: false,
    last: today,
    next: "2026-08-17",
  })
  pass("shouldApplyLeitnerTransitions")
}

function shouldMasterAtBoxFiveOnGoodOrEasy(): void {
  const today = "2026-07-18"
  for (const grade of ["Good", "Easy"] as const) {
    const transition = applyGrade(grade, MAX_BOX, today)
    assert.equal(transition.mastered, true)
    assert.equal(transition.to_box, null)
    assert.equal(transition.next, null)
    assert.equal(transition.last, today)
  }
  const hardAtFive = applyGrade("Hard", MAX_BOX, today)
  assert.equal(hardAtFive.mastered, false)
  assert.equal(hardAtFive.to_box, MAX_BOX)
  assert.equal(hardAtFive.next, addDays(today, BOX_INTERVAL_DAYS[MAX_BOX]))
  pass("shouldMasterAtBoxFiveOnGoodOrEasy")
}

function shouldRejectInvalidScheduleInput(): void {
  assert.throws(() => applyGrade("Good", undefined, "2026-07-18"), /box must be an integer 1-5/)
  assert.throws(() => applyGrade("Good", 0, "2026-07-18"), /box must be an integer 1-5/)
  assert.throws(() => applyGrade("Good", 6, "2026-07-18"), /box must be an integer 1-5/)
  assert.throws(() => applyGrade("Good", 3, "2026-02-30"), /invalid today/)
  pass("shouldRejectInvalidScheduleInput")
}

function shouldExposeThePluginEntrypoint(): void {
  assert.equal(typeof RecallCalcPlugin, "function")
  pass("shouldExposeThePluginEntrypoint")
}

shouldValidateIsoDates()
shouldAddDaysAcrossMonthAndYearBoundaries()
shouldFormatLocalToday()
shouldParseQueueRowsAndReportMalformedOnes()
shouldExcludeMasteredSectionFromSchedule()
shouldReportDueCardsOldestFirstWithUpcomingDate()
shouldApplyLeitnerTransitions()
shouldMasterAtBoxFiveOnGoodOrEasy()
shouldRejectInvalidScheduleInput()
shouldExposeThePluginEntrypoint()

console.log(`recall-calc contracts: ${passed} checks passed`)
