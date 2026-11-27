#!/bin/bash
# Builds a universal KeyBridge.app (ad-hoc signed) plus KeyBridge.dmg and KeyBridge.zip into ./build.
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

# Universal binary so the app runs on both Apple silicon and Intel Macs.
for arch in arm64 x86_64; do
    swift build -c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/$arch"
done
APP=build/KeyBridge.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/KeyBridge" \
    .build/arm64/release/KeyBridge .build/x86_64/release/KeyBridge
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

# Downloadable packages: a drag-to-Applications disk image and a zip.
DMG=build/KeyBridge.dmg
ZIP=build/KeyBridge.zip
STAGING=build/dmg
rm -rf "$STAGING" "$DMG" "$ZIP"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname KeyBridge -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGING"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Built $DMG"
echo "Built $ZIP"
