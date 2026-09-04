import SwiftUI
import UniformTypeIdentifiers

struct TabStrip: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: PaneModel
    let side: PaneSide
    @Environment(\.interfaceScale) private var scale
    @State private var tabMidpoints: [CGFloat] = []
    @State private var tabBoundaries: [CGFloat] = []
    @State private var dropIndex: Int?

    private let coordinateSpace = "tab-strip"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2 * scale) {
                ForEach(model.tabs) { tab in
                    tabButton(tab)
                }
                Button { model.addTab() } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain)
                    .frame(width: 20 * scale, height: 20 * scale)
                    .controlTooltip("Open a new tab", shortcut: "⌘T")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4 * scale)
            .padding(.vertical, 2 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .coordinateSpace(name: coordinateSpace)
            .contentShape(Rectangle())
            .onPreferenceChange(TabFramePreferenceKey.self) { frames in
                let ordered = frames.sorted { $0.minX < $1.minX }
                tabMidpoints = ordered.map { ($0.minX + $0.maxX) / 2 }
                tabBoundaries = ordered.map(\.minX) + [ordered.last?.maxX ?? 0]
            }
            .overlay(alignment: .leading) { insertionIndicator }
            .onDrop(
                of: [.chadCommanderTab],
                delegate: TabDropDelegate(
                    side: side,
                    insertionIndex: { TabStripLayout.insertionIndex(forX: $0, tabMidpoints: tabMidpoints) },
                    highlight: { dropIndex = $0 },
                    perform: { payload, index in state.moveTab(payload, to: side, at: index) }
                )
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var insertionIndicator: some View {
        if let dropIndex, dropIndex < tabBoundaries.count {
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 2 * scale, height: 19 * scale)
                .offset(x: tabBoundaries[dropIndex] - 1 * scale)
        }
    }

    private func tabButton(_ tab: PaneTab) -> some View {
        let isMovable = model.canMoveTab(tab.id)
        return tabLabel(tab)
            .padding(.horizontal, 6 * scale)
            .frame(height: 21 * scale)
            .background(tab.id == model.activeTabID ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 4 * scale))
            .background {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .named(coordinateSpace))
                    Color.clear.preference(
                        key: TabFramePreferenceKey.self,
                        value: [TabFrame(minX: frame.minX, maxX: frame.maxX)]
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.selectTab(tab.id) }
            .modifier(
                TabDragModifier(
                    payload: TabDragPayload(side: side, tabID: tab.id),
                    isMovable: isMovable,
                    preview: { tabLabel(tab).padding(.horizontal, 6 * scale).frame(height: 21 * scale) }
                )
            )
            .controlTooltip(
                isMovable
                    ? "Switch to \(tab.title) — drag it to reorder or move it to the other pane"
                    : "Switch to \(tab.title)"
            )
            .contextMenu {
                Button("Close Tab") { model.closeTab(tab.id) }
                    .disabled(model.tabs.count == 1)
                    .controlTooltip("Close \(tab.title)")
                Button("Move to Other Pane") {
                    state.moveTab(TabDragPayload(side: side, tabID: tab.id), to: side.opposite, at: .max)
                }
                .disabled(!isMovable)
                .controlTooltip("Move \(tab.title) to the other pane")
            }
    }

    private func tabLabel(_ tab: PaneTab) -> some View {
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
    }
}

/// Makes a tab draggable only when it is allowed to leave its slot, so the
/// anchor tab keeps its normal click-to-select behaviour.
private struct TabDragModifier<Preview: View>: ViewModifier {
    let payload: TabDragPayload
    let isMovable: Bool
    @ViewBuilder let preview: () -> Preview

    func body(content: Content) -> some View {
        if isMovable {
            content.onDrag {
                let provider = NSItemProvider()
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.chadCommanderTab.identifier,
                    visibility: .ownProcess
                ) { completion in
                    completion(Data(payload.encoded.utf8), nil)
                    return nil
                }
                return provider
            } preview: {
                preview()
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
            }
        } else {
            content
        }
    }
}

private struct TabDropDelegate: DropDelegate {
    let side: PaneSide
    let insertionIndex: (CGFloat) -> Int
    let highlight: (Int?) -> Void
    let perform: (TabDragPayload, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.chadCommanderTab])
    }

    func dropEntered(info: DropInfo) {
        highlight(insertionIndex(info.location.x))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        highlight(insertionIndex(info.location.x))
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        highlight(nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        highlight(nil)
        guard let provider = info.itemProviders(for: [.chadCommanderTab]).first else { return false }
        let index = insertionIndex(info.location.x)
        provider.loadDataRepresentation(forTypeIdentifier: UTType.chadCommanderTab.identifier) { data, _ in
            guard let data,
                  let payload = TabDragPayload(encoded: String(decoding: data, as: UTF8.self))
            else { return }
            Task { @MainActor in perform(payload, index) }
        }
        return true
    }
}

private struct TabFrame: Equatable {
    let minX: CGFloat
    let maxX: CGFloat
}

private struct TabFramePreferenceKey: PreferenceKey {
    static let defaultValue: [TabFrame] = []

    static func reduce(value: inout [TabFrame], nextValue: () -> [TabFrame]) {
        value.append(contentsOf: nextValue())
    }
}

extension UTType {
    /// A private type so only Chad Commander's own tab drags land in a tab
    /// strip — file drags from the panes pass straight over it.
    static let chadCommanderTab = UTType(exportedAs: "org.chadcommander.ChadCommander.tab")
}
