import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var folderAssociation = FolderAssociationService()
    @State private var isRelaunching = false
    @State private var privacyMessage: String?

    var body: some View {
        Form {
            Section("File Listings") {
                Toggle("Calculate folder sizes automatically", isOn: $state.automaticallyCalculateFolderSizes)
                    .controlTooltip("Calculate folder sizes automatically when a tab opens")
                Text("Off by default. When enabled, folder sizes are calculated in the background for each opened tab. Results are cached briefly for faster revisits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Folder Handling") {
                LabeledContent("Current folder viewer") {
                    Text(folderAssociation.currentHandlerName)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Use Chad Commander") {
                        folderAssociation.makeChadCommanderDefault()
                    }
                    .disabled(folderAssociation.isChadCommanderDefault || folderAssociation.isWorking)
                    .controlTooltip("Use Chad Commander when macOS opens folders")

                    Button("Restore Finder") {
                        folderAssociation.restoreFinder()
                    }
                    .disabled(folderAssociation.isFinderDefault || folderAssociation.isWorking)
                    .controlTooltip("Restore Finder as the default folder viewer")

                    if folderAssociation.isWorking {
                        ProgressView().controlSize(.small)
                    }
                }

                Text("This affects apps that ask macOS to open or reveal a folder. Finder still owns the Desktop, Trash, and system Open/Save dialogs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let note = folderAssociation.installationNote {
                    Label(note, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let message = folderAssociation.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Privacy Access") {
                Text("Full Disk Access lets Chad Commander browse protected locations—including Desktop, Documents, Downloads, iCloud Drive, external disks, and other users’ readable files—without asking for each location separately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("macOS requires one manual approval: open System Settings, add or enable Chad Commander under Full Disk Access, then return here and relaunch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Open Full Disk Access Settings") {
                        if !PrivacyAccessService.openFullDiskAccessSettings() {
                            privacyMessage = "Could not open Full Disk Access settings. Open System Settings → Privacy & Security → Full Disk Access."
                        }
                    }
                    .controlTooltip("Open macOS Full Disk Access settings")

                    Button("Relaunch Chad Commander") {
                        relaunch()
                    }
                    .disabled(isRelaunching)
                    .controlTooltip("Quit and reopen Chad Commander")

                    if isRelaunching {
                        ProgressView().controlSize(.small)
                    }
                }

                if let privacyMessage {
                    Text(privacyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 440)
        .task { folderAssociation.refresh() }
    }

    private func relaunch() {
        isRelaunching = true
        privacyMessage = nil
        Task { @MainActor in
            do {
                try await PrivacyAccessService.relaunch()
            } catch {
                privacyMessage = error.localizedDescription
                isRelaunching = false
            }
        }
    }
}
