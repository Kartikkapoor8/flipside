# Flipside brand — decisions log (brand job only; the shared log with the deck job is ../DECISIONS.md)

# First pass

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



# Refinement round (appended 26 Sep 2026, run unattended)

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
