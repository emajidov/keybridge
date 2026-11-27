# Changelog

All notable changes to this project are documented here. This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]
### Added
- Install with Homebrew: `brew install --cask emajidov/tap/keybridge`.

## [1.1.0]
### Added
- "Show menu bar icon" setting and "Hide Menu Bar Icon" menu item: hide the icon while remapping keeps working.
- "Keep running after Quit" setting (on by default): Quit only hides the menu bar icon so shortcuts keep working. "Quit Completely" in Settings stops KeyBridge. Opening KeyBridge again shows the icon and settings.
- WezTerm, Hyper and Tabby are excluded by default (new installs or "Restore defaults").

## [1.0.1]
### Added
- App icon (also used on the website and in the README).

## [1.0.0]
### Added
- First public release. Windows/Linux Ctrl shortcuts remapped to their Mac equivalents, Windows text navigation, custom shortcut recording, excluded apps and launch at login.
- Universal (Apple silicon + Intel) app, shipped as a drag-to-install `KeyBridge.dmg` and as `KeyBridge.zip`.
