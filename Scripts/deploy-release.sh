#!/bin/zsh
# Publish a notarized Chad Commander DMG and signed Sparkle appcast.

set -euo pipefail

APP_NAME="Chad Commander"
ARTIFACT_NAME="Chad-Commander"
PROJECT_DIR="${0:A:h:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$PROJECT_DIR/Build/$APP_NAME.app"
INFO_PLIST="$PROJECT_DIR/Info.plist"

# Deployment details are intentionally supplied by the maintainer's environment
# rather than committed to this public repository.
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_LANDING="${REMOTE_LANDING:-}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://chadcommander.org}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)

DRY_RUN="${DRY_RUN:-0}"
VERIFY_PUBLIC_RELEASE="${VERIFY_PUBLIC_RELEASE:-1}"

info() { printf '\033[1;34m=> %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m✓  %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗  %s\033[0m\n' "$*"; exit 1; }

[[ -f "$INFO_PLIST" ]] || fail "Info.plist not found."
[[ -d "$APP_PATH" ]] || fail "App bundle not found. Run ./Scripts/build-dmg.sh first."

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
DMG_NAME="$ARTIFACT_NAME-$VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
APPCAST_PATH="$DIST_DIR/appcast.xml"

[[ -f "$DMG_PATH" ]] || fail "DMG not found: $DMG_PATH"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
[[ "$APP_VERSION" == "$VERSION" && "$APP_BUILD" == "$BUILD_NUMBER" ]] \
    || fail "App bundle version does not match Info.plist. Rebuild before deploying."

info "Verifying signatures, notarization, and Sparkle configuration…"
codesign --verify --deep --strict "$APP_PATH"
xcrun stapler validate "$APP_PATH" >/dev/null 2>&1 \
    || fail "The app is not notarized and stapled."
xcrun stapler validate "$DMG_PATH" >/dev/null 2>&1 \
    || fail "The DMG is not notarized and stapled."
spctl --assess --type execute "$APP_PATH" >/dev/null 2>&1 \
    || fail "Gatekeeper rejected the app bundle."
spctl --assess --type open --context context:primary-signature "$DMG_PATH" >/dev/null 2>&1 \
    || fail "Gatekeeper rejected the DMG."

APP_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
[[ -n "$APP_PUBLIC_KEY" && "$APP_PUBLIC_KEY" != "REPLACE_WITH_PUBLIC_KEY_FROM_GENERATE_KEYS" ]] \
    || fail "The built app has no Sparkle public key."
APP_FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
[[ "$APP_FEED_URL" == "$PUBLIC_BASE_URL/appcast.xml" ]] \
    || fail "The built app feed ($APP_FEED_URL) does not match $PUBLIC_BASE_URL/appcast.xml."
ok "Release artifacts are Gatekeeper-ready"

SIGN_UPDATE_BIN="$(find "$PROJECT_DIR/.build/artifacts" -path '*/Sparkle/bin/sign_update' -type f -perm +111 2>/dev/null | head -n 1)"
GENERATE_KEYS_BIN="$(find "$PROJECT_DIR/.build/artifacts" -path '*/Sparkle/bin/generate_keys' -type f -perm +111 2>/dev/null | head -n 1)"
[[ -n "$SIGN_UPDATE_BIN" ]] || fail "Sparkle sign_update was not found. Run swift package resolve."
[[ -n "$GENERATE_KEYS_BIN" ]] || fail "Sparkle generate_keys was not found. Run swift package resolve."

SIGNING_PUBLIC_KEY="$($GENERATE_KEYS_BIN -p 2>/dev/null | tr -d '[:space:]')"
[[ "$SIGNING_PUBLIC_KEY" == "$APP_PUBLIC_KEY" ]] \
    || fail "The Sparkle signing key does not match SUPublicEDKey in the built app."

info "Creating the Sparkle update archive…"
mkdir -p "$DIST_DIR"
TMP_ZIP="$(mktemp "$DIST_DIR/.$ARTIFACT_NAME-$VERSION-$BUILD_NUMBER.XXXXXX.zip")"
trap 'rm -f "${TMP_ZIP:-}" "${NEW_ITEM_PATH:-}" "${PUBLIC_ZIP_PATH:-}"' EXIT
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$TMP_ZIP"
ZIP_SIZE="$(stat -f%z "$TMP_ZIP")"
ZIP_SHA256="$(shasum -a 256 "$TMP_ZIP" | awk '{ print $1 }')"
ZIP_NAME="$ARTIFACT_NAME-$VERSION-$BUILD_NUMBER-${ZIP_SHA256[1,12]}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
mv -f "$TMP_ZIP" "$ZIP_PATH"
TMP_ZIP=""

SIGN_OUTPUT="$($SIGN_UPDATE_BIN "$ZIP_PATH")"
EDSIG_VALUE="$(print -r -- "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
[[ -n "$EDSIG_VALUE" ]] || fail "Could not parse Sparkle signature: $SIGN_OUTPUT"
$SIGN_UPDATE_BIN --verify "$ZIP_PATH" "$EDSIG_VALUE"

VERIFY_DIR="$(mktemp -d)"
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
codesign --verify --deep --strict "$VERIFY_DIR/$APP_NAME.app"
rm -rf "$VERIFY_DIR"
ok "Signed $ZIP_NAME"

PUB_DATE="$(LC_ALL=C date -u +'%a, %d %b %Y %H:%M:%S +0000')"
RELEASE_NOTES_DEFAULT="$DIST_DIR/release-notes-$VERSION.html"
if [[ -n "${RELEASE_NOTES:-}" && -f "$RELEASE_NOTES" ]]; then
    NOTES_HTML="$(<"$RELEASE_NOTES")"
elif [[ -f "$RELEASE_NOTES_DEFAULT" ]]; then
    NOTES_HTML="$(<"$RELEASE_NOTES_DEFAULT")"
else
    NOTES_HTML="<h2>$APP_NAME $VERSION</h2><p>Bug fixes and improvements.</p>"
fi

NEW_ITEM="        <item>
            <title>Version $VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <description><![CDATA[$NOTES_HTML]]></description>
            <enclosure url=\"$PUBLIC_BASE_URL/$ZIP_NAME\" type=\"application/octet-stream\" sparkle:edSignature=\"$EDSIG_VALUE\" length=\"$ZIP_SIZE\"/>
        </item>"

NEW_ITEM_PATH="$(mktemp -t chad-commander-appcast-item.XXXXXX.xml)"
print -r -- "$NEW_ITEM" > "$NEW_ITEM_PATH"

info "Updating appcast.xml…"
if [[ -f "$APPCAST_PATH" ]] && grep -q '<channel>' "$APPCAST_PATH"; then
    awk -v ver="$VERSION" '
        BEGIN { in_item = 0 }
        /<item>/ { buffer = $0; in_item = 1; has_version = 0; next }
        in_item {
            buffer = buffer "\n" $0
            if ($0 ~ "<sparkle:shortVersionString>" ver "</sparkle:shortVersionString>") has_version = 1
            if ($0 ~ /<\/item>/) {
                if (!has_version) print buffer
                in_item = 0
                buffer = ""
            }
            next
        }
        { print }
    ' "$APPCAST_PATH" > "$APPCAST_PATH.tmp"
    awk -v item_path="$NEW_ITEM_PATH" '
        /<channel>/ && !inserted {
            print
            while ((getline line < item_path) > 0) print line
            close(item_path)
            inserted = 1
            next
        }
        { print }
    ' "$APPCAST_PATH.tmp" > "$APPCAST_PATH"
    rm -f "$APPCAST_PATH.tmp"
else
    cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>$APP_NAME</title>
        <link>$PUBLIC_BASE_URL/appcast.xml</link>
        <description>Most recent $APP_NAME updates.</description>
        <language>en</language>
$NEW_ITEM
    </channel>
</rss>
EOF
fi

if [[ "$DRY_RUN" == "1" ]]; then
    info "DRY_RUN=1 — prepared locally without uploading:"
    print "  $DMG_PATH"
    print "  $ZIP_PATH"
    print "  $APPCAST_PATH"
    exit 0
fi

[[ -n "$REMOTE_HOST" ]] || fail "REMOTE_HOST is required for deployment."
[[ -n "$REMOTE_USER" ]] || fail "REMOTE_USER is required for deployment."
[[ -n "$REMOTE_LANDING" ]] || fail "REMOTE_LANDING is required for deployment."

SSH_CMD=(ssh "${SSH_OPTS[@]}")
RSYNC_RSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
info "Testing SSH connection…"
if ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$REMOTE_USER@$REMOTE_HOST" 'echo ok' >/dev/null 2>&1; then
    ok "Using SSH key authentication"
else
    command -v sshpass >/dev/null || fail "SSH key authentication failed and sshpass is not installed."
    read -rs "SSHPASS?SSH password for $REMOTE_USER@$REMOTE_HOST: "
    print
    export SSHPASS
    SSH_CMD=(sshpass -e ssh "${SSH_OPTS[@]}")
    RSYNC_RSH="sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
    "${SSH_CMD[@]}" "$REMOTE_USER@$REMOTE_HOST" 'echo ok' >/dev/null \
        || fail "Cannot connect to $REMOTE_HOST."
fi

"${SSH_CMD[@]}" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_LANDING'"

info "Uploading release artifacts…"
rsync -azP -e "$RSYNC_RSH" "$DMG_PATH" "$ZIP_PATH" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_LANDING/"
rsync -az -e "$RSYNC_RSH" "$APPCAST_PATH" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_LANDING/"

if [[ "$VERIFY_PUBLIC_RELEASE" == "1" ]]; then
    info "Verifying the public update payload…"
    PUBLIC_ZIP_PATH="$(mktemp -t chad-commander-public.XXXXXX.zip)"
    curl -fsSL "$PUBLIC_BASE_URL/$ZIP_NAME" -o "$PUBLIC_ZIP_PATH"
    PUBLIC_SHA256="$(shasum -a 256 "$PUBLIC_ZIP_PATH" | awk '{ print $1 }')"
    [[ "$PUBLIC_SHA256" == "$ZIP_SHA256" ]] || fail "Public ZIP checksum does not match."
    $SIGN_UPDATE_BIN --verify "$PUBLIC_ZIP_PATH" "$EDSIG_VALUE"
    ok "Public ZIP and Sparkle signature verified"
fi

ok "Deployed $APP_NAME $VERSION"
print "DMG:     $PUBLIC_BASE_URL/$DMG_NAME"
print "Appcast: $PUBLIC_BASE_URL/appcast.xml"
