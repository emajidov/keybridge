#!/bin/bash
# Builds KeyBridge.app into ./build (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")"

# Command Line Tools (without full Xcode) lack the SwiftUI macro plugin required by newer SDKs,
# so fall back to the newest installed SDK where SwiftUI's @State is still a plain property wrapper.
if [[ -z "${SDKROOT:-}" && "$(xcode-select -p)" == *CommandLineTools* ]]; then
    for sdk in $(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX[0-9]*.sdk | sort -rV); do
        frameworks="$sdk/System/Library/Frameworks"
        [[ -d "$frameworks/SwiftUI.framework" ]] || continue
        if ! grep -rqs "macro State" --include='*-macos.swiftinterface' "$frameworks/SwiftUI.framework" "$frameworks/SwiftUICore.framework"; then
            export SDKROOT="$sdk"
            echo "Using SDK $SDKROOT"
            break
        fi
    done
fi

swift build -c release
APP=build/KeyBridge.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KeyBridge "$APP/Contents/MacOS/KeyBridge"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
