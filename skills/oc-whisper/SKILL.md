---
name: oc-whisper
description: |
  Extract, transcribe, and summarize audio or video files using OpenAI Whisper. Use this skill
  whenever the user wants to transcribe audio or video, extract what was said in a recording,
  get a transcript of a meeting/interview/lecture/podcast, or generate a summary of spoken content.
  Also trigger when the user mentions files like .mp3, .mp4, .wav, .m4a, .ogg, .flac, .webm,
  .mkv, .mov and wants text out of them. Generates a .md file with an AI summary followed by
  the full literal transcript.
  También se activa en castellano: "transcribir", "transcripción", "extraer audio",
  "qué dice este audio", "transcribir reunión", "transcribir entrevista",
  "pasar audio a texto", "resumir grabación", "transcribir este video",
  "extraer texto de audio", "transcript", "whisper", "grabar y resumir".
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.1.2"
---

# Whisper Extract

## Intent

- **Goal:** A `.md` file with an AI summary, then the complete literal Whisper transcript of an audio or video file.
- **Limits:**
  - Check Whisper first: `whisper --help > /dev/null 2>&1 && echo "OK" || echo "NOT FOUND"`. If it is missing, tell the user to run `pipx install openai-whisper` (and `brew install ffmpeg`), then wait.
  - Ask for missing inputs once, in one message.
  - Clear `/tmp/whisper-extract-temp` before each run. Never read files from earlier runs.
  - Do not paraphrase the transcript or invent speaker turns. Do not put it in chat.
- **Fails if:** the transcript is not Whisper's raw text, a stale file from an earlier run is used, the command is split across lines, or a Whisper error is not reported with a fix.

## Context

- **Reads:** the input file and the Whisper JSON in `/tmp/whisper-extract-temp/` with the same basename (field `text`).
- **Scope:** transcripts and summaries of recordings (.mp3, .mp4, .wav, .m4a, .ogg, .flac, .webm, .mkv, .mov, .mpeg, .mpga, .oga, .wma).

## Expectations

- **Scenarios:** WHEN the file is longer than 1 hour THEN say: "Starting transcription — this may take a few minutes depending on file length and model."
- **Done means:** `YYYY-MM-DD-<slugified-context>.md` (date from `stat` if today is unknown) in the output directory. Chat shows the full path, the summary, and `Transcript: ~N words`.
- **Quality needs:** summary of 150-300 words in the recording language. Transcript in paragraphs of 10-15 sentences, content unchanged.

## Method

- **Inputs:** Required: file path, language (or auto-detect), recording context. Optional: model (default `turbo`; needs `openai-whisper` >= 20240930), output directory (default: the file directory), summary language.
- **Command:** one line only. In zsh, a space after a `\` continuation gives Whisper an empty second path. For auto-detect, omit `--language`.

```bash
whisper "<file_path>" --model <model> --language <code> --output_format json --output_dir /tmp/whisper-extract-temp
```

- **Summary sections:** subject; key topics; decisions and action items with owner (skip if none); 1-3 verbatim quotes.
- **Errors:** unknown model `turbo` → `pipx upgrade openai-whisper`. Out of memory → smaller model. Empty transcript → silent file or wrong path. Unsupported format → `ffmpeg -i input.xyz output.mp3`.

File template:

```markdown
---
title: "<recording context>"
date: YYYY-MM-DD
model: <whisper model used>
language: <detected or specified language>
source: "<original filename>"
duration: "<approximate duration if available>"
---

# <Descriptive title based on context>

## Summary

<summary>

---

## Full Transcript

<complete literal transcript, paragraph-formatted>
```
