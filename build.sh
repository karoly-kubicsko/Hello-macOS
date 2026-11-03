#!/bin/bash
#
# Builds build/Hello.app, a universal (Apple silicon + Intel) macOS application bundle:
#
#   Hello.app/
#   └── Contents/
#       ├── Info.plist
#       ├── PkgInfo
#       ├── MacOS/Hello              (executable)
#       ├── Resources/AppIcon.icns
#       └── _CodeSignature/          (ad-hoc signature)
#
# Requirements: macOS 26 or later with Xcode or the Command Line Tools
# (install the latter with `xcode-select --install`).
#
# Usage: ./build.sh [--open]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLIST="$ROOT/Resources/Info.plist"
APP_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$APP" "$BUILD/obj"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/obj"

for arch in arm64 x86_64; do
    echo "==> Compiling $APP_NAME for $arch (macOS $MIN_MACOS+)"
    xcrun swiftc -O -parse-as-library \
        -sdk "$SDK" \
        -target "$arch-apple-macos$MIN_MACOS" \
        "$ROOT"/Sources/*.swift \
        -o "$BUILD/obj/$APP_NAME-$arch"
done

echo "==> Assembling $APP"
lipo -create "$BUILD/obj/$APP_NAME-arm64" "$BUILD/obj/$APP_NAME-x86_64" \
    -output "$APP/Contents/MacOS/$APP_NAME"
cp "$PLIST" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist" > /dev/null

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

# Make Finder and Launch Services pick up the (new) icon.
touch "$APP"

echo "==> Done: $APP ($(lipo -archs "$APP/Contents/MacOS/$APP_NAME"))"

if [[ "${1:-}" == "--open" ]]; then
    open "$APP"
fi
