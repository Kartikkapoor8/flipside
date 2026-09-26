# Flipside UI mockups — SUMMARY

Built 26 Sep 2026 02:08 by the UI mockups session. Everything here is an image or a note; no app code.

Decisions and rationale: `../DECISIONS.md` (section “UI mockups job”), copy in `DECISIONS.md` here. Regenerate: `python3 _src/build.py`.

## Look at these first
1. `contact-sheet.png` — everything on one page.
2. `03a-transition-090.png` — the pose. I drew the phone standing on its hinge as a V (each person sees the far inner half). If you meant something else, say so; it is one parameter.
3. `01-present-mode.png` — the two halves as the app draws them: top half presenter (upright), bottom half audience (rotated 180°).
4. `06-flow-hinge-angle-to-mode.png` — the angle thresholds (Ended < 25°, Present 25–110°, transition 110–160°, Edit 160–180°, re-enter Present at 40°).
5. Slides carry `deck/deck.json` as finalised by the deck session at 01:45 (snapshot in `_src/deck-snapshot.json`); colours and the mark follow `brand/tokens.json` v0.2.0-refined (snapshot in `_src/tokens-snapshot.json`).

## Display sizes used
- Inner display: **669 × 951 pt @3x = 2007 × 2853 px** (App Store Connect inner screenshot size; confirmed against the booted Duo simulator framebuffer). Panel is 1878 × 2670 px; the OS downsamples. Hinge horizontal at 475.5 pt; each half 669 × 475.5 pt.
- Outer display: 466 × 678 pt @3x = 1398 × 2034 px.
- Second phone (recipient): iPhone 402 × 874 pt @3x.

## Every file
- `01-present-mode.png`  2400×1600  783 KB
- `02-edit-mode.png`  2400×1600  903 KB
- `03a-transition-090.png`  2400×1600  1420 KB
- `03b-transition-135.png`  2400×1600  1371 KB
- `03c-transition-180.png`  2400×1600  1435 KB
- `04-closed-recap-sent.png`  2400×1600  857 KB
- `05-laser-dot.png`  2400×1600  785 KB
- `06-flow-hinge-angle-to-mode.png`  2400×1600  991 KB
- `contact-sheet.png`  2400×1700  955 KB
- `raw/edit-180deg_669x951pt@3x.png`  2007×2853  283 KB
- `raw/ended-outer_466x678pt@3x.png`  1398×2034  102 KB
- `raw/present-laser_669x951pt@3x.png`  2007×2853  253 KB
- `raw/present_669x951pt@3x.png`  2007×2853  231 KB
- `raw/recap-mail-duo-outer_466x678pt@3x.png`  1398×2034  172 KB
- `raw/recap-mail-iphone_402x874pt@3x.png`  1206×2622  190 KB
- `raw/transition-135deg_669x951pt@3x.png`  2007×2853  203 KB
- `DECISIONS.md`  copy of my section of the shared log
- `SUMMARY.md`  this file
- `_src/`  the generator (Python + HTML/CSS, fonts copied from `../build/fonts`), not app code

## Missing or provisional
- The HIG diagrams for the outer display (camera corner, vertical status bar) could not be downloaded (asset CDN returned 403), so the outer-display chrome in `04` and `raw/ended-outer*` follows the HIG text only.
- The keyboard is not drawn in edit mode; the editor scrolls under it.
- Fold gutter is an assumed 16 pt per side; the app should read `ReservedRegion(kind: .division)`.
- Slide renders are mine (deck.json on the brand templates), not the deck session’s PNGs, which were still on the placeholder palette when I built.

## Nothing failed
All deliverables rendered on the first pipeline (headless Chrome). No installs were needed.
