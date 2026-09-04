import AppKit
import Foundation
import Sparkle

@MainActor
final class ApplicationOpenCoordinator {
    static let shared = ApplicationOpenCoordinator()

    private var handler: (([URL]) -> Void)?
    private var pendingURLs: [URL] = []

    private init() {}

    func install(handler: @escaping ([URL]) -> Void) {
        self.handler = handler
        guard !pendingURLs.isEmpty else { return }
        let urls = pendingURLs
        pendingURLs = []
        handler(urls)
    }

    func receive(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if let handler {
            handler(urls)
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }
}

@MainActor
final class ChadCommanderApplicationDelegate: NSObject, NSApplicationDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    /// Matches the identifier SwiftUI derives from the `Window` scene's id.
    static let windowIdentifier = "commander"

    private(set) var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        updaterController?.updater.checkForUpdatesInBackground()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        ApplicationOpenCoordinator.shared.receive(urls)
        showCommanderWindow()
    }

    /// Clicking the dock icon brings the one commander window back rather than
    /// opening a second one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showCommanderWindow() }
        return true
    }

    private func showCommanderWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let commander = NSApp.windows.first { $0.identifier?.rawValue.contains(Self.windowIdentifier) == true }
        (commander ?? NSApp.windows.first { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }

    @objc func checkForUpdates(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        updaterController?.checkForUpdates(sender)
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard handleShowingUpdate else { return }
        NSApp.activate(ignoringOtherApps: true)
    }
}
