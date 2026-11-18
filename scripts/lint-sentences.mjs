#!/usr/bin/env node
// Fail when a sentence in a Markdown file has more than 25 words.
// Usage: lint-sentences.mjs [path...]   (no path: the default file set below)
// Exit: 0 no long sentence, 1 one or more long sentences, 2 a path cannot be read.
//
// Rules (few on purpose; a false positive is acceptable, a false negative is not):
// - Skipped: YAML frontmatter at the top, fenced code blocks, heading lines.
// - Text units: a paragraph is one text. Each list item is its own text; its
//   continuation lines belong to it. Each table cell is its own text. A blank
//   line, a heading, a fence, a list marker, or a table row ends the text.
// - Words: a word is text between spaces that has a letter or a digit. Thus
//   `|`, `->`, and `...` alone are not words. An inline code span is one word,
//   with the text that touches it. A URL and a Markdown link target have no
//   space, so each is one word or part of the word before it.
// - Sentence end: a word that ends with `.`, `!`, or `?`. Closing quotes,
//   brackets, and emphasis marks can follow the mark. A dot inside a word
//   (`SKILL.md`, `1.0.0`) or inside a code span does not end a sentence.
// - Abbreviations: `e.g.`, `i.e.`, `etc.`, and `vs.` do not end a sentence.
// - A colon does not end a sentence. Text without an end mark is one sentence.
// - The reported line is the line of the first word of the sentence.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const MAX_WORDS = 25;
const PREVIEW_WORDS = 8;
const ABBREVIATIONS = new Set(["e.g.", "i.e.", "etc.", "vs."]);
const TOKEN = /(?:`[^`]*`|[^\s`])+/g;
const SENTENCE_END = /[.!?][)\]"'*_”’]*$/;
const LIST_MARKER = /^\s*(?:[-*+]|\d+[.)])\s+/;

const withoutCode = (token) => token.replace(/`[^`]*`/g, "x");
const isWord = (token) => /[\p{L}\p{N}]/u.test(withoutCode(token));

function endsSentence(token) {
  const plain = withoutCode(token);
  const bare = plain.toLowerCase().replace(/^[^a-z]+|[^a-z.]+$/g, "");
  return SENTENCE_END.test(plain) && !ABBREVIATIONS.has(bare);
}

// Split a table row on `|`, but not inside a code span and not on `\|`.
function tableCells(row) {
  const cells = [""];
  let inCode = false;
  for (let i = 0; i < row.length; i += 1) {
    const char = row[i];
    if (char === "`") inCode = !inCode;
    if (char === "\\" && row[i + 1] === "|") {
      cells[cells.length - 1] += "\\|";
      i += 1;
    } else if (char === "|" && !inCode) {
      cells.push("");
    } else {
      cells[cells.length - 1] += char;
    }
  }
  return cells;
}

// Return one { line, words, preview } for each sentence over the maximum.
export function lintText(text) {
  const violations = [];
  let sentence = [];
  let startLine = 0;

  const closeSentence = () => {
    if (sentence.length > MAX_WORDS) {
      violations.push({
        line: startLine,
        words: sentence.length,
        preview: sentence.slice(0, PREVIEW_WORDS).join(" "),
      });
    }
    sentence = [];
  };
  const addText = (part, line) => {
    for (const token of part.match(TOKEN) ?? []) {
      if (!isWord(token)) continue;
      if (sentence.length === 0) startLine = line;
      sentence.push(token);
      if (endsSentence(token)) closeSentence();
    }
  };

  const lines = text.split(/\r?\n/);
  let index = 0;
  if (lines[0]?.trim() === "---") {
    const end = lines.indexOf("---", 1);
    if (end > 0) index = end + 1;
  }
  let fence = null;
  for (; index < lines.length; index += 1) {
    const lineNumber = index + 1;
    const line = lines[index].replace(/^\s*(?:>\s?)+/, "");
    const fenceMark = line.match(/^\s*(```|~~~)/)?.[1];
    if (fence) {
      if (fenceMark === fence) fence = null;
      continue;
    }
    if (fenceMark) {
      closeSentence();
      fence = fenceMark;
    } else if (line.trim() === "" || /^\s*#{1,6}\s/.test(line)) {
      closeSentence();
    } else if (line.trimStart().startsWith("|")) {
      closeSentence();
      for (const cell of tableCells(line)) {
        addText(cell, lineNumber);
        closeSentence();
      }
    } else if (LIST_MARKER.test(line)) {
      closeSentence();
      addText(line.replace(LIST_MARKER, ""), lineNumber);
    } else {
      addText(line, lineNumber);
    }
  }
  closeSentence();
  return violations;
}

const markdownIn = (dir) =>
  existsSync(dir)
    ? readdirSync(dir).filter((name) => name.endsWith(".md")).sort().map((name) => join(dir, name))
    : [];

// The default file set. `skills/*/assets` holds templates and examples: not checked.
export function defaultFiles(root) {
  const files = ["AGENTS.md", "README.md", "CONTRIBUTING.md"]
    .map((name) => join(root, name))
    .filter((file) => existsSync(file));
  for (const dir of ["agents", "commands", "global", "docs", "standards"]) {
    files.push(...markdownIn(join(root, dir)));
  }
  const skills = join(root, "skills");
  for (const skill of existsSync(skills) ? readdirSync(skills).sort() : []) {
    const body = join(skills, skill, "SKILL.md");
    if (existsSync(body)) files.push(body);
    files.push(...markdownIn(join(skills, skill, "references")));
  }
  return files;
}

function main(args) {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
  const files = args.length > 0 ? args : defaultFiles(root).map((file) => relative(process.cwd(), file));
  let total = 0;
  let filesWithViolations = 0;
  for (const file of files) {
    let text;
    try {
      text = readFileSync(file, "utf8");
    } catch (error) {
      console.error(`lint-sentences: cannot read ${file}: ${error.code ?? error.message}`);
      return 2;
    }
    const violations = lintText(text);
    for (const { line, words, preview } of violations) {
      console.log(`${file}:${line}: ${words} words (max ${MAX_WORDS}): ${preview}...`);
    }
    total += violations.length;
    if (violations.length > 0) filesWithViolations += 1;
  }
  if (total === 0) return 0;
  console.log(`lint-sentences: ${total} sentence(s) over ${MAX_WORDS} words in ${filesWithViolations} file(s).`);
  return 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
