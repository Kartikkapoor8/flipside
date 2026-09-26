# Flipside — brand & visual system (first pass)

Flipside turns a link or a sentence into a presentation and plays it across the two halves of a folded iPhone Duo: slides face the audience, notes face the presenter. The whole system is built from that one fact. The mark is the phone itself in tent mode, seen from the audience's side of the table: the slide face stands steep toward the room in the accent, the notes face reclines behind the ridge in ink, toward the presenter looking down at it. The halves are landscape, the same proportion as the slides. Every surface repeats that crease quietly. Slides carry a 1px fold line down the centre, the face that holds content is lit (Card white) while the other stays Paper, and a 3px accent tab sits at the top of the crease like a bookmark. Colour is a cool, near-neutral grey scale with a single deep verdigris accent, chosen to stay calm and legible on a phone held up in a bright room, with a dark mirror of the same five roles for the presenter's side (accent fills there take Ink text, not white). Type pairs Instrument Serif for anything the room reads (its narrow forms fit a half-width screen) with SF Pro for everything the presenter reads and taps, so the app ships with one bundled font and one system font.

## Files

- `mark/flipside-mark.svg`, `-dark.svg`, `-mono.svg` — the fold mark (100-unit viewBox, transparent)
- `mark/flipside-wordmark.svg`, `-dark.svg` (+ `.png` previews) — mark + "Flipside" in Instrument Serif, text outlined
- `icon/flipside-icon-light-1024.png`, `-dark-1024.png` (+ `.svg`) — app icon, solid background, no corner mask (iOS applies it)
- `palette/palette.png` — the five roles, light and dark mirror
- `type/type-specimen.png` — the type scale at 2x
- `templates/title.png`, `statement.png`, `two-column.png`, `closing.png` — 1200x630 backgrounds; `*-example.png` show sample copy in the system
- `tokens.json` — colour, type, spacing, radius and mark geometry
- `contact-sheet.png` — everything on one page

## Refinement round (26 Sep 2026, run unattended)

- Mark rebuilt. The first-pass end-on chevron read as a caret at 16 px and a chevron at 60 px and above, so it failed the one test that mattered: does it read as a folded phone standing on a table? The new mark is the same phone in tent mode seen from the audience's side and slightly above, with the slide face standing steep and the notes face reclining behind the ridge. That view keeps both faces visible at every size. The old mark is kept in `../build/alternates/v1-tent-endon`.
- Accent kept. Verdigris passes on Paper (5.7:1) and Card (6.4:1) and reads deeper and calmer than iOS blue beside it. Only the dark-theme variant changed, from #46A98F to #3E9C85, because the minty one looked cheap next to iOS blue; it is 5.5:1 on Ink and 5.0:1 on Slate. Accent-filled buttons in the dark theme take Ink text, since white on either variant fails.
- Italic kept on the statement slide; at 60 px on the 1200x630 canvas it is fully legible.

## Fonts

Instrument Serif: https://fonts.google.com/specimen/Instrument+Serif (OFL). SF Pro ships with iOS; use Inter (https://fonts.google.com/specimen/Inter) as the web fallback.
