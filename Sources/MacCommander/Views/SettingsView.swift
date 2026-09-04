import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var folderAssociation = FolderAssociationService()
    @State private var isRelaunching = false
    @State private var isRequestingFolderAccess = false
    @State private var privacyMessage: String?

    var body: some View {
        Form {
            Section("Appearance") {
                LabeledContent("Interface size") {
                    Text("\(state.interfaceScalePercentage)%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Smaller") { state.decreaseInterfaceScale() }
                        .disabled(!state.canDecreaseInterfaceScale)
                        .controlTooltip("Make the main interface smaller", shortcut: "⌘−")
                    Button("Actual Size") { state.resetInterfaceScale() }
                        .disabled(state.interfaceScale == 1)
                        .controlTooltip("Reset the main interface to its default size", shortcut: "⌘0")
                    Button("Larger") { state.increaseInterfaceScale() }
                        .disabled(!state.canIncreaseInterfaceScale)
                        .controlTooltip("Make the main interface larger", shortcut: "⌘+")
                }
            }

            Section("File Listings") {
                Toggle("Calculate folder sizes automatically", isOn: $state.automaticallyCalculateFolderSizes)
                    .tint(.blue)
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
                    .disabled(
                        folderAssociation.isChadCommanderDefault
                            || folderAssociation.isWorking
                            || !folderAssociation.canMakeChadCommanderDefault
                    )
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

                Text("Restart your Mac after changing this setting. It affects apps and Terminal commands that ask macOS to open or reveal a folder. Finder still owns the Desktop, Trash, and system Open/Save dialogs.")
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
                Text("macOS asks when Chad Commander first opens protected locations such as Desktop, Documents, Downloads, network volumes, or removable disks. You can also explicitly allow a folder here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Full Disk Access is optional. It avoids separate prompts across the Mac, but Apple requires you to add or enable the app manually in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Allow a Folder…") {
                        requestFolderAccess()
                    }
                    .disabled(isRequestingFolderAccess)
                    .controlTooltip("Choose a folder Chad Commander may access")

                    Button("Full Disk Access Settings") {
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

                    if isRelaunching || isRequestingFolderAccess {
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
        .frame(width: 560, height: 560)
        .task { folderAssociation.refresh() }
    }

    private func requestFolderAccess() {
        isRequestingFolderAccess = true
        privacyMessage = nil
        Task { @MainActor in
            if let folder = await PrivacyAccessService.requestFolderAccess(
                startingAt: FileManager.default.homeDirectoryForCurrentUser
            ) {
                state.activePane.navigate(to: folder)
                privacyMessage = "Access allowed for \(folder.path)."
            }
            isRequestingFolderAccess = false
        }
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
