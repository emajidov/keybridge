# KeyBridge

A small macOS menu bar app for people who switch between Windows/Linux and Mac every day.
Keep pressing **Ctrl+C / Ctrl+V / Ctrl+Z …** on your Mac and KeyBridge sends the Mac equivalent (**⌘C / ⌘V / ⌘Z …**).
Your normal ⌘ shortcuts keep working.

## Features
- Ready-made Windows-style shortcuts: copy, paste, cut, select all, undo/redo (Ctrl+Y too), save, find, new, open, print, tabs, reload, bold/italic/underline.
- Windows text navigation: Ctrl+←/→ jumps words, Home/End go to line start/end, Ctrl+Home/End go to document start/end, Ctrl+Backspace deletes a word.
- "Also with Shift" option so Shift+Home, Ctrl+Shift+→ etc. select text like on Windows.
- Add, edit, disable, reorder or delete any shortcut by recording it.
- Excluded apps: terminals (so Ctrl+C still interrupts), virtual machines and remote desktops are skipped by default. Toggle the current app from the menu bar.
- Launch at login.

## Build & run
Requires macOS 13+ and Xcode or the Command Line Tools.

```bash
./build.sh
open build/KeyBridge.app
```

Optionally copy `build/KeyBridge.app` to `/Applications`.

On first launch, grant **Accessibility** access (System Settings → Privacy & Security → Accessibility → enable KeyBridge).
The app is ad-hoc signed, so after rebuilding you may need to remove KeyBridge from that list and add it again.

## Tests
```bash
swift test   # with Command Line Tools only, prefix with SDKROOT=<SDK chosen by build.sh>
```

## Notes
- macOS reserves some shortcuts (e.g. ⌃←/⌃→ switch Spaces). Turn those off in System Settings → Keyboard → Keyboard Shortcuts → Mission Control to use them for word jumps.
- Prefer a physical Ctrl⇄Cmd swap everywhere? macOS has that built in: System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys.
