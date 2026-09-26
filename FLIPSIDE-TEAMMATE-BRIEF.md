# Flipside, teammate brief

Read this fully before writing code. It is the shared picture for both agents on this team.

## What we are building

Flipside is a presentation app for iPhone Duo, Apple's folding phone. Bitrig Hacks, Sat Sep 26, four hours of building (11:30 to 3:30), then live demos. Everyone builds in the iPhone Duo simulator in Xcode 27.1 beta. Nobody has the real phone.

The one-line pitch: the show on their side, the notes on yours.

- Stand the phone up on a table folded to about 90 degrees, like a book on its edge, at the corner of a table between you and one other person. Both halves are the inner display. The half facing them shows the slide, drawn rotated 180 degrees so it reads right from their side. The half facing you shows your notes, the next slide, a timer, and a live viewer of what they are seeing.
- Lay it flat and the same deck becomes the editor. Reorder slides, fix a line, drop in a quick video or animation. Presenter half is the control desk, audience half is the live preview.
- Fold it shut and the meeting is over. A recap email goes to the other person.
- Say a topic or paste a link and a deck builds itself, streaming slide by slide while you talk.
- Your finger on your half puts a laser dot on theirs.

We present our own pitch to the judges using the app. The judges are the audience.

## What wins

Judges score creative use of the Duo's new APIs and something meaningfully new. The hinge driving the mode (present, edit, ended) is the part only a folding phone can do. The AI generation and the motion are what make it feel like a product. Both matter. Neither is optional.

## The phone, facts we verified

- Inner display when open: 669 x 951 points portrait. Closed cover display: 466 x 678 points.
- Hinge API, SwiftUI: `.onHingeChange { old, new in }` gives a `DeviceHingeContext`. `new.hinge?.status` is `.closed`, `.partiallyOpen` or `.fullyOpen`. `new.hinge?.angle` is an `Angle`, 180 is flat. These live in SwiftUICore, not SwiftUI, so grep there if you need signatures. UIKit twin: `UIHingeInteraction`.
- Layout across the fold: `ArrangementView { primary } secondary: { secondary }` with `.arrangementViewStyle(.split)`. Environment `splitArrangementAxis` is nil when not split. UIKit twin: `UIArrangementViewController`.
- The fold seam: `GeometryProxy.reservedRegions(kind: .division)` returns regions with `frame`, `margins`, `isActive`. Active only when partially folded. Re-query on hinge change, the first query on appear can come back empty.
- Simulator: the GUI is DeviceHub, inside Xcode 27.1 (`Xcode.app/Contents/Applications/DeviceHub.app`). There is no Simulator.app. Poses are buttons at the bottom of the device window, plus a hinge slider. `xcrun simctl` cannot fold the phone. Screenshots of the inner display come back black while the phone is closed.
- The outer display cannot be used by us. Apple only lets an app draw on it during an active camera session, and the simulator has no camera. Do not build anything that needs the outer display.
- Bitrig's Mac app has a 3D simulator where you drag the phone to fold it. We use it for the final demo if it opens our project.

## Team split, four hours

Kartik owns: `Core/`, `Hinge/`, `Presenter/`, `App/`, the pitch and the demo.
- Two-face layout with ArrangementView, audience half rotated 180.
- Hinge to mode: standing about 90 degrees is present, flat is edit, closed ends the session.
- Presenter half: notes, next slide, timer, laser trackpad.
- Laser dot on the audience half.

Teammate owns: `Audience/`, `Generate/`, `Editor/`.
1. Slide renderer with motion. Read `~/flipside-assets/motion/MOTION.md` and the storyboards. Title lands, body lines fade in, one thing moves at a time, nothing over 600 ms. Layouts: cover, statement, two-column, live, close. A `video` layout that plays a bundled MP4 is a stretch goal.
2. Generation: a chat input on the presenter half. Topic or pasted link in, deck streams onto the audience half slide by slide as it arrives. Use `~/flipside-assets/motion/GENERATION-PROMPT.md` as the system prompt. Model over the API, key from the event's OpenAI credits or an Anthropic key. Streaming state: title first, body lines appear as they land.
3. Editor: when the phone is flat, presenter half is the control desk (reorder slides by drag, edit title, body and notes, insert a video or an animation preset), audience half is the live preview of the current slide. Think a DJ booth or CapCut on the left, the show on the right.
4. Recap email when the session ends: from deck plus notes, through an email API or a prefilled compose sheet. A phone buzzing on stage is the goal.

Do them in that order. 1 and 2 before lunch. 3 and 4 after. If 3 runs long, cut the video insert and keep reorder plus text edit.

## Shared model, frozen after 11:45

`Core/DeckModel.swift` and `Core/AppState.swift`. Deck schema matches `~/flipside-assets/deck/deck.json`:

```
slide: id, layout (cover | statement | two-column | live | close), title, body, notes, cue, durationHint
```

AppState holds: deck, currentIndex, mode (present | edit | ended), hingeAngle, laserPoint (normalized, optional), isGenerating.

If you need a new field, add it, say so in the commit message, and tell Kartik in person. Never rename or remove a field.

## Assets already made, use them

- `~/flipside-assets/brand/` tokens.json (palette, type, spacing), app icon, mark, slide template backgrounds.
- `~/flipside-assets/deck/` deck.json (our six-slide pitch), slide PNGs at 1200x630 and 2400x1260, notes cards at 800x600, fallback-deck.json for when Wi-Fi dies, recap-template.md.
- `~/flipside-assets/motion/` MOTION.md, storyboards, motion previews, three example decks (realtor, founder, one more), GENERATION-PROMPT.md.
- `~/flipside-assets/ui/` mockups of present mode, edit mode, the fold transition, ended state, laser, and the hinge-angle to mode diagram.

Copy what you need into `Flipside/Resources/`. Do not edit the assets folders.

## Git rules

- Both on main. No branches.
- Only edit files in your folders, plus Core when adding a field.
- Never reformat, rename or move files outside your folders.
- Commit every 15 minutes. Before push: `git pull --rebase origin main`, then `xcodegen`, then build for the iPhone Duo simulator. Push only if it builds.
- Never commit `.xcodeproj`. Run `xcodegen` after every pull. New files go in your folder and xcodegen picks them up.
- If a rebase conflicts in a file you do not own, stop and talk to Kartik. Do not resolve it by guessing.

## Timeline

- 12:30 checkpoint: renderer shows one slide with motion. Kartik's two faces show the deck. Merge, build, both machines.
- 1:00 lunch. The pitch deck plays end to end on the standing phone. This is the minimum demo and it is locked.
- 1:30 checkpoint: generation streams. Hinge modes work. Merge.
- 2:30 checkpoint: editor, laser, recap. Merge. Anything not in by now does not ship.
- 2:45 feature freeze. Polish and bugs only.
- 3:00 record a backup video.
- 3:30 demos.

## The demo, 90 seconds

1. Phone standing at the corner of the table. Judges on the audience side. "You're the client, I'm the realtor." The pitch deck plays, notes on Kartik's side.
2. Tilt the phone back. The hinge drives it. Lay it flat, it becomes the editor, drag a slide.
3. Stand it up again. "Someone give me a topic." Deck streams in live.
4. Finger on the trackpad, dot on their slide.
5. Fold it shut. Say nothing. A judge's phone buzzes with the recap.

## Do not

- Build for the outer display or the camera.
- Change the deck schema without telling Kartik.
- Add accounts, cloud sync, PowerPoint export, or anything not listed above.
- Spend more than 20 minutes on any single bug. Cut it and move on.
