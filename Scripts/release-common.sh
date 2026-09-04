#!/bin/zsh

# Load machine-local release settings. This file contains destinations and
# Keychain references only; passwords and signing secrets stay in Keychain.
CHAD_RELEASE_CONFIG_FILE="${CHAD_RELEASE_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/chad-commander/release.env}"
if [[ -r "$CHAD_RELEASE_CONFIG_FILE" ]]; then
    source "$CHAD_RELEASE_CONFIG_FILE"
fi
