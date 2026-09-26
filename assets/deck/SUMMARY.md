# SUMMARY

Flipside self-pitch deck assets, built 26 Sep 2026 (final render 01:57). Output folder: `~/flipside-assets/deck`.

## Look at these first
1. `contact-sheet.png`: every slide and notes card on one page, rendered on the real brand.
2. `../DECISIONS.md`, "Deck job" section: entries 9 to 15 cover your overnight corrections. Two calls to check: cues are now taken from the end of each slide's spoken notes, and slide 6 has an empty cue because you say nothing and the fold ends the run.
3. `deck.json`: your six slides verbatim, with the cues and durations chosen for them.

## Delivered
- [x] `deck.json`, 6 slides with id, layout, title, body, notes, cue, durationHint (total 245 s)
- [x] 6 audience slides at 1200x630 and 6 at 2400x1260, on the brand templates (title, statement, two-column, closing)
- [x] 6 notes cards at 800x600 in the brand's dark mirror: notes large, next-slide thumbnail, timer placeholder, cue to say
- [x] `fallback-deck.json`, 3 slides on "Why standing desks beat sitting" (total 90 s), marked as fallback, plus 3+3 slides and 3 notes cards
- [x] `recap-template.md`, subject line plus five lines, no em dashes
- [x] `contact-sheet.png` (2400x1500)
- [x] `README.md` with the layout-to-template mapping and cue table; `render/` rebuilds everything in about 30 s

## Brand
- `~/flipside-assets/brand/tokens.json` appeared at 01:40 (no polling needed; it was there when your message arrived), was refined to v0.2.0 at 01:50, and the mark SVGs were replaced with the tent-mode geometry at 01:55. The final render (01:57) uses all of that. The only token value change was the presenter accent.
- `render/brand.css` is generated from tokens.json on every build. The placeholder brand is retired and kept only as `render/brand-placeholder.css`.
- If the brand session refines tokens.json or the mark SVGs again, run `render/render.sh` and the deck follows.

## Missing or provisional
- Nothing is missing. No step failed and no installs were needed.
- The brand session said a refinement round is still owed, so the look may shift again; see above.

## Every file
- `contact-sheet.png`  2400x1500
- `deck.json`
- `fallback-deck.json`
- `fallback/notes/800x600/01-fallback-cover.png`  800x600
- `fallback/notes/800x600/02-fallback-move.png`  800x600
- `fallback/notes/800x600/03-fallback-sharp.png`  800x600
- `fallback/slides/1200x630/01-fallback-cover.png`  1200x630
- `fallback/slides/1200x630/02-fallback-move.png`  1200x630
- `fallback/slides/1200x630/03-fallback-sharp.png`  1200x630
- `fallback/slides/2400x1260/01-fallback-cover.png`  2400x1260
- `fallback/slides/2400x1260/02-fallback-move.png`  2400x1260
- `fallback/slides/2400x1260/03-fallback-sharp.png`  2400x1260
- `notes/800x600/01-cover.png`  800x600
- `notes/800x600/02-pitch.png`  800x600
- `notes/800x600/03-faces.png`  800x600
- `notes/800x600/04-topic.png`  800x600
- `notes/800x600/05-point.png`  800x600
- `notes/800x600/06-close.png`  800x600
- `README.md`
- `recap-template.md`
- `render/brand-placeholder.css`
- `render/brand.css`
- `render/build.py`
- `render/fonts/InstrumentSerif-Italic.ttf`
- `render/fonts/InstrumentSerif-Regular.ttf`
- `render/render.sh`
- `slides/1200x630/01-cover.png`  1200x630
- `slides/1200x630/02-pitch.png`  1200x630
- `slides/1200x630/03-faces.png`  1200x630
- `slides/1200x630/04-topic.png`  1200x630
- `slides/1200x630/05-point.png`  1200x630
- `slides/1200x630/06-close.png`  1200x630
- `slides/2400x1260/01-cover.png`  2400x1260
- `slides/2400x1260/02-pitch.png`  2400x1260
- `slides/2400x1260/03-faces.png`  2400x1260
- `slides/2400x1260/04-topic.png`  2400x1260
- `slides/2400x1260/05-point.png`  2400x1260
- `slides/2400x1260/06-close.png`  2400x1260
- `SUMMARY.md`
- `render/html/`  19 intermediate HTML pages
