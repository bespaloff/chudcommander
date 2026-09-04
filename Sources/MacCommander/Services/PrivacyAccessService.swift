import AppKit
import Foundation

@MainActor
enum PrivacyAccessService {
    static let fullDiskAccessSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )!

    static var canRelaunch: Bool {
        Bundle.main.bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
    }

    @discardableResult
    static func openFullDiskAccessSettings() -> Bool {
        NSWorkspace.shared.open(fullDiskAccessSettingsURL)
    }

    static func relaunch() async throws {
        guard canRelaunch else {
            throw RelaunchError.notPackagedApplication
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        _ = try await NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        )
        NSApp.terminate(nil)
    }

    enum RelaunchError: LocalizedError {
        case notPackagedApplication

        var errorDescription: String? {
            "Relaunch is available from the packaged Chad Commander app."
        }
    }
}
