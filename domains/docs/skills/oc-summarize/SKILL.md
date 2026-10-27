---
name: oc-summarize
description: |
  Expert in pedagogical book chapter synthesis. Use this skill WHENEVER the user wants to summarize a book chapter, analyze text or document content, study a chapter, extract key ideas from a reading, or when they mention words like "summary", "chapter", "book", "analyze this text", "summarize this", "cornell", "TL;DR" of long-form content. Also trigger when the user uploads a PDF, EPUB, or document and asks to understand or study it in parts.
  También se activa en castellano: "resumen", "resumen del capítulo", "resumir esto",
  "resumir el capítulo", "analizar este texto", "capítulo", "libro", "ideas clave",
  "resumen del libro", "estudiar el capítulo", "síntesis", "notas cornell",
  "extraer ideas principales", "dame un resumen", "qué dice este capítulo",
  "resumir documento", "analizar lectura".
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.1.0"
---

# Book Chapter Summary

## Intent

- **Goal:** A detailed, didactic chapter summary that builds deep reader comprehension, saved as a local `.md` file when file-writing is available.
- **Limits:**
  - Order is fixed: read the chapter, generate the summary, save the local `.md`, then optionally publish. **Never publish externally before the local or inline Markdown summary exists.**
  - Publish to a knowledge base only when the user requested or configured it and the environment provides that capability; never assume a specific MCP, tool name, workspace, or page exists.
- **Fails if:** the summary is written before reading the entire chapter, sections are missing or out of order, the file ignores `assets/chapter-summary-template.md`, or no file was written while file-writing was available.

## Context

- **Reads:** the full chapter (pasted text, PDF/EPUB, or reference); `assets/chapter-summary-template.md`; for PDFs over 20 pages, text extracted with `scripts/extract_pdf_pages.py`.
- **Never reads:** none.
- **Persona:** expert in content synthesis and pedagogy — didactic, clear, professional, like a good teacher who wants students to understand; explain technical terms on first use and favor the learning curve over erudition.
- **Scope:** summarizing or studying a book chapter, analyzing a text or document, extracting key ideas, Cornell notes, or a TL;DR of long-form content, including uploaded PDF/EPUB/documents (English and Spanish triggers in the description).

## Expectations

- **Scenarios:**
  - WHEN book and chapter, save path, or publishing preference are missing THEN ask for them in a single message before starting (save path defaults to the current working directory; publishing only if available).
  - WHEN file-writing is unavailable THEN return the complete Markdown inline and say no file was created.
  - WHEN publishing is requested and available THEN publish from the saved `.md` (if no file exists, use the generated Markdown content) and show only the TL;DR, file path, and link/identifier in chat (full summary only if asked).
  - WHEN publishing is not available THEN show the full summary in chat and say: *"The summary was saved at `[path/file.md]`. Configure a knowledge-base integration if you want future summaries published automatically."*
  - WHEN summarizing a book chapter by chapter THEN keep one folder per book (for example `refactoring-fowler/chapter-01-code-smell.md`) and you may offer: *"Would you like to continue with the next chapter?"*
- **Done means:** a file named `chapter-NN-short-title.md` (lowercase, hyphenated, e.g. `chapter-07-basic-refactoring.md`) built from the template with YAML frontmatter (book, chapter, author, date) and all sections in order, and the full path confirmed to the user (or confirmation that it was returned inline).
- **Quality needs:** identify main ideas, technical concepts, supporting arguments, and author examples, explaining each in accessible language without losing rigor; simple examples for abstract concepts; a Java code-block example for programming concepts.

## Method

### Summary structure (always in this order)

1. `# [Descriptive Title]` — captures the chapter's essence; improve a generic original title.
2. `## Key Questions (Cornell Method)` — 5-8 study questions: key concepts (What is X? How does Y work?), connections (relationship between A and B?), critical reflection (Why does the author argue that...?).
3. `## TL;DR` — at most **4 sentences**; enough to know what the chapter covers and its main contribution.
4. `## AI Summary` — bullet points organized by subtopic; for each concept explain, contextualize, and exemplify when helpful.
5. `## Final Summary and Conclusions` — main idea and key takeaways; implicitly answer what the reader should take away and how it connects to what likely comes next.

### Publishing

Create the page with the descriptive title as title, the `.md` body converted to Notion Markdown as content (exclude YAML frontmatter, but use it to infer properties if the target is a database), and the parent destination indicated by the user or configured by the environment. Show the link or identifier when available.

### Large PDFs (more than 20 pages)

Agents often have a per-call page limit; extract only the chapter pages first:

```bash
pip install pymupdf   # one time only
python scripts/extract_pdf_pages.py book.pdf --pages 45-72 --output chapter-03.txt
python scripts/extract_pdf_pages.py book.pdf --output full-book.txt   # entire PDF
```

Feed the generated `.txt` into the normal workflow.
