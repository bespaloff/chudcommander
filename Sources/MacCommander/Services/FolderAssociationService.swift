import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class FolderAssociationService: ObservableObject {
    @Published private(set) var currentHandlerName = "Checking…"
    @Published private(set) var isChadCommanderDefault = false
    @Published private(set) var isFinderDefault = false
    @Published private(set) var isWorking = false
    @Published private(set) var message: String?

    var installationNote: String? {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL.path
        guard path.hasPrefix("/Applications/") || path.hasPrefix(userApplications + "/") else {
            return "For a durable default, move Chad Commander to Applications before enabling this."
        }
        return nil
    }

    func refresh() {
        let handlerURL = NSWorkspace.shared.urlForApplication(toOpen: .folder)
        let bundle = handlerURL.flatMap(Bundle.init(url:))
        let bundleID = bundle?.bundleIdentifier

        currentHandlerName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? handlerURL?.deletingPathExtension().lastPathComponent
            ?? "Unknown"
        isChadCommanderDefault = bundleID == Bundle.main.bundleIdentifier
        isFinderDefault = bundleID == "com.apple.finder"
    }

    func makeChadCommanderDefault() {
        setDefaultApplication(at: Bundle.main.bundleURL, successMessage: "Chad Commander now opens folders by default.")
    }

    func restoreFinder() {
        guard let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") else {
            message = "Finder could not be located."
            return
        }
        setDefaultApplication(at: finderURL, successMessage: "Finder is the default folder viewer again.")
    }

    private func setDefaultApplication(at applicationURL: URL, successMessage: String) {
        guard !isWorking else { return }
        isWorking = true
        message = nil

        Task {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: applicationURL, toOpen: .folder)
                message = successMessage
            } catch {
                message = "Could not change the folder viewer: \(error.localizedDescription)"
            }
            isWorking = false
            refresh()
        }
    }
}
