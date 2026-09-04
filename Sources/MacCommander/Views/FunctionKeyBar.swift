import AppKit
import SwiftUI

struct FunctionKeyBar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 1) {
            favoriteAction
            action("F3", "View") { state.quickLookSelection() }
            action("F4", "Open") { state.openSelection() }
            action("F5", "Copy") { state.copySelection() }
            action("F6", "Move") { state.moveSelection() }
            action("⇧F6", "Rename") { state.requestRename() }
            action("F7", "New folder") { state.requestNewFolder() }
            action("F8", "Trash") { state.requestTrash() }
            action("⌥F4", "Terminal", isActive: state.activePane.terminalVisible) { state.toggleTerminal() }
        }
        .padding(2)
        .background(.bar)
    }

    private var favoriteAction: some View {
        Button {
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                state.showFavorites()
            } else {
                state.toggleFavoriteForActiveFolder()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: state.isActiveFolderFavorite ? "star.fill" : "star")
                    .foregroundStyle(state.isActiveFolderFavorite ? Color.blue : Color.primary)
                Text("⌘B")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tint)
                Text(state.isActiveFolderFavorite ? "Unfavourite" : "Favorite")
                    .font(.system(size: 10.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 21)
            .background(
                state.isActiveFolderFavorite
                    ? Color.blue.opacity(0.16)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.7),
                in: RoundedRectangle(cornerRadius: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3).stroke(
                    state.isActiveFolderFavorite ? Color.blue.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.65),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
        .controlTooltip(
            state.isActiveFolderFavorite
                ? "Remove the active folder from favorites; Shift-click to browse favorites"
                : "Add the active folder to favorites; Shift-click to browse favorites",
            shortcut: "⌘B; ⇧⌘B opens favorites"
        )
    }

    private func action(
        _ key: String,
        _ title: String,
        isActive: Bool = false,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            HStack(spacing: 3) {
                Text(key)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(isActive ? Color.blue : Color.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 21)
            .background(
                isActive ? Color.blue.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.7),
                in: RoundedRectangle(cornerRadius: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3).stroke(
                    isActive ? Color.blue.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.65),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
        .controlTooltip(title, shortcut: key)
    }
}
