# Contributing to KeyBridge

Thanks for helping! Bug reports, shortcut ideas and pull requests are welcome.

## Reporting bugs and requesting features
- Search [existing issues](https://github.com/emajidov/keybridge/issues) first.
- For bugs, include your macOS version, the KeyBridge version, the app you were typing in, and the shortcut that misbehaved.

## Development
Requires macOS 13+ and Xcode or the Command Line Tools.

```bash
./build.sh               # builds build/KeyBridge.app, KeyBridge.dmg and KeyBridge.zip
open build/KeyBridge.app
swift test               # runs unit tests
```

Project layout:
- `Sources/KeyBridge/KeyRemapper.swift` — the event tap that rewrites key events
- `Sources/KeyBridge/Models.swift` — rules, key codes, default shortcuts and excluded apps
- `Sources/KeyBridge/AppState.swift` — settings persistence and app state
- `Sources/KeyBridge/Views.swift` — SwiftUI menu bar and settings UI
- `scripts/make-icon.swift` — draws the app icon; run `swift scripts/make-icon.swift` to regenerate `Resources/AppIcon.icns`
- `docs/` — the project website (GitHub Pages)

## Pull requests
1. Fork the repo and create a branch from `main`.
2. Keep changes focused. Add or update tests in `Tests/KeyBridgeTests` when you change matching logic.
3. Make sure `swift build` and `swift test` pass.
4. Add a line to the "Unreleased" section of [CHANGELOG.md](CHANGELOG.md).

By submitting a contribution, you agree that it is licensed under the [Apache License 2.0](LICENSE).
