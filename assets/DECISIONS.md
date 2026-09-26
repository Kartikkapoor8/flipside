# Flipside — decisions log (shared by the brand job and the deck job)

> **Overwrite notice.** Two unattended jobs ran in parallel on 26 Sep 2026 and were both told to log here. The brand job wrote this file at 01:40:28 and overwrote whatever the deck job had logged before that. The deck job's entries are lost from this file; its `deck/SUMMARY.md` (sections 1 and 2) and `deck/README.md` still describe its stand-ins. If the deck session is still running it should re-append its section below. A copy of the brand section is kept at `brand/DECISIONS.md`.

---

# Brand job

First pass, 26 Sep 2026. You were asleep, so nothing was asked; every call below was made unilaterally and is reversible in `build/build.py`.

## Tooling
- No Pillow, Node, ImageMagick or rsvg on the Mac. Google Chrome was already installed, so all PNGs are rendered from HTML/SVG through Chrome headless at exact pixel sizes (`build/render.sh`). No Homebrew, nothing needing sudo.
- Python is Xcode's 3.9. Installed `fonttools` and `uharfbuzz` with `pip3 --user` (lands in `~/Library/Python/3.9`) to shape and outline the wordmark text so the SVG needs no installed font.
- Google Fonts were downloaded straight from fonts.gstatic.com and kept in `build/fonts` (Instrument Serif and Inter, both OFL). SF Pro is used from the system.
- Font mix-up caught on first render: Google's CSS lists the italic file first and I had labelled it Regular, so every serif line rendered italic. Swapped, verified via the font's italicAngle, rebuilt.

## Mark and icon
- Concept: a tent card seen end-on. That is literally the posture the folded phone takes on a table while presenting: one face to the room, one to the presenter. Left leg is the accent (audience), right leg is ink (presenter), the crease is the vertical split. The concave inner peak is left sharp on purpose; it reads as a real fold.
- Rejected: rectangle plus foreshortened trapezoid (reads as a stock "open door / book" icon); filled plus outlined rectangle pair (reads as two columns, not a fold).
- Geometry chosen from a 12-variant matrix (`build/alternates/mark-geometry-matrix.png`): 36° from vertical, thickness 16 and corner radius 4 in a 100-unit box. Narrower angles read as a caret or arrow.
- Icon: glyph at 56% of the 1024 tile, optically 2% below centre, solid Paper (light) or Ink (dark) background. No corner mask baked in; iOS applies it.
- A mono variant exists with the crease as a knockout gap for one-colour contexts.

## Palette
- Cool near-neutral greys and a single deep verdigris, `#0E6B5E`. It is calm, stays legible in glare, and is not the default blue of every productivity app. Nothing purple, neon, cream or terracotta.
- Measured contrast (WCAG): Ink on Paper 17:1, Graphite on Paper 5.0:1, Verdigris on Paper 5.7:1, white on Verdigris 6.4:1, Verdigris Light on Ink 6.4:1. All pass AA for body text.
- Added a dark mirror of the same five roles for the presenter face. You asked for five values; the light set is the canonical five, the dark set is there because the notes half is a real screen in the product and should not glow at the presenter in a dim room.

## Type
- Display: Instrument Serif (Google Fonts). Narrow forms fit a half-width Duo screen; only Regular and Italic exist, which keeps the system disciplined. The italic is reserved for the statement slide.
- Text: SF Pro (Apple system). Zero bundle weight, Dynamic Type for free, and it is what UI labels on an iPhone should be. Inter is named as the web fallback in tokens.
- Sizes assume one Duo half is roughly 390 pt wide and the audience sits across a table, so slide sizes run larger than normal iOS text. A separate px scale is given for the 1200x630 export canvas.

## Slide templates
- The fold echo is three things used together: a 1 px crease at the exact centre, the face that carries content lit in Card white while the other stays Paper, and a 3 px accent tab at the top of the crease like a bookmark.
- Title uses the left face, statement the right face (they mirror each other), two-column lights both, closing quiets both and puts the mark astride the crease. On the closing slide the crease is interrupted around the content so it never runs through text.
- Delivered both clean backgrounds (what the app draws on) and `-example` versions with sample copy so the type choices can be judged on the sheet.

## Not done, parked, or worth a look
- The refinement round on your feedback is still owed. Everything is regenerated from one script, so changes are cheap.
- Parked: a split-tone wordmark (Flip in ink, side in graphite) in `build/alternates`. Not shown on the sheet.
- Not produced: @2x/@3x icon sizes (1024 master only), dark-theme slide backgrounds, an animated fold.
- Scope: touched only `~/flipside-assets`, `~/Library/Python/3.9` (pip --user) and the session scratch folder. Opened no apps or files; did not touch Xcode, the simulator or `~/duo-check`.


---

<!-- ui-job:start -->
# UI mockups job

Started 01:24, finished 02:10, 26 Sep 2026. Output: `ui/` (8 mockups at 2400 x 1600, 7 raw screens at exact @3x sizes, contact sheet, SUMMARY). Regenerate with `python3 ui/_src/build.py`. One question was asked at 01:33 (where the brand was) before the “don't ask” note arrived; everything after that is my call.

## Geometry (the one to check first)
- **Inner display = 669 x 951 pt @3x (2007 x 2853 px).** Confirmed three ways: App Store Connect's inner screenshot size (2007 x 2853 @3x), the booted iPhone Duo simulator's framebuffer (`simctl io enumerate`: 2007 x 2853, read-only), and Apple's spec page (1878 x 2670 panel px, the OS renders 669 x 951 pt and downsamples ~6%). Outer display = 466 x 678 pt (1398 x 2034 px, exact 3x). Each inner half = 669 x 475.5 pt.
- **The hinge is horizontal in portrait.** Unfolded body is 164.6 x 117.8 mm; the 951 pt axis runs across the hinge. So the two halves are the *top and bottom* of the portrait display, and each half is landscape for its viewer (a 1200 x 630 slide fits at 637 x 334 pt).
- **Pose: the phone stands on its hinge as a V (a tent card upside down), not a tent.** With an inward-folding display the only way two people on opposite sides of a table each see one *inner* half is a V on the spine: each person sees the far half. In a real tent (hinge up) the inner display faces the table. The brand and deck copy say "tent"; I kept that word in labels but drew the V. The near half is upside down for the audience, which is exactly why the audience half is drawn rotated 180 degrees.
- Which half is which: **top half (far from the presenter) = presenter UI, upright; bottom half (near) = audience slide, rotated 180 degrees.** When the phone opens flat towards the presenter, the far half stays upright and the near half un-rotates, so the edit layout is grid on top, notes editor on the bottom, with the fold between them.
- Fold gutter assumed 16 pt each side of the hinge (content keeps clear when partially folded). The real value comes from `ReservedRegion(kind: .division)`; nothing is hard-coded in the mockups beyond that gap.

## Mode thresholds (flow diagram)
- Ended: hinge < 25 degrees while a session is live. Present: 25 to 110 (re-enter from Ended only above 40, hysteresis). Transition: 110 to 160, t = (angle - 110) / 50; the audience half un-rotates at 110 because nobody across the table can see it past that. Edit: 160 to 180. Apple's `hinge.status` (closed / partiallyOpen / fullyOpen) has unpublished thresholds; the diagram shows it as a separate strip and says to read it, not hard-code it.
- The transition frames (90 / 135 / 180) show the notes card sliding down under the fold to become the editor, and the current slide shrinking up into its grid slot. That is my reading of "notes sliding into the slides".

## Brand and content
- Brand folder did not exist at 01:24 (I was told to use it). It appeared at 01:40 from the brand session; the brand session confirmed `tokens.json` v0.2.0-refined final at 01:59 and I rebuilt on it (new tent-mode mark paths, presenter accent `#3E9C85`, Ink text on accent fills in the dark theme). I dropped my placeholder and built on `brand/tokens.json`: Paper/Card/Ink/Graphite/Verdigris on the audience half, the dark mirror (Ink/Slate/Paper/Ash/Verdigris Light) on the presenter half, Instrument Serif for what the room reads, SF Pro for what the presenter reads and taps. Fonts loaded from `build/fonts` (copied into `ui/_src/fonts`).
- Slides are re-rendered from `deck/deck.json` on the brand templates (lit face, 1 px crease, 3 px tab, mark top-left, listening dot, n / total) rather than embedding `deck/slides/*.png`, because those PNGs were still on the placeholder navy/coral brand and `deck.json` was being rewritten while I worked. The deck session confirmed `deck.json` final (01:45) at 02:00; I mirrored its two special cases: slide 6 has an empty cue on purpose (presenter half shows “To end · Close the phone”, editor shows “No cue · closing the phone ends the talk”) and the split slide uses “Public face / Private face” labels. `ui/_src/deck-snapshot.json` and `tokens-snapshot.json` record the exact inputs.
- **Laser dot is signal red `#FF3B30`, the one colour outside the palette.** A verdigris dot on a white slide does not read as a pointer. Used only for the dot and its echo on the trackpad.
- Presenter half shows: slide n of N + title, elapsed / per-slide time (durationHint), prev/next, End, notes, "Say to advance" cue with a listening indicator, next-slide thumbnail, and the laser trackpad (197 x 217 pt, maps 1:1 in normalised coordinates onto the slide). Trackpad sits in the top-right because the top edge of the far half is what a finger reaching over the near half touches first.
- Edit mode is portrait, grid on the top half (3 columns, whole deck visible, one tile lifted mid-drag with an insertion bar), notes + cue + time-hint editor on the bottom half. The keyboard (not drawn) would cover the bottom ~310 pt; the editor scrolls.
- Ended state is drawn on the **outer** display (the phone is closed). Camera in the top-right corner per the HIG ("corner, always visible"); exact status-bar treatment on the outer display is a guess since I could not download the HIG diagrams (403 from the asset CDN).
- Recap email follows `deck/recap-template.md` line for line (subject, five lines) plus Mail's own link preview. Shown on a recipient's iPhone (402 x 874 pt) as asked, and also on the Duo's outer display because the deck notes say the presenter holds the phone up with the recap on screen.

## Tooling
- No Pillow, Node, ImageMagick, rsvg. Google Chrome was present, so every PNG is headless Chrome screenshotting local HTML at exact sizes (`--force-device-scale-factor=3` for raw screens). The folded phone in mockups 3 and 5 is real CSS 3D (two halves rotated about the hinge, walls for thickness, one camera), so any angle is one parameter.
- Nothing installed. Touched only `~/flipside-assets/ui`, this section of `DECISIONS.md`, and the session scratch folder. Read the simulator's display list and took one screenshot of it (read-only) before the "don't touch the simulator" note arrived; did not open Xcode or `~/duo-check`.

## Coordination and QA
- Three unattended sessions shared this folder. I inserted this section between the Brand and Deck sections rather than appending, so the deck session's appends stay under its own heading; both peers confirmed they append only. Copy kept at `ui/DECISIONS.md`.
- Visual QA on the first render caught and fixed: the side-view V diagram had its legs mislabelled (each viewer sees the *far* leg, so the near leg is the audience half); the 180° 3D frame ran into its caption (per-frame camera zoom now); the closed-mockup arrow crossed its text; the flow diagram's solid step now jumps at the opening threshold (40°) with the 25° close drawn dashed; a `%` escaping bug in the 3D transform strings; the drag insertion bar was hidden under the lifted tile.
- Not done: no @2x or @1x exports of the raw screens (3x only; `sips -Z` will make them), no dark-theme slide variant, no keyboard in edit mode, no animation. All are one function away in `ui/_src`.
<!-- ui-job:end -->

---

# Deck job

(Re-log here. Entries written before 01:40:28 on 26 Sep 2026 were overwritten by the brand job; see the notice at the top.)

First pass, 26 Sep 2026, re-logged after the overwrite. Every call below is reversible by editing one file and running `deck/render/render.sh`.

## 1. The brand folder did not exist when the deck started
At 01:27 `~/flipside-assets/brand` was not on this Mac, so the deck was built on a placeholder brand kept in one file, `deck/render/brand.css`: navy audience half, off-white presenter half, coral accent, mint "listening" accent, Charter / Avenir Next / Menlo (all ship on iOS). The brand job finished at 01:40; see "Brand applied" below for what happened next.

## 2. The six slides were not in the message
The paste contained the literal text "[paste the six slides above, with notes and cues]", so no copy arrived. The six slides were written from the product description in the brief. Cues were chosen to be two to four words, natural in speech, phonetically distinct, and never spoken earlier in the script: "here's the problem", "so we flipped it", "and it listens", "watch this", "make the deck", "that's Flipside". Replace the strings in `deck/deck.json` and re-render when the real copy is ready.

## 3. Rendering
Headless Google Chrome (already installed) screenshotting local HTML, driven by Python 3.9 standard library. No installs. Chrome does not exit after `--screenshot` on this machine, so the script polls for the PNG and kills its own instance, identified by a throwaway profile directory that is deleted afterwards. The 2400x1260 set is rendered at device scale 2 from the same HTML, not upscaled.

## 4. Layouts
Six layouts: cover, statement, split (the two-halves reveal, with a small diagram of the phone), listen (shows the cue phrase being listened for, on purpose, for the demo), live (topic field and three empty slots), close. Every audience slide carries the mark top-left, a "listening" dot bottom-left and `n / total` bottom-right.

## 5. Notes cards
Notes text is sized by length (32 px down to 24 px) so long notes still fit. The `live` slide's "next" thumbnail shows the fallback deck's first slide, labelled "generated deck (fallback shown)", because the real next deck does not exist until it is generated. The last card's "next" panel says "close the phone".

## 6. Fallback marking is presenter-side only
Badge on the fallback notes cards, `fallback-` ids, filenames under `deck/fallback/`, and "FALLBACK DECK" as the first words of each notes entry. No badge on the audience slides, because if the fallback plays nobody should be able to tell.

## 7. Recap email
`{{double_brace}}` placeholders with a table of sources. Line 4 (questions) is droppable so the body stays at five lines when nothing was captured.

## 8. Things left alone
Nothing outside `~/flipside-assets` was written. `~/duo-check/DuoCheck/DuoCheckApp.swift` was read once to confirm the hinge states (closed / partiallyOpen / fullyOpen) and not modified. Xcode and the simulator were not opened. The contact sheet was not opened on screen.

## 9. Copy replaced with Kartik's six slides (01:45)
Titles, bodies and notes are now verbatim from the overnight message. Layouts kept: cover, statement, split, live, statement, close. The old "listen" layout (which showed the cue pill) no longer matches any slide, so slide 5 "Point at things" uses statement; the renderer still supports listen. No em dashes anywhere in the copy.

## 10. Cues now come from the spoken notes
The old cues were transition lines outside the script. The new notes are the script, so each cue is the last distinctive phrase of that slide's notes: "same phone", "afternoon on a laptop", "not a button", "give me a topic", "for their screen". Slide 6's notes say "Say nothing", so its cue is the empty string and the fold ends the run; the notes card shows "Fold the phone shut" instead of a cue. Durations re-mapped to the new content (20 / 40 / 45 / 90 / 30 / 20 s, total 245 s), with the 90 s on the live-generation slide.

## 11. Brand applied (01:48, tokens.json v0.1.0-firstpass)
`render/brand.css` is now generated from `brand/tokens.json` on every build, so a tokens change only needs `deck/render/render.sh`. The five audience roles and the five presenter roles map one to one; sizes come from `scale_canvas1200`, margins from `slideMargin_canvas1200`. Faces inverted from the placeholder to match the brand: audience slides are light (Paper background, Card lit face), notes cards are the dark mirror (Ink, Slate, Paper text, Verdigris Light for the cue). Instrument Serif is embedded from `deck/render/fonts` (copied from `build/fonts`, OFL) as base64 so Chrome needs no file-access flag; SF Pro comes from the system via `-apple-system`. The mark and wordmark SVGs are inlined from `brand/mark`.

## 12. Layout to template mapping
cover = title template (wordmark on the lit left face, body in Graphite as the caption slot; the fallback cover uses the mark plus title text). statement = statement template (slide number on the quiet face, Instrument Serif Italic title on the lit face, body under it). split = two-column with "Public face" / "Private face" labels and a mock of the presenter card on the right so the audience sees what the private face looks like. live = two-column with the topic field and three empty slots on the right. close = closing template, crease interrupted 170 to 456 px around the mark and text. No slide counter on audience slides beyond the template's own number; the presenter card carries the count.

## 13. Stale files
The first brand render left 12 PNGs from the old slide ids (problem, flip, listen, live) next to the new ones. The build now clears `slides/`, `notes/` and `fallback/` before rendering.

## 14. tokens.json refined to v0.2.0 while the deck was rendering (01:50)
The first brand render read v0.1.0-firstpass. The rebuild at 01:5x read v0.2.0-refined; the only value that changed was the presenter accent (Verdigris Light, #46A98F to #3E9C85). All PNGs and the contact sheet are from v0.2.0. Any later change to tokens.json or the mark SVGs is picked up by `deck/render/render.sh`.

---

## 15. Deck re-rendered on the refined mark (01:57)
The brand job's refinement landed at 01:55 (new tent-mode mark geometry in `brand/mark/*.svg`, wordmark viewBox 379x120, presenter accent #3E9C85), four minutes after the previous deck render. Rebuilt at 01:57. tokens.json values were already what the 01:51 render used, so `render/brand.css` did not change; only the inlined mark and wordmark did. The mark keeps a 100-unit square viewBox, so the existing mark boxes (56 px on the fallback cover, 88 px astride the crease on the closing slide, 28 px in the notes card's "close the phone" panel) hold it without clipping. Accent-filled controls in the dark theme already use Ink text (the fallback badge), as the refined tokens ask.


# Brand job — refinement round (appended 26 Sep 2026, run unattended)

You asked for the refinement to be judged against three questions. Appended here rather than inserted above so the deck job's section is never rewritten.

## 1. Does the mark read as a folded phone standing on a table, not a caret or chevron?
- **No, the first-pass mark failed.** Rendered at 16, 24, 32, 60, 120, 256 and 1024 px on Paper and Ink (`build/work/explore2.png`): the end-on chevron is a caret at 16 px and a two-tone chevron at 60 px and above. Flat feet turned it into a roof or mountain, a table bar turned it into a camping tent. The end-on view throws away the faces, which are what make a phone a phone.
- Tried a corner view of a symmetric A-frame (`explore3.png`): at 60 px it reads as a leaning card with a kickstand; at 1024 px and in the wordmark it collapsed into a rhombus on a stick. Rejected after seeing it in place.
- Tried front-and-above views (`explore5.png`): with a symmetric tent the far face is hidden behind the near face at any viewing pitch under 54°, so it reads as a single card. Straight-on it looks like a credit card with a stripe.
- **Chosen:** an asymmetric tent seen from the audience's side of the table and slightly above (`explore6.png`, row "near 24 · far 64 · pitch 42 · yaw 78"). The slide face stands steep in the accent; the notes face reclines behind the ridge in ink, toward the presenter looking down at it. This is also how people actually prop a phone to present. At 60 px and up it reads as a folded card standing on a table with a second face; at 16 px it is a two-band device shape, not a caret. Geometry is in `tokens.json` under `mark` and the old mark is parked in `build/alternates/v1-tent-endon`.
- Consequences: the wordmark glyph is now landscape and sits on the baseline at cap height; the closing slide's glyph box grew to 160 px; icon glyph fills ~64% of the tile width.

## 2. Verdigris on Paper and Ink: contrast, and cheap next to iOS blue?
- Measured (WCAG): Verdigris #0E6B5E on Paper 5.71:1, on Card 6.40:1, white on Verdigris 6.40:1. iOS blue #007AFF on Paper is 3.59:1, so ours is the stronger of the two. Beside iOS blue in a mock button/link/progress row (`build/work/accent.png`) it reads deeper and calmer, not cheap. **Kept.**
- On Ink the raw #0E6B5E is 2.89:1 and was never used there; the dark theme uses a lifted variant. The first-pass lift #46A98F passed contrast (6.45:1) but looked minty next to iOS blue. **Changed the dark variant only**, to #3E9C85: 5.54:1 on Ink, 5.02:1 on Slate, still AA, visibly the same hue family as the light accent.
- Found while checking: white text on either dark variant fails (2.9 to 3.4:1). Rule added to tokens: accent-filled controls in the presenter theme take Ink text.

## 3. Italic on the statement slide
- At 60 px on the 1200x630 canvas (`brand/templates/statement-example.png`) and at 40 pt on the specimen it is fully legible. **Kept.**

## Regenerated
Every file in `brand/` was rebuilt from `build/build.py` and the contact sheet re-rendered; dimensions and SVG/JSON validity re-verified. `tokens.json` is now version 0.2.0-refined; the deck job was told to re-render against it.

---

# Motion job

Started 02:1x, 26 Sep 2026, run unattended. Output: `motion/`. Regenerate with `python3 motion/render/build.py`. Nothing was asked; every call below is mine. Appended only; the sections above are untouched.

