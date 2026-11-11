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
  version: "2.1.0"
---

# Whisper Extract

## Intent

- **Goal:** A `.md` file containing an AI summary followed by the complete literal transcript of an audio or video file, produced with Whisper.
- **Limits:**
  - Verify Whisper first (`whisper --help > /dev/null 2>&1 && echo "OK" || echo "NOT FOUND"`). If missing, tell the user to run `pipx install openai-whisper` (and `brew install ffmpeg` if ffmpeg is missing), then stop and wait until Whisper is available. The `turbo` model requires `openai-whisper` >= 20240930 (`pipx upgrade openai-whisper`).
  - Ask for missing inputs once, in a single message; never ask for things already mentioned. Wait for answers before transcribing.
  - Never paraphrase, clean up, or invent speaker turns in the transcript; do not split into speaker turns unless Whisper detected them.
  - Do not dump the full transcript in chat — it lives in the file.
- **Fails if:** the transcript differs from Whisper's raw text, a stale file from a previous run is used, the Whisper command is split across lines, or a Whisper error is not reported with a suggested fix.

## Context

- **Reads:** the user's file; the Whisper JSON in `/tmp/whisper-extract-temp/` whose basename matches the input (its `text` field is the full raw transcript).
- **Never reads:** leftovers from earlier runs (clear `/tmp/whisper-extract-temp` before each run).
- **Persona:** concise, factual transcriber; the transcript is the source of truth, the summary is the lens.
- **Scope:** transcribing audio/video, extracting what was said, transcripts or summaries of meetings, interviews, lectures, podcasts; files like .mp3, .mp4, .wav, .m4a, .ogg, .flac, .webm, .mkv, .mov (English and Spanish triggers in the description).

## Expectations

- **Scenarios:**
  - WHEN the file is longer than 1 hour THEN tell the user: "Starting transcription — this may take a few minutes depending on file length and model."
  - WHEN Whisper fails THEN report the exact error and the fix from the error table before continuing.
  - WHEN today's date is unknown THEN use the file's modification date via `stat`, or drop the date prefix.
- **Done means:** the file `YYYY-MM-DD-<slugified-context>.md` (e.g. `2026-04-14-team-meeting-q3-roadmap.md`) saved in the output directory, and chat shows its full path, the summary section, and `Transcript: ~N words`.
- **Quality needs:** summary of 150-300 words without padding, in the recording language (or the requested output language); transcript wrapped into readable paragraphs with a blank line roughly every 10-15 sentences, content unchanged.

## Method

### Inputs

- **Required:** file path (mp3, mp4, wav, m4a, ogg, flac, webm, mkv, mov, mpeg, mpga, oga, wma); language (e.g. `Spanish`, `English`, `Portuguese`, or "auto-detect", slower); recording context (e.g. "team meeting about Q3 roadmap", "lecture on clean architecture"), used for a better summary.
- **Optional (ask only if not obvious):** Whisper model, default `turbo` (recommended speed/accuracy balance; `tiny` fastest/less accurate, `large-v3` most accurate/slower; also `base`, `small`, `medium`) — ask only if the user wants a different speed/accuracy trade-off; output directory, default the audio file's directory; summary language, default the recording language.

### Transcription

```bash
whisper "<file_path>" --model <model> --language <language_code_or_auto> --output_format json --output_dir /tmp/whisper-extract-temp
```

Always emit this as a **single line** — never split with `\` continuations: in zsh a trailing space after `\` becomes an escaped space that Whisper receives as a second (empty) path, and ffmpeg fails with `Error opening input file  .` Language codes: `es`, `en`, `pt`, `fr`, etc.; for auto-detect omit `--language`.

### Summary contents

1. **What this recording is about** — one or two sentences.
2. **Key topics discussed** — bulleted themes or agenda items.
3. **Key decisions or conclusions** — skip for lectures or monologues without decisions.
4. **Action items** — with owner if stated; skip if none.
5. **Notable quotes or moments** — 1-3 verbatim fragments (optional, highly recommended for interviews and meetings).

### File template

Use this exact template:

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

<The summary from Summary contents>

---

## Full Transcript

<The complete literal transcript from Whisper, paragraph-formatted>
```

### Error handling

| Problem | Action |
|---|---|
| `whisper: command not found` | Tell user to run `pipx install openai-whisper` |
| `ffmpeg not found` | Tell user to run `brew install ffmpeg` |
| File not found | Ask user to confirm the path; suggest `ls` to check |
| Unsupported format | Tell user to convert with `ffmpeg -i input.xyz output.mp3` |
| Transcription empty / very short | Warn user — likely a silent file or wrong path |
| Unknown model `turbo` | Tell user to run `pipx upgrade openai-whisper` (needs >= 20240930) |
| Out of memory | Suggest a smaller model (`medium`, `small`) |
