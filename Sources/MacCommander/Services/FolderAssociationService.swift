import AppKit
import Combine
import Foundation

@MainActor
final class FolderAssociationService: ObservableObject {
    nonisolated static let finderBundleIdentifier = "com.apple.finder"

    @Published private(set) var currentHandlerName = "Checking…"
    @Published private(set) var isChadCommanderDefault = false
    @Published private(set) var isFinderDefault = false
    @Published private(set) var isWorking = false
    @Published private(set) var message: String?

    private let preferences = FolderAssociationPreferences()

    var installationNote: String? {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL.path
        guard path.hasPrefix("/Applications/") || path.hasPrefix(userApplications + "/") else {
            return "Move Chad Commander to Applications before making it the default folder viewer."
        }
        return nil
    }

    var canMakeChadCommanderDefault: Bool {
        installationNote == nil && Bundle.main.bundleIdentifier != nil
    }

    func refresh() {
        let launchServicesHandlerURL = NSWorkspace.shared.urlForApplication(toOpen: .folder)
        let launchServicesBundleID = launchServicesHandlerURL
            .flatMap(Bundle.init(url:))?
            .bundleIdentifier
        let bundleID = Self.resolvedFolderHandlerBundleIdentifier(
            launchServicesBundleIdentifier: launchServicesBundleID,
            configuredFolderHandlerBundleIdentifier: preferences.configuredFolderHandlerBundleIdentifier
        )

        let handlerURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        let bundle = handlerURL.flatMap(Bundle.init(url:))
        let needsRestart = launchServicesBundleID.map {
            !Self.bundleIdentifiersMatch($0, bundleID)
        } ?? false

        currentHandlerName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? handlerURL?.deletingPathExtension().lastPathComponent
            ?? Self.displayName(for: bundleID)
        if needsRestart {
            currentHandlerName += " (restart required)"
        }
        isChadCommanderDefault = Bundle.main.bundleIdentifier.map {
            Self.bundleIdentifiersMatch(bundleID, $0)
        } ?? false
        isFinderDefault = Self.bundleIdentifiersMatch(bundleID, Self.finderBundleIdentifier)
    }

    func makeChadCommanderDefault() {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            message = "The packaged Chad Commander app is required to change the folder viewer."
            return
        }
        guard canMakeChadCommanderDefault else {
            message = installationNote
            return
        }
        setFolderHandler(
            bundleIdentifier: bundleID,
            preferredFileViewerBundleIdentifier: bundleID,
            successMessage: "Chad Commander will become the preferred folder viewer after you restart your Mac."
        )
    }

    func restoreFinder() {
        guard NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.finderBundleIdentifier
        ) != nil else {
            message = "Finder could not be located."
            return
        }
        setFolderHandler(
            bundleIdentifier: Self.finderBundleIdentifier,
            preferredFileViewerBundleIdentifier: nil,
            successMessage: "Finder will become the preferred folder viewer after you restart your Mac."
        )
    }

    private func setFolderHandler(
        bundleIdentifier: String,
        preferredFileViewerBundleIdentifier: String?,
        successMessage: String
    ) {
        guard !isWorking else { return }
        isWorking = true
        message = nil

        do {
            try preferences.setFolderHandlerBundleIdentifier(
                bundleIdentifier,
                preferredFileViewerBundleIdentifier: preferredFileViewerBundleIdentifier
            )
            message = successMessage
        } catch {
            message = "Could not change the folder viewer: \(error.localizedDescription)"
        }
        isWorking = false
        refresh()
    }

    private static func displayName(for bundleID: String) -> String {
        bundleID == finderBundleIdentifier ? "Finder" : bundleID
    }

    nonisolated static func resolvedFolderHandlerBundleIdentifier(
        launchServicesBundleIdentifier: String?,
        configuredFolderHandlerBundleIdentifier: String?
    ) -> String {
        configuredFolderHandlerBundleIdentifier
            ?? launchServicesBundleIdentifier
            ?? finderBundleIdentifier
    }

    nonisolated static func bundleIdentifiersMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}

struct FolderAssociationPreferences {
    private static let fileViewerKey = "NSFileViewer"
    private static let launchServicesApplicationID =
        "com.apple.LaunchServices/com.apple.launchservices.secure"
    private static let launchServicesHandlersKey = "LSHandlers"
    private static let folderContentType = "public.folder"

    var preferredFileViewerBundleIdentifier: String? {
        CFPreferencesCopyValue(
            Self.fileViewerKey as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? String
    }

    var launchServicesHandlers: [[String: Any]] {
        CFPreferencesCopyValue(
            Self.launchServicesHandlersKey as CFString,
            Self.launchServicesApplicationID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? [[String: Any]] ?? []
    }

    var configuredFolderHandlerBundleIdentifier: String? {
        Self.folderHandlerBundleIdentifier(in: launchServicesHandlers)
            ?? preferredFileViewerBundleIdentifier
    }

    func setFolderHandlerBundleIdentifier(
        _ bundleIdentifier: String,
        preferredFileViewerBundleIdentifier: String?
    ) throws {
        let oldFileViewer = CFPreferencesCopyValue(
            Self.fileViewerKey as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        let oldHandlers = CFPreferencesCopyValue(
            Self.launchServicesHandlersKey as CFString,
            Self.launchServicesApplicationID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )

        CFPreferencesSetValue(
            Self.fileViewerKey as CFString,
            preferredFileViewerBundleIdentifier as CFString?,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        guard CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) else {
            restore(fileViewer: oldFileViewer, handlers: oldHandlers)
            throw PreferenceError.couldNotSaveFileViewerPreference
        }

        let updatedHandlers = Self.replacingFolderHandler(
            in: launchServicesHandlers,
            with: bundleIdentifier
        )
        CFPreferencesSetValue(
            Self.launchServicesHandlersKey as CFString,
            updatedHandlers as CFArray,
            Self.launchServicesApplicationID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        guard CFPreferencesSynchronize(
            Self.launchServicesApplicationID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) else {
            restore(fileViewer: oldFileViewer, handlers: oldHandlers)
            throw PreferenceError.couldNotSaveLaunchServicesPreference
        }
    }

    static func folderHandlerBundleIdentifier(in handlers: [[String: Any]]) -> String? {
        handlers.reversed().lazy.compactMap { handler -> String? in
            guard handler["LSHandlerContentType"] as? String == folderContentType else {
                return nil
            }
            return handler["LSHandlerRoleAll"] as? String
        }.first
    }

    static func replacingFolderHandler(
        in handlers: [[String: Any]],
        with bundleIdentifier: String
    ) -> [[String: Any]] {
        var updatedHandlers = handlers.filter {
            $0["LSHandlerContentType"] as? String != folderContentType
        }
        updatedHandlers.append([
            "LSHandlerContentType": folderContentType,
            "LSHandlerRoleAll": bundleIdentifier
        ])
        return updatedHandlers
    }

    private func restore(fileViewer: CFPropertyList?, handlers: CFPropertyList?) {
        CFPreferencesSetValue(
            Self.fileViewerKey as CFString,
            fileViewer,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        _ = CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSetValue(
            Self.launchServicesHandlersKey as CFString,
            handlers,
            Self.launchServicesApplicationID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        _ = CFPreferencesSynchronize(
            Self.launchServicesApplicationID as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }

    enum PreferenceError: LocalizedError {
        case couldNotSaveFileViewerPreference
        case couldNotSaveLaunchServicesPreference

        var errorDescription: String? {
            switch self {
            case .couldNotSaveFileViewerPreference:
                "macOS did not save the preferred file viewer."
            case .couldNotSaveLaunchServicesPreference:
                "macOS did not save the folder association."
            }
        }
    }
}
