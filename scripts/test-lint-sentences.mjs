import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { lintText } from "./lint-sentences.mjs";

const script = new URL("./lint-sentences.mjs", import.meta.url).pathname;

// Literal sentences; the word counts are in the names.
const WORDS_25 =
  "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty w21 w22 w23 w24 w25.";
const WORDS_26 =
  "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty w21 w22 w23 w24 w25 w26.";
const WORDS_13 = "one two three four five six seven eight nine ten eleven twelve thirteen";

function runOn(t, text) {
  const dir = mkdtempSync(join(tmpdir(), "lint-sentences-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const file = join(dir, "sample.md");
  writeFileSync(file, text);
  return { file, result: spawnSync(process.execPath, [script, file], { encoding: "utf8" }) };
}

test("shouldReportSentenceWhenItHas26Words", () => {
  const violations = lintText(`${WORDS_26}\n`);
  assert.deepEqual(violations, [
    { line: 1, words: 26, preview: "one two three four five six seven eight" },
  ]);
});

test("shouldPassWhenSentenceHas25Words", () => {
  assert.deepEqual(lintText(`${WORDS_25}\n`), []);
});

test("shouldPassWhenTextIsEmpty", () => {
  assert.deepEqual(lintText(""), []);
});

test("shouldCountSentencesSeparatelyWhenAnEndMarkSplitsThem", () => {
  const text = `${WORDS_13}. ${WORDS_13}! ${WORDS_13}? ${WORDS_13}.\n`;
  assert.deepEqual(lintText(text), []);
});

test("shouldReportParagraphWhenWrappedLinesTogetherExceedTheMaximum", () => {
  const violations = lintText(`${WORDS_13}\n${WORDS_13}.\n`);
  assert.equal(violations.length, 1);
  assert.equal(violations[0].words, 26);
});

test("shouldSkipFrontmatterWhenFileStartsWithIt", () => {
  const text = `---\ndescription: ${WORDS_26}\n---\n\nShort body.\n`;
  assert.deepEqual(lintText(text), []);
});

test("shouldSkipFencedCodeBlockWhenItHoldsALongLine", () => {
  const text = `Before.\n\n\`\`\`text\n${WORDS_26}\n\`\`\`\n\nAfter.\n`;
  assert.deepEqual(lintText(text), []);
});

test("shouldSkipHeadingWhenItIsLong", () => {
  assert.deepEqual(lintText(`## ${WORDS_26}\n`), []);
});

test("shouldNotJoinTextAcrossAHeading", () => {
  const text = `${WORDS_13}\n## Title\n${WORDS_13}\n`;
  assert.deepEqual(lintText(text), []);
});

test("shouldCheckEachTableCellSeparatelyWhenRowTotalExceedsTheMaximum", () => {
  const text = `| A | B |\n| --- | --- |\n| ${WORDS_13} | ${WORDS_13} |\n`;
  assert.deepEqual(lintText(text), []);
});

test("shouldReportTableCellWhenOneCellHas26Words", () => {
  const text = `| A | B |\n| --- | --- |\n| Short. | ${WORDS_26} |\n`;
  const violations = lintText(text);
  assert.equal(violations.length, 1);
  assert.equal(violations[0].line, 3);
  assert.equal(violations[0].words, 26);
});

test("shouldCheckEachListItemSeparatelyWhenItemsHaveNoEndMark", () => {
  const text = `- ${WORDS_13}\n- ${WORDS_13}\n1. ${WORDS_13}\n2. ${WORDS_13}\n`;
  assert.deepEqual(lintText(text), []);
});

test("shouldJoinContinuationLineToItsListItem", () => {
  const violations = lintText(`- ${WORDS_13}\n  ${WORDS_13}.\n`);
  assert.equal(violations.length, 1);
  assert.equal(violations[0].words, 26);
});

test("shouldCountCodeSpanAsOneWordWhenItHasSpacesAndDots", () => {
  // 25 words + one code span = 26.
  const text = WORDS_26.replace("w26.", "`git push -u origin. main now`.");
  assert.deepEqual(lintText(`${text}\n`).map((v) => v.words), [26]);
});

test("shouldCountUrlAndLinkTargetAsOneWordEach", () => {
  // 24 words + one URL + one link whose text is one word = 26.
  const text = WORDS_26.replace("w25 w26.", "https://example.com/a.b/c?d=e [guide](docs/guide.md).");
  assert.deepEqual(lintText(`${text}\n`).map((v) => v.words), [26]);
});

test("shouldNotEndSentenceWhenDotIsInAFileNameOrAbbreviation", () => {
  // No valid end before the last word, so all 26 words are one sentence.
  const text = WORDS_26.replace("three four", "SKILL.md e.g. i.e. etc. vs.").replace(" w23 w24 w25", "");
  const violations = lintText(`${text}\n`);
  assert.equal(violations.length, 1);
  assert.equal(violations[0].words, 26);
});

test("shouldNotCountSymbolsWithoutLettersOrDigitsAsWords", () => {
  const text = WORDS_25.replace("two", "-> two | ... —");
  assert.deepEqual(lintText(`${text}\n`), []);
});

test("shouldReportTheLineOfTheFirstWordWhenSentenceStartsMidFile", () => {
  const text = `---\nname: x\n---\n# Title\n\nShort one. ${WORDS_13}\n${WORDS_13}.\n`;
  const violations = lintText(text);
  assert.deepEqual(violations, [
    { line: 6, words: 26, preview: "one two three four five six seven eight" },
  ]);
});

test("shouldExitOneAndPrintLocationWhenFileHasALongSentence", (t) => {
  const { file, result } = runOn(t, `Short.\n\n${WORDS_26}\n`);
  assert.equal(result.status, 1);
  assert.equal(
    result.stdout,
    `${file}:3: 26 words (max 25): one two three four five six seven eight...\n` +
      "lint-sentences: 1 sentence(s) over 25 words in 1 file(s).\n",
  );
});

test("shouldExitZeroAndPrintNothingWhenFileHasNoLongSentence", (t) => {
  const { result } = runOn(t, `${WORDS_25}\n`);
  assert.equal(result.status, 0);
  assert.equal(result.stdout, "");
});

test("shouldExitTwoWhenPathCannotBeRead", () => {
  const result = spawnSync(process.execPath, [script, "/nonexistent/missing.md"], { encoding: "utf8" });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /cannot read \/nonexistent\/missing\.md/);
});
