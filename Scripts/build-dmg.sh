#!/bin/zsh
# Build, Developer ID-sign, notarize, staple, and package Chad Commander.

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_NAME="Chad Commander"
ARTIFACT_NAME="Chad-Commander"
INFO_PLIST="$PROJECT_DIR/Info.plist"
APP_PATH="$PROJECT_DIR/Build/$APP_NAME.app"
DIST_DIR="${1:-$PROJECT_DIR/dist}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notarytool}"
AUTO_BUMP_MINOR="${AUTO_BUMP_MINOR:-1}"
STAGING_DIR=""

fail() { print -u2 "ERROR: $*"; exit 1; }

cleanup() {
    [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]] && rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

set_plist_string() {
    local key="$1"
    local value="$2"
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$INFO_PLIST"
}

bump_minor_version() {
    local current_version current_build major minor patch new_version
    local -a version_parts

    current_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
    current_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
    version_parts=("${(@s:.:)current_version}")
    major="${version_parts[1]:-0}"
    minor="${version_parts[2]:-0}"
    patch="${version_parts[3]:-}"

    [[ "$major" == <-> && "$minor" == <-> && "$current_build" == <-> ]] \
        || fail "Bundle versions must contain only numeric components."

    minor=$((minor + 1))
    new_version="$major.$minor"
    [[ -n "$patch" ]] && new_version="$new_version.0"

    set_plist_string CFBundleShortVersionString "$new_version"
    set_plist_string CFBundleVersion "$((current_build + 1))"
    print "Version bumped: $current_version ($current_build) -> $new_version ($((current_build + 1)))"
}

if [[ "$AUTO_BUMP_MINOR" == "1" ]]; then
    bump_minor_version
else
    print "Version bump skipped (AUTO_BUMP_MINOR=0)"
fi

SIGNING_IDENTITY="${CHAD_COMMANDER_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(
        security find-identity -v -p codesigning 2>/dev/null |
        sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' |
        head -n 1
    )"
fi
[[ -n "$SIGNING_IDENTITY" ]] || fail "No Developer ID Application identity is installed."

if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1 \
        || fail "No usable notarytool profile named '$KEYCHAIN_PROFILE'."
fi

print "Building and signing $APP_NAME…"
CHAD_COMMANDER_SIGNING_IDENTITY="$SIGNING_IDENTITY" "$PROJECT_DIR/Scripts/package-app.sh"

[[ -d "$APP_PATH" ]] || fail "Packaged app not found at $APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_PATH="$DIST_DIR/$ARTIFACT_NAME-$VERSION.dmg"
mkdir -p "$DIST_DIR"

STAGING_DIR="$(mktemp -d)"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

print "Creating $DMG_PATH…"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
    print "Skipping notarization; this DMG must not be deployed."
    print "$DMG_PATH"
    exit 0
fi

print "Submitting DMG to Apple Notary Service…"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

print "Stapling tickets…"
xcrun stapler staple "$DMG_PATH"
xcrun stapler staple "$APP_PATH"

xcrun stapler validate "$DMG_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type open --context context:primary-signature "$DMG_PATH"
spctl --assess --type execute "$APP_PATH"

print "Release DMG ready: $DMG_PATH"
