# Troubleshooting

Failures actually hit while building retro decks, as symptom → cause → fix.

## Vite error rendered on the first exported slide

**Symptom:** the PNG export (or dev server) shows a red vite overlay on slide 1: `Failed to resolve import "@slidev/types"`.

**Cause:** `setup/mermaid.ts` imports `@slidev/types` (for example to use `defineMermaidSetup`). It is a transitive dependency of `@slidev/cli`, and strict pnpm does not expose transitive dependencies to your code.

**Fix:** export a plain function with no imports (see `assets/mermaid-setup.ts`). Do not add `@slidev/types` as a direct dependency just for typing.

## Diagram clipped at the right edge

**Symptom:** the widest mermaid nodes are cut off at the slide border.

**Fix ladder — apply in order, re-export after each step:**

1. Switch orientation to `flowchart LR` if it is `TD` — top-down almost never fits 16:9.
2. Lower the fence `scale` (mono fonts usually need 0.4–0.6).
3. Tighten spacing in the fence: `{scale: X, flowchart: {nodeSpacing: 35, rankSpacing: 36}}` — fence options merge into `mermaid.initialize`, so any init key works here.
4. Trim the widest node label; move the removed detail to a caption `<div>` under the diagram.
5. Make sure the theme's `.mermaid` negative side margins are active — they reclaim the slide's horizontal padding.

## Export hangs with a TimeoutError and a mermaid parse error in the log

**Symptom:** `slidev export` stalls and eventually fails with `TimeoutError`; the log shows `[console.warn] Error: Parse error on line N` pointing into a mermaid fence.

**Cause:** a `classDef` line with a value mermaid's grammar cannot parse — notably `var(--token)`; mermaid does not support CSS variables in `classDef`. The diagram never renders, so the export waits forever.

**Fix:** remove `classDef` from fences entirely. Tag nodes with `class <id> a|b|aux` and let the theme's `mermaid-setup.ts` style those classes via `themeCSS` — that keeps node accents day/night-aware with no color literals in the fence.

## Diagram colors don't follow a live day/night toggle

**Symptom:** after toggling the color scheme in the Slidev UI (`colorSchema: auto`), slides restyle but already-rendered diagrams keep the previous palette.

**Cause:** the mermaid setup picks its day or night palette when a diagram first renders; mermaid does not re-render on scheme change.

**Fix:** reload the page after toggling. Exports are unaffected — the scheme is fixed for the whole run, so PNGs are always consistent.

## Cover slide ignores the theme (gray background, white text in day scheme)

**Symptom:** every slide follows the theme except the cover, which renders seriph's own background and white text — invisible glow at night, unreadable white-on-gray by day.

**Cause:** seriph's `cover`/`intro` layouts set their own background and text colors, overriding the theme's `.slidev-layout` rules.

**Fix:** already handled — each packaged `style.css` retints `.slidev-layout.cover`/`.intro` with the theme tokens (`!important`). Keep that block if you trim the CSS.

## Text or chips clipped at the bottom edge

**Symptom:** the last table row, the final line of a box, or a footer chip's border is cut mid-glyph.

**Cause:** mono fonts are wider and taller than proportional fonts; content that fits with a default font overflows here.

**Fix:** add per-slide frontmatter `class: text-sm` to the dense slide; shrink footers to `text-xs` and reduce their top margin (`mt-2` instead of `mt-4`); as a last resort trim copy. Always verify in the exported PNG, not the dev server — the export is the ground truth for clipping.

## `slidev export --range N` deleted the other slides

**Symptom:** after exporting a single slide with `--range 9`, the output directory contains only `9.png`.

**Cause:** `slidev export` wipes the output directory on every run, including ranged runs.

**Fix:** use `--range` only for fast iteration on one slide, and always finish with a full export before inspecting or declaring done.

## `playwright-chromium` never downloads its browser

**Symptom:** `slidev export` fails because Chromium is missing, even though `playwright-chromium` is installed.

**Cause:** pnpm blocks dependency build/postinstall scripts by default, and the browser download runs in one.

**Fix:** add `assets/scaffold/pnpm-workspace.yaml` (`allowBuilds: playwright-chromium: true`) to the deck directory before installing, or approve the build interactively with `pnpm approve-builds`.

## Headings render in the wrong font

**Symptom:** the display font set under `fonts:` shows up in body text, or headings ignore it.

**Cause:** the seriph theme maps the `serif` headmatter slot to **headings**, not to body serif text.

**Fix:** put the display font (VT323) in `fonts: serif`, and the body/mono font in `sans` and `mono`. Keep `!important`-free CSS overrides in `style.css` aligned with that mapping.

## `check.mjs` crashes before parsing anything

**Symptom:** `TypeError: Cannot set property navigator` (or similar) when running the mermaid validator under jsdom.

**Cause:** `globalThis.navigator` is getter-only in modern Node, so assigning a jsdom navigator throws.

**Fix:** never assign `navigator`; mermaid parses fine with only `window`, `document`, and the DOMPurify stub already in `assets/mermaid-check/check.mjs`.
