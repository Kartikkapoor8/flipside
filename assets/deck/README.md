# Flipside self-pitch deck

Content and rendered images for the deck Flipside uses to pitch itself. No app code.
Rendered on the real brand from `../brand/tokens.json`. Every judgment call is in `../DECISIONS.md` under "Deck job".

## What is here

| Path | What |
|---|---|
| `deck.json` | 6 slides: id, layout, title, body, notes, cue, durationHint (seconds) |
| `fallback-deck.json` | 3 slides, "Why standing desks beat sitting", same fields. Plays if live generation fails |
| `slides/1200x630/` and `slides/2400x1260/` | audience face, one PNG per slide (light: Paper and Card) |
| `notes/800x600/` | presenter face, dark mirror: notes large, cue to say, next-slide thumbnail, timer placeholder |
| `fallback/slides/`, `fallback/notes/` | the same for the fallback deck |
| `recap-template.md` | subject line plus five-line body the app sends on fold |
| `contact-sheet.png` | every slide and notes card on one page |
| `render/brand.css` | GENERATED from `../brand/tokens.json` on every build. Do not edit by hand |
| `render/brand-placeholder.css` | the stand-in brand used before tokens.json existed, kept for the record |
| `render/fonts/` | Instrument Serif Regular and Italic (OFL), embedded into every page at build time |
| `render/build.py`, `render/render.sh` | re-render everything (needs Google Chrome in /Applications) |
| `render/html/` | intermediate pages, useful when tweaking CSS |
| `SUMMARY.md` | file list, gaps, what to look at first |

## Re-render after changing copy or brand

```
~/flipside-assets/deck/render/render.sh
```

About 30 seconds. Edit `deck.json` or `fallback-deck.json` for copy. Edit `../brand/tokens.json` for colors, type and spacing; the build reads it fresh every time and clears the output folders first, so renamed slides leave no stale files.

## How the brand templates map to layouts (the `layout` field)

| layout | Brand template | Audience sees |
|---|---|---|
| `cover` | title | left face lit: wordmark (or mark + title), body in Graphite. Right face quiet |
| `statement` | statement | left face quiet with the slide number, right face lit with the title in Instrument Serif Italic and the body |
| `split` | two-column | both faces lit: "Public face" label, heading and body on the left; "Private face" label and a mock of the presenter card on the right |
| `live` | two-column | both faces lit: title and body on the left; "Listening" label, topic field and three empty slide slots on the right |
| `close` | closing | both faces quiet, mark astride the crease, centred title and body, crease interrupted around the content |
| `listen` | statement | statement plus a pill showing the cue being listened for. Supported by the renderer, not used by the current deck |

Every slide carries the 1 px crease at the exact centre and the 3 px accent tab at the top of it, per the brand.

## Cue phrases

Cues are the last distinctive words of each slide's spoken notes, so saying the script advances the deck. They are two to four words, phonetically distinct, and never spoken earlier in the script.

| Slide | Say to advance | Then |
|---|---|---|
| 1 cover | same phone | slide 2 |
| 2 pitch | afternoon on a laptop | slide 3 |
| 3 faces | not a button | slide 4 |
| 4 topic | give me a topic | listens for the topic, generates and plays a 3-slide deck, or the fallback |
| 5 point | for their screen | slide 6 |
| 6 close | (none) | the presenter says nothing; folding the phone shut ends the run and sends the recap |
| fallback 1 | reason one | fallback 2 |
| fallback 2 | reason two | fallback 3 |
| fallback 3 | back to the pitch | main slide 6 |

Slide 6 has `"cue": ""` on purpose. Live-generated decks should end on "back to the pitch" so the return works the same way as the fallback.

## Fallback marking

Marked in the filename, the slide ids (`fallback-*`), the first words of every notes entry, and a "Fallback deck" badge on the presenter side only. The audience side has no badge on purpose: if it plays, nobody should be able to tell.
