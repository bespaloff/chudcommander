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
