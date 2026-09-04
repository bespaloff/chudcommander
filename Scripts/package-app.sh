#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/Build"
APP_DIR="$BUILD_DIR/Chad Commander.app"
APP_BINARY="$APP_DIR/Contents/MacOS/MacCommander"
ICON_SOURCE="$PROJECT_DIR/Sources/MacCommander/Resources/AppIcon.png"
ICON_COMPOSER_SOURCE="$PROJECT_DIR/Assets/AppIcon.icon"
cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(cd "$PROJECT_DIR" && swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"
cp "$BIN_DIR/MacCommander" "$APP_BINARY"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

SPARKLE_FRAMEWORK="$BIN_DIR/Sparkle.framework"
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
    print -u2 "Sparkle.framework was not produced by SwiftPM at $SPARKLE_FRAMEWORK"
    exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/"

# SwiftPM command-line executables use @loader_path, while a conventional app
# keeps third-party frameworks in Contents/Frameworks.
if ! otool -l "$APP_BINARY" | grep -Fq '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP_BINARY"
fi

for resource_bundle in "$BIN_DIR"/*.bundle(N); do
    cp -R "$resource_bundle" "$APP_DIR/Contents/Resources/"
done

ICON_WORK_DIR="$(mktemp -d)"

if [[ -d "$ICON_COMPOSER_SOURCE" ]] && xcrun --find actool >/dev/null 2>&1; then
    xcrun actool "$ICON_COMPOSER_SOURCE" \
        --compile "$ICON_WORK_DIR" \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --target-device mac \
        --app-icon AppIcon \
        --output-partial-info-plist "$ICON_WORK_DIR/AppIcon-Partial.plist" \
        --warnings --errors --notices \
        --output-format human-readable-text
    cp "$ICON_WORK_DIR/Assets.car" "$APP_DIR/Contents/Resources/Assets.car"
    cp "$ICON_WORK_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    ICONSET_DIR="$ICON_WORK_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"

    sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

rm -rf "$ICON_WORK_DIR"

SIGNING_IDENTITY="${CHAD_COMMANDER_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(
        security find-identity -v -p codesigning 2>/dev/null |
        sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' |
        head -n 1
    )"
fi

SPARKLE_VERSION_DIR="$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/Current"

sign_sparkle() {
    local sign_args=(--force --options runtime --sign "$1")
    if [[ "$1" != "-" ]]; then
        sign_args+=(--timestamp)
    fi

    for target in \
        "$SPARKLE_VERSION_DIR/XPCServices/Downloader.xpc" \
        "$SPARKLE_VERSION_DIR/XPCServices/Installer.xpc" \
        "$SPARKLE_VERSION_DIR/Updater.app" \
        "$SPARKLE_VERSION_DIR/Autoupdate" \
        "$APP_DIR/Contents/Frameworks/Sparkle.framework"; do
        [[ -e "$target" ]] && codesign "${sign_args[@]}" "$target"
    done
}

if [[ -n "$SIGNING_IDENTITY" ]]; then
    sign_sparkle "$SIGNING_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_DIR"
    print "Signed with $SIGNING_IDENTITY"
else
    sign_sparkle "-"
    codesign --force --options runtime --sign - "$APP_DIR"
    print "No Developer ID identity found; used an ad-hoc signature. Privacy grants may need to be renewed after rebuilding."
fi

codesign --verify --deep --strict "$APP_DIR"
print "$APP_DIR"
