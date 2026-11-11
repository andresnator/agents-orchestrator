# Troubleshooting

Failures actually hit while building retro decks, as symptom → cause → fix.

## Vite error rendered on the first exported slide

**Symptom:** the PNG export (or dev server) shows a red vite overlay on slide 1: `Failed to resolve import "@slidev/types"`.

**Cause:** `setup/mermaid.ts` imports `@slidev/types` (for example to use `defineMermaidSetup`). It is a transitive dependency of `@slidev/cli`, and strict pnpm does not expose transitive dependencies to your code.

**Fix:** export a plain function with no imports (see `assets/themes/<name>/mermaid-setup.ts`). Do not add `@slidev/types` as a direct dependency just for typing.

## Diagram clipped at the right edge

**Fix:** apply the SKILL.md sizing levers in order and export again after each step. Fence options merge into `mermaid.initialize`, so any init key works there. If the diagram still clips, make sure the theme's `.mermaid` negative side margins are active: they reclaim the slide's horizontal padding.

## Export hangs with a TimeoutError and a mermaid parse error in the log

**Symptom:** `slidev export` stalls and eventually fails with `TimeoutError`; the log shows `[console.warn] Error: Parse error on line N` pointing into a mermaid fence.

**Cause:** a `classDef` line with a value mermaid's grammar cannot parse — notably `var(--token)`; mermaid does not support CSS variables in `classDef`. The diagram never renders, so the export waits forever.

**Fix:** remove `classDef` from fences entirely. Tag nodes with `class <id> a|b|aux` and let the theme's `mermaid-setup.ts` style those classes via `themeCSS` — that keeps node accents day/night-aware with no color literals in the fence.

## Cover slide ignores the theme (gray background, white text in day scheme)

**Symptom:** every slide follows the theme except the cover, which renders seriph's own background and white text — invisible glow at night, unreadable white-on-gray by day.

**Cause:** seriph's `cover`/`intro` layouts set their own background and text colors, overriding the theme's `.slidev-layout` rules.

**Fix:** already handled — each packaged `style.css` retints `.slidev-layout.cover`/`.intro` with the theme tokens (`!important`). Keep that block if you trim the CSS.

## Text or chips clipped at the bottom edge

**Symptom:** the last table row, the final line of a box, or a footer chip's border is cut mid-glyph.

**Cause:** mono fonts are wider and taller than proportional fonts; content that fits with a default font overflows here.

**Fix:** add per-slide frontmatter `class: text-sm` to the dense slide; shrink footers to `text-xs` and reduce their top margin (`mt-2` instead of `mt-4`); as a last resort trim copy. Always verify in the exported PNG, not the dev server — the export is the ground truth for clipping.

## `playwright-chromium` never downloads its browser

**Symptom:** `slidev export` fails because Chromium is missing, even though `playwright-chromium` is installed.

**Cause:** pnpm blocks dependency build/postinstall scripts by default, and the browser download runs in one.

**Fix:** add `assets/scaffold/pnpm-workspace.yaml` (`allowBuilds: playwright-chromium: true`) to the deck directory before installing, or approve the build interactively with `pnpm approve-builds`.

## `check.mjs` crashes before parsing anything

**Symptom:** `TypeError: Cannot set property navigator` (or similar) when running the mermaid validator under jsdom.

**Cause:** `globalThis.navigator` is getter-only in modern Node, so assigning a jsdom navigator throws.

**Fix:** never assign `navigator`; mermaid parses fine with only `window`, `document`, and the DOMPurify stub already in `assets/mermaid-check/check.mjs`.
