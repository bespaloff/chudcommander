#!/bin/zsh
# One-time setup for unattended Chad Commander releases.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/release-common.sh"

MODE="${1:-setup}"
[[ "$MODE" == "setup" || "$MODE" == "--check" ]] || {
    print -u2 "Usage: $0 [--check]"
    exit 2
}

KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-${CHAD_RELEASE_NOTARY_PROFILE:-notarytool}}"
NOTARY_KEYCHAIN="${NOTARY_KEYCHAIN:-${CHAD_RELEASE_NOTARY_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}}"
REMOTE_HOST="${REMOTE_HOST:-${CHAD_RELEASE_REMOTE_HOST:-}}"
REMOTE_USER="${REMOTE_USER:-${CHAD_RELEASE_REMOTE_USER:-}}"
REMOTE_LANDING="${REMOTE_LANDING:-${CHAD_RELEASE_REMOTE_LANDING:-}}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-${CHAD_RELEASE_PUBLIC_BASE_URL:-https://chadcommander.org}}"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10)

info() { printf '\033[1;34m=> %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m✓  %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗  %s\033[0m\n' "$*"; exit 1; }

check_notary_profile() {
    xcrun notarytool history \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --keychain "$NOTARY_KEYCHAIN" \
        >/dev/null 2>&1
}

prompt_if_empty() {
    local variable_name="$1"
    local prompt="$2"
    local current_value="${(P)variable_name:-}"

    if [[ -z "$current_value" ]]; then
        [[ -t 0 ]] || fail "$variable_name is required. Run make setup-release in an interactive terminal."
        read "$variable_name?$prompt"
    fi
}

if [[ "$MODE" == "setup" ]] && ! check_notary_profile; then
    SIGNING_IDENTITY="$({
        security find-identity -v -p codesigning 2>/dev/null |
            sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' |
            head -n 1
    })"
    APPLE_TEAM_ID="${APPLE_TEAM_ID:-${CHAD_RELEASE_APPLE_TEAM_ID:-}}"
    if [[ -z "$APPLE_TEAM_ID" ]]; then
        APPLE_TEAM_ID="$(print -r -- "$SIGNING_IDENTITY" | sed -n 's/.*(\([A-Z0-9]\{10\}\))$/\1/p')"
    fi
    NOTARY_APPLE_ID="${NOTARY_APPLE_ID:-}"

    [[ -n "$APPLE_TEAM_ID" ]] || fail "APPLE_TEAM_ID is required because it could not be read from the signing identity."
    prompt_if_empty NOTARY_APPLE_ID "Apple ID used for notarization: "

    info "Saving notarization credentials in the login Keychain profile '$KEYCHAIN_PROFILE'…"
    print "Enter the Apple app-specific password once when notarytool asks for it."
    xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" \
        --apple-id "$NOTARY_APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --keychain "$NOTARY_KEYCHAIN" \
        --validate
    check_notary_profile || fail "The saved notarization profile could not be validated."
    ok "Notarization credentials saved"
elif check_notary_profile; then
    ok "Notarization profile '$KEYCHAIN_PROFILE' is ready"
else
    fail "Notarization profile '$KEYCHAIN_PROFILE' is missing. Run make setup-release once."
fi

if [[ "$MODE" == "setup" ]]; then
    prompt_if_empty REMOTE_HOST "SSH host: "
    prompt_if_empty REMOTE_USER "SSH user: "
    prompt_if_empty REMOTE_LANDING "Remote release directory: "

    mkdir -p "${CHAD_RELEASE_CONFIG_FILE:h}"
    umask 077
    {
        print -r -- "CHAD_RELEASE_NOTARY_PROFILE=${(q)KEYCHAIN_PROFILE}"
        print -r -- "CHAD_RELEASE_NOTARY_KEYCHAIN=${(q)NOTARY_KEYCHAIN}"
        print -r -- "CHAD_RELEASE_REMOTE_HOST=${(q)REMOTE_HOST}"
        print -r -- "CHAD_RELEASE_REMOTE_USER=${(q)REMOTE_USER}"
        print -r -- "CHAD_RELEASE_REMOTE_LANDING=${(q)REMOTE_LANDING}"
        print -r -- "CHAD_RELEASE_PUBLIC_BASE_URL=${(q)PUBLIC_BASE_URL}"
    } >| "$CHAD_RELEASE_CONFIG_FILE"
    chmod 600 "$CHAD_RELEASE_CONFIG_FILE"
    ok "Release settings saved to $CHAD_RELEASE_CONFIG_FILE"
fi

[[ -n "$REMOTE_HOST" && -n "$REMOTE_USER" && -n "$REMOTE_LANDING" ]] \
    || fail "Release destination is not configured. Run make setup-release once."

info "Checking passwordless SSH access…"
ssh "${SSH_OPTS[@]}" "$REMOTE_USER@$REMOTE_HOST" 'printf ok' >/dev/null \
    || fail "SSH key authentication failed for $REMOTE_USER@$REMOTE_HOST. Install an SSH public key on the server; password fallback is intentionally disabled."
ok "Release credentials and destination are ready"
