# Flipside brand — summary (refined pass)

Generated 26 Sep 2026. 25 files, all image or text. Refinement was run unattended against your three questions; the reasoning is in `../DECISIONS.md` (appended section "Brand job — refinement round") and copied in `DECISIONS.md` here. Regenerate with `../build`.

## Look at first
1. `contact-sheet.png`, section 1 and 2. **The mark was rebuilt.** The first-pass chevron failed your test (caret at 16 px, chevron above). The new mark is the phone in tent mode seen from the audience's side and slightly above: slide face standing in the accent, notes face reclining behind the ridge in ink. Judge it at the 16 px and 60 px cells. The old mark is parked in `../build/alternates/v1-tent-endon`.
2. Palette, dark row. **Only the dark accent changed**, #46A98F to #3E9C85, because the minty one looked cheap beside iOS blue. Light Verdigris stayed: 5.7:1 on Paper, 6.4:1 on Card, deeper than iOS blue beside it. New rule in tokens: accent fills in the dark theme take Ink text, since white fails on both.
3. `templates/statement-example.png`. Italic kept; legible at 60 px on the canvas.
4. `../deck` renders from this `tokens.json` (v0.2.0-refined). The deck session was told to re-render; check that it picked up the new mark.

## What changed in the refinement
- Mark geometry, all mark and icon SVGs and PNGs, wordmark, closing slide glyph, contact sheet.
- `tokens.json`: version, `mark` block, presenter accent hex and its text rule.
- README: refinement section added.

## Delivered
| File | What | Size |
|---|---|---|
| `DECISIONS.md` | brand decision log (copy; the shared log is ../DECISIONS.md) | 7 KB |
| `README.md` | design logic, file map, what changed in the refinement | 3 KB |
| `contact-sheet.png` | everything on one page, 2400x3800 (start here) | 713 KB |
| `icon/flipside-icon-dark-1024.png` | app icon, dark, 1024x1024 | 19 KB |
| `icon/flipside-icon-dark.svg` | icon source | 1 KB |
| `icon/flipside-icon-light-1024.png` | app icon, light, 1024x1024 | 20 KB |
| `icon/flipside-icon-light.svg` | icon source | 1 KB |
| `mark/flipside-mark-dark.svg` | fold mark, two-tone dark | 1 KB |
| `mark/flipside-mark-mono.svg` | one-colour mark, ridge as a white knockout gap | 1 KB |
| `mark/flipside-mark.svg` | fold mark, two-tone light | 1 KB |
| `mark/flipside-wordmark-dark.png` | wordmark preview 2x | 22 KB |
| `mark/flipside-wordmark-dark.svg` | wordmark dark | 13 KB |
| `mark/flipside-wordmark-light.png` | wordmark preview 2x | 23 KB |
| `mark/flipside-wordmark.svg` | wordmark, outlined text | 13 KB |
| `palette/palette.png` | five roles light + dark mirror | 49 KB |
| `templates/closing-example.png` | with sample copy | 19 KB |
| `templates/closing.png` | 1200x630 background | 6 KB |
| `templates/statement-example.png` | with sample copy | 45 KB |
| `templates/statement.png` | 1200x630 background | 3 KB |
| `templates/title-example.png` | with sample copy | 45 KB |
| `templates/title.png` | 1200x630 background | 3 KB |
| `templates/two-column-example.png` | with sample copy | 56 KB |
| `templates/two-column.png` | 1200x630 background | 3 KB |
| `tokens.json` | palette, type, spacing, radius, mark geometry (v0.2.0-refined) | 4 KB |
| `type/type-specimen.png` | type scale at 2x | 125 KB |

## Missing or parked
- No @2x/@3x icon exports, no dark slide backgrounds, no motion. Quick additions to `../build/build.py`.
- A split-tone wordmark alternate (Flip | side) and the first-pass mark are parked in `../build/alternates`.
- Earlier collision on the shared `../DECISIONS.md` is resolved: the deck job re-appended its section, and this round was appended rather than inserted.

## Nothing failed
Every deliverable rendered and re-verified (dimensions, SVG and JSON validity) after the rebuild.
