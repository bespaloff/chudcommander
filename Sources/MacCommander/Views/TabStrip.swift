import SwiftUI

struct TabStrip: View {
    @ObservedObject var model: PaneModel
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2 * scale) {
                ForEach(model.tabs) { tab in
                    HStack(spacing: 5 * scale) {
                        Image(systemName: tab.virtualItems == nil ? "folder" : "magnifyingglass")
                            .font(.system(size: 10 * scale))
                        Text(tab.title).font(.system(size: 10.5 * scale, weight: .medium)).lineLimit(1)
                        if model.tabs.count > 1 {
                            Button { model.closeTab(tab.id) } label: {
                                Image(systemName: "xmark").font(.system(size: 8 * scale, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .controlTooltip(
                                "Close \(tab.title)",
                                shortcut: tab.id == model.activeTabID ? "⌘W" : nil
                            )
                        }
                    }
                    .padding(.horizontal, 6 * scale)
                    .frame(height: 21 * scale)
                    .background(tab.id == model.activeTabID ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 4 * scale))
                    .contentShape(Rectangle())
                    .onTapGesture { model.selectTab(tab.id) }
                    .controlTooltip("Switch to \(tab.title)")
                    .contextMenu {
                        Button("Close Tab") { model.closeTab(tab.id) }
                            .disabled(model.tabs.count == 1)
                            .controlTooltip("Close \(tab.title)")
                    }
                }
                Button { model.addTab() } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain)
                    .frame(width: 20 * scale, height: 20 * scale)
                    .controlTooltip("Open a new tab", shortcut: "⌘T")
            }
            .padding(.horizontal, 4 * scale)
            .padding(.vertical, 2 * scale)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
