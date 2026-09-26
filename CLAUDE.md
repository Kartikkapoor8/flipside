# Flipside

Presentation app for iPhone Duo. Full context in `FLIPSIDE-TEAMMATE-BRIEF.md`. Read it before writing code.

Build: `xcodegen` then build the `Flipside` scheme for the iPhone Duo simulator (Xcode 27.1 beta, iOS 27.1). Never commit `Flipside.xcodeproj`.

## Git rules

- Both on main. No branches.
- Only edit files in your folders, plus Core when adding a field.
- Never reformat, rename or move files outside your folders.
- Commit every 15 minutes. Before push: `git pull --rebase origin main`, then `xcodegen`, then build for the iPhone Duo simulator. Push only if it builds.
- Never commit `.xcodeproj`. Run `xcodegen` after every pull. New files go in your folder and xcodegen picks them up.
- If a rebase conflicts in a file you do not own, stop and talk to Kartik. Do not resolve it by guessing.

