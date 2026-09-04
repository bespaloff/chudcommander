import SwiftUI

@main
struct ChadCommanderApp: App {
    @NSApplicationDelegateAdaptor(ChadCommanderApplicationDelegate.self) private var applicationDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Chad Commander") {
            ContentView()
                .environmentObject(state)
        }
        .defaultSize(width: 1100, height: 650)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    applicationDelegate.checkForUpdates(nil)
                }
                .controlTooltip("Check for Chad Commander updates")
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts…") {
                    state.showShortcutGuide()
                }
                .keyboardShortcut("/", modifiers: .command)
                .controlTooltip("Show the keyboard shortcut guide", shortcut: "⌘/")
            }
            CommandGroup(replacing: .newItem) {
                Button("New Folder…") { state.requestNewFolder() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .controlTooltip("Create a folder in the active pane", shortcut: "F7 or ⌘⇧N")
                Button("New Tab") { state.activePane.addTab() }
                    .keyboardShortcut("t", modifiers: .command)
                    .controlTooltip("Open a new tab in the active pane", shortcut: "⌘T")
                Divider()
                Button("Close Tab") { state.activePane.closeTab(state.activePane.activeTabID) }
                    .keyboardShortcut("w", modifiers: .command)
                    .controlTooltip("Close the active tab", shortcut: "⌘W")
            }
            CommandMenu("Commander") {
                Button("Quick Look  F3") { state.quickLookSelection() }
                    .keyboardShortcut("y", modifiers: .command)
                    .controlTooltip("Preview the selected item", shortcut: "F3, Space, or ⌘Y")
                Button("Open  F4") { state.openSelection() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .controlTooltip("Open the selected item", shortcut: "F4 or ⌘Return")
                Divider()
                Button("Copy to Other Pane  F5") { state.copySelection() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .controlTooltip("Copy the selection to the other pane", shortcut: "F5 or ⌘⇧C")
                Button("Move to Other Pane  F6") { state.moveSelection() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                    .controlTooltip("Move the selection to the other pane", shortcut: "F6 or ⌘⇧M")
                Button("Rename…  ⇧F6") { state.requestRename() }
                    .keyboardShortcut("r", modifiers: .command)
                    .controlTooltip("Rename the selected item", shortcut: "⇧F6 or ⌘R")
                Button("Move to Trash  F8") { state.requestTrash() }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .controlTooltip("Move the selection to the Trash", shortcut: "F8 or ⌘Delete")
                Divider()
                Button("Find Files…") { state.searchPresented = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .controlTooltip("Find files in the active location", shortcut: "⌘F")
                Button("Toggle Terminal  ⌥F4") { state.toggleTerminal() }
                    .keyboardShortcut("`", modifiers: .control)
                    .controlTooltip("Show or hide the active pane's terminal", shortcut: "⌥F4 or ⌃`")
                Button("Switch Active Pane  Tab") { state.switchPane() }
                    .keyboardShortcut("u", modifiers: .command)
                    .controlTooltip("Switch the active pane", shortcut: "Tab or ⌘U")
                Divider()
                Button("Reload") { state.activePane.reload() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .controlTooltip("Reload the active folder", shortcut: "⌘⇧R")
                Button("Calculate Folder Sizes") { state.activePane.calculateFolderSizesForTab(forceRefresh: true) }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                    .disabled(state.activePane.isLoading || state.activePane.isCalculatingFolderSizes)
                    .controlTooltip("Calculate folder sizes in the active tab", shortcut: "⌘⌥S")
                Button("Show Hidden Files") { state.activePane.showHidden.toggle(); state.activePane.reload() }
                    .controlTooltip("Show or hide hidden files", shortcut: "⌘⇧.")
            }
        }

        Settings {
            SettingsView()
                .environmentObject(state)
        }
    }
}
