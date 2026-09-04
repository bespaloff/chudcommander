# Chad Commander

A fast, native, keyboard-first dual-pane file manager for macOS. Chad Commander keeps the orthodox file-manager workflow—source on one side, destination on the other—while using macOS-native views, Quick Look, application discovery, Trash, and file icons.

## Included in this build

- Independent left and right panes with tabs, history, direct path entry, folder/volume shortcuts, list/grid views, hidden-file toggles, natural sorting, multi-selection, status counts, drag-and-drop copying between panes, and native file dragging to Finder or other apps.
- Total Commander-style actions: **F3** Quick Look, **F4** open, **F5** copy to the other pane, **F6** move, **Shift-F6** rename, **F7** new folder, and **F8** move to Trash.
- A selection-aware application bar that shows the macOS default application and offers every compatible “Open With” application.
- Direct, cancellable search independent of Spotlight: filename substring or regex, UTF-8/Latin-1 content, recursive/non-recursive scope, hidden-file scope, case sensitivity, file/folder filters, wildcard exclusions, and temporary result tabs.
- One persistent zsh session per pane. Opening or changing a pane synchronizes its shell; using `cd` in the shell synchronizes the pane.
- Background copy/move/trash operations with non-destructive conflict naming (`report copy.txt`) and progress feedback.
- Native Quick Look, contextual menus, multi-selection, light/dark appearance, and accessibility metadata.
- Optional cached folder-size calculation for the active tab, with a global automatic mode that is off by default.
- Optional default-folder handling with macOS consent and a one-click Finder restore in Settings.

## Requirements

- macOS 14 Sonoma or newer.
- Xcode 16.3 or newer, which includes the Swift 6.1 toolchain required by `Package.swift`.
- Xcode Command Line Tools selected in **Xcode → Settings → Locations**.
- Git and an internet connection for resolving the Sparkle and SwiftTerm packages on the first build.

Confirm the active developer tools before building:

```sh
xcodebuild -version
swift --version
xcode-select -p
```

If the tools are missing, install Xcode from the Mac App Store, open it once to finish setup, and select its Command Line Tools. `xcode-select --install` is sufficient for command-line builds when it provides Swift 6.1 or newer.

## Build from source

Clone the repository, resolve its Swift packages, run the test suite, and create the macOS app bundle:

```sh
git clone https://github.com/bespaloff/chudcommander.git
cd chudcommander
swift package resolve
swift test
make app
open "Build/Chad Commander.app"
```

`make app` performs a release build, embeds Sparkle and the SwiftPM resource bundles, generates the app icon, and signs the result. The finished application is at `Build/Chad Commander.app`.

For the normal edit/build/launch loop, run:

```sh
make run
```

You can also open `Package.swift` in Xcode, select the `MacCommander` scheme and **My Mac**, then press `Command-R`. No generated `.xcodeproj` is required.

Available Make targets:

| Command | Result |
|---|---|
| `make build` | Build a debug executable with SwiftPM |
| `make test` | Run the Swift test suite |
| `make app` | Create a signed release app in `Build/` |
| `make run` | Rebuild the app and launch it |
| `make clean` | Remove SwiftPM output and the packaged app |
| `make dmg` | Build a maintainer release DMG; signing credentials required |
| `make deploy` | Publish a maintainer release; deployment configuration required |

### Code signing and macOS permissions

The packaging script uses the first installed **Developer ID Application** identity. If none is available, it falls back to an ad-hoc signature, which is enough for local development. To select a particular identity, set it explicitly:

```sh
CHAD_COMMANDER_SIGNING_IDENTITY="Developer ID Application: Example (TEAMID)" make app
```

Because the app is downloaded from source and locally signed, macOS may require a Control-click → **Open** on first launch. The app is deliberately not sandboxed: a general-purpose file manager must be able to browse paths the user chooses. macOS still protects Desktop, Documents, Downloads, iCloud Drive, network volumes, and other sensitive locations. To approve access, open Chad Commander Settings (`Command-,`), choose **Open Full Disk Access Settings**, enable Chad Commander, and then choose **Relaunch Chad Commander**.

For a durable default-folder association, move the app to `/Applications`, open Chad Commander Settings, and choose **Use Chad Commander** under Folder Handling. Finder continues to own the Desktop, Trash, and system Open/Save dialogs.

## Updates and releases

Packaged builds check `https://chadcommander.org/appcast.xml` at launch and hourly, and users can choose **Chad Commander → Check for Updates…** at any time. Update archives are EdDSA-signed and verified by Sparkle before installation.

Maintainers with an Apple Developer ID certificate, notarization credentials, a Sparkle signing key, and a configured web host can produce and publish a release:

```sh
make dmg       # bumps the minor version, signs, notarizes, staples, creates DMG
make deploy    # signs ZIP, writes appcast, uploads and verifies
```

See [RELEASE.md](RELEASE.md) for one-time setup, environment overrides, and verification details.

## Keyboard reference

| Key | Action |
|---|---|
| `Tab` | Switch active pane |
| `F3` or `Space` | Quick Look selected file |
| `F4` | Open in default application |
| `Option-F4` | Toggle terminal in active pane |
| `F5` | Copy selection to opposite pane |
| `F6` | Move selection to opposite pane |
| `Shift-F6` | Rename |
| `F7` | New folder |
| `F8` | Move selection to Trash |
| `Command-F` | Search active location |
| `Command-T` | New active-pane tab |
| `Command-Option-S` | Calculate folder sizes in the active tab |

On Apple keyboards configured to use media controls, hold `fn` with an F-key or enable “Use F1, F2, etc. keys as standard function keys” in System Settings.

## Architecture

The application is native Swift 6 with Sparkle and SwiftTerm as its external runtime dependencies. `PaneModel` owns independent tab/history/selection state, `FileSystemService` performs direct Foundation filesystem access, `SearchEngine` runs cancellable scans away from the main actor, `OperationCenter` serializes safe operations, and `TerminalSession` owns one long-running login shell. The pane model already distinguishes real and virtual result tabs, leaving a clean seam for future archive and remote providers.

See [docs/COMPETITOR-RESEARCH.md](docs/COMPETITOR-RESEARCH.md) for the research and product decisions behind the build.

## License

Chad Commander is available under the permissive [MIT License](LICENSE).
