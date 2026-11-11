---
name: oc-slides
description: >
  Trigger: slidev, slides, presentation, deck, retro console, CRT, terminal
  theme. Build a Slidev presentation with a retro-console visual identity —
  three packaged themes (crt-phosphor, dos-terminal, synthwave-arcade), each
  with day and night schemes — themed Mermaid diagrams, and a mandatory
  PNG-export verification loop that checks every slide for overflow. También
  se activa en castellano: "hazme una presentación con Slidev", "presentación
  estilo consola retro".
license: MIT
metadata:
  author: andresnator
  status: testing
  version: "2.1.1"
---

# Slidev Retro Deck

## Intent

- **Goal:** A 16:9 Slidev deck with a retro console identity. Every slide is visually verified before you declare it done.
- **Limits:**
  - Put each deck in its own directory (for example `.ai/slides/<deck-name>/`).
  - `setup/mermaid.ts` exports a plain function. Do not import `@slidev/types`: strict pnpm cannot resolve it and the error shows on slide 1.
  - Do not put color literals or `classDef` in mermaid fences. Use `class <id> a|b|aux`. `var()` does not parse and hex values break the day/night switch.
  - One accent has one meaning in text, borders, stamps, and diagram nodes.
  - Obey each theme's heading scale. Pixel fonts (Silkscreen, Press Start 2P) are much wider than VT323.
  - Presenter notes are a trailing `<!-- ... -->` comment in the slide. Keep the `prefers-reduced-motion` guard on the cursor.
- **Fails if:** you claim "done" without a PNG inspection of every slide in each scheme the deck uses, a mermaid block does not parse, or a slide clips or overflows.

## Context

- **Reads:** the assets and `references/troubleshooting.md`.
- **Never reads:** none.
- **Persona:** deck builder with visual-QA discipline.
- **Scope:** Slidev decks and presentations, mainly with a retro or terminal look.

## Expectations

- **Scenarios:** WHEN a diagram overflows THEN apply the sizing levers in order.
- **Done means:** the verification loop passed on a full export.
- **Quality needs:** legible slides and a consistent accent map.

## Method

| Theme | Night | Day | Fonts (headings / body) |
|---|---|---|---|
| `crt-phosphor` | green/amber on black | phosphor ink on paper-green | VT323 / JetBrains Mono |
| `dos-terminal` | yellow/cyan on Borland blue | navy on ivory | Silkscreen / IBM Plex Mono |
| `synthwave-arcade` | magenta/cyan on purple | sunrise pastel | Press Start 2P / Space Mono |

### Setup facts

- Copy `assets/scaffold/` to the deck and install with explicit `pnpm` commands. The workspace file lets `playwright-chromium` download.
- Start from `assets/slides-skeleton.md`. The seriph theme maps `fonts: serif` to headings. `colorSchema`: `dark` = night, `light` = day, `auto` = system plus toggle. `background: none` shows the CSS gradient.
- Copy `assets/themes/<name>/style.css` to the deck root. Accents: `--accent-a`/`--accent-b`, classes `.tx-a`/`.tx-b`, `.bd-a`/`.bd-b`.
- Each slide has a top-right stamp after the separator: `<div class="stamp stamp-a">topic</div>` (`.stamp-both` for two topics).
- Copy `assets/global-bottom.vue` to the deck root (credit `@andresnator`; edit for another owner).
- Copy `assets/themes/<name>/mermaid-setup.ts` to `setup/mermaid.ts`. A live scheme toggle does not re-render diagrams; reload.
- Dense slides get frontmatter `class: text-sm`; footers get `text-xs`.

### Verification loop

1. Parse mermaid: install `assets/mermaid-check/` deps in a scratch directory, then `node check.mjs <deck>/slides.md`.
2. Export: `npx slidev export slides.md --format png --output slide-export --timeout 90000`.
3. Inspect every PNG. Fix and export again. `--range N` erases the output directory, so finish with a full export.

### Diagram sizing levers

| Lever | How |
|---|---|
| Orientation | `flowchart LR`; `TD` overflows 16:9 |
| Scale | fence option `{scale: 0.4–0.6}` |
| Spacing | `{scale: X, flowchart: {nodeSpacing: 35, rankSpacing: 36}}` |
| Label trim | shorten the widest label; move detail to a caption |
| Composition | diagram-only slides get `class: diagram-center` |
