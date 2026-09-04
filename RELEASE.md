# Releasing Chad Commander

Sparkle polls a static HTTPS appcast, verifies a signed ZIP, then atomically installs and relaunches the app. The DMG is for first-time installs; Sparkle updates use the ZIP generated from the same notarized app bundle.

## Normal release flow

```sh
make release
```

This verifies saved credentials, runs the tests, increments the minor version and build number, signs and notarizes the app and DMG, publishes the Sparkle update, and verifies the public download. It does not prompt for passwords. Set `AUTO_BUMP_MINOR=0` when rebuilding the same version.

The deploy script publishes the DMG, update ZIP, and appcast to the SSH destination saved by `make setup-release`. `REMOTE_HOST`, `REMOTE_USER`, `REMOTE_LANDING`, and `PUBLIC_BASE_URL` can still override those settings for a single run.

## One-time credential setup

Install a Developer ID Application certificate, then run:

```sh
make setup-release
```

The setup asks for the Apple ID and SSH destination. Apple's `notarytool` then asks once for the app-specific password and stores it in the macOS login Keychain under the `notarytool` profile. The password is never placed in a config file, environment variable, command argument, or repository. The non-secret destination and Keychain references are saved with mode `600` at `~/.config/chad-commander/release.env`.

SSH uploads require public-key authentication and deliberately have no password fallback. Once setup succeeds, `make release` is unattended. Run `make setup-release` again to replace missing or expired notarization credentials, and use `./Scripts/setup-release.sh --check` for a read-only preflight.

The app's Sparkle public EdDSA key is committed as `SUPublicEDKey`; its private half must remain in the maintainer's login Keychain and must never be committed. Sparkle's `generate_keys` utility creates or retrieves the signing key. Before releasing, verify that `generate_keys -p` matches `SUPublicEDKey` in `Info.plist`.

Sparkle's release tools come from the resolved Swift package under `.build/artifacts`, so running `swift package resolve` is sufficient on a new checkout.

## Release notes

Place optional HTML notes at `dist/release-notes-<version>.html`, or set `RELEASE_NOTES=/path/to/notes.html`. Otherwise the appcast uses a generic bug-fixes message.

## Useful overrides

```sh
AUTO_BUMP_MINOR=0 ./Scripts/build-dmg.sh
SKIP_NOTARIZE=1 ./Scripts/build-dmg.sh        # local testing only; deploy rejects it
DRY_RUN=1 ./Scripts/deploy-release.sh         # prepare ZIP/appcast; do not upload
VERIFY_PUBLIC_RELEASE=0 ./Scripts/deploy-release.sh
```

For a real deployment, provide the SSH destination explicitly:

```sh
REMOTE_HOST=downloads.example.com \
REMOTE_USER=deploy \
REMOTE_LANDING=/srv/www/chadcommander \
PUBLIC_BASE_URL=https://downloads.example.com \
./Scripts/deploy-release.sh
```

Explicit environment values override the saved machine-local configuration.

The deploy step refuses an unstapled build, creates a content-addressed ZIP, signs and locally verifies it, updates `appcast.xml`, uploads the release artifacts, then downloads the public ZIP and verifies its checksum and Sparkle signature.
