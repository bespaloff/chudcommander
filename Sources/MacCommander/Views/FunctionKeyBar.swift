import SwiftUI

struct FunctionKeyBar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 1) {
            action("F3", "View") { state.quickLookSelection() }
            action("F4", "Open") { state.openSelection() }
            action("F5", "Copy") { state.copySelection() }
            action("F6", "Move") { state.moveSelection() }
            action("⇧F6", "Rename") { state.requestRename() }
            action("F7", "New folder") { state.requestNewFolder() }
            action("F8", "Trash") { state.requestTrash() }
            action("⌥F4", "Terminal") { state.toggleTerminal() }
        }
        .padding(2)
        .background(.bar)
    }

    private func action(_ key: String, _ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 3) {
                Text(key)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tint)
                Text(title).font(.system(size: 10.5)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 21)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .controlTooltip(title, shortcut: key)
    }
}
