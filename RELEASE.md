# Releasing Chad Commander

Sparkle polls a static HTTPS appcast, verifies a signed ZIP, then atomically installs and relaunches the app. The DMG is for first-time installs; Sparkle updates use the ZIP generated from the same notarized app bundle.

## Normal release flow

```sh
./Scripts/build-dmg.sh
open "dist/Chad-Commander-<version>.dmg"
# Install and smoke-test it, then:
./Scripts/deploy-release.sh
```

`build-dmg.sh` increments the minor version and build number by default. Set `AUTO_BUMP_MINOR=0` when rebuilding the same version.

The deploy script publishes the DMG, update ZIP, and appcast to a maintainer-configured SSH destination. Set `REMOTE_HOST`, `REMOTE_USER`, and `REMOTE_LANDING` for every real deployment. `PUBLIC_BASE_URL` defaults to `https://chadcommander.org` and can also be overridden.

## One-time setup

Install a Developer ID Application certificate and store notarization credentials in the `notarytool` keychain profile:

```sh
xcrun notarytool store-credentials notarytool \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID
```

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

The deploy step refuses an unstapled build, creates a content-addressed ZIP, signs and locally verifies it, updates `appcast.xml`, uploads the release artifacts, then downloads the public ZIP and verifies its checksum and Sparkle signature.
