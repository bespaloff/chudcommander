import SwiftUI

struct FileGridView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: PaneModel
    let side: PaneSide
    @FocusState private var gridFocused: Bool

    private let cellSpacing: CGFloat = 10

    private var iconSize: CGFloat { CGFloat(model.gridIconSize) }
    private var minimumCellWidth: CGFloat { max(70, iconSize + 38) }
    private var maximumCellWidth: CGFloat { minimumCellWidth + 38 }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(minimum: minimumCellWidth, maximum: maximumCellWidth),
                                spacing: cellSpacing
                            )
                        ],
                        spacing: 10
                    ) {
                        ForEach(model.displayItems) { item in
                            gridItem(item)
                                .id(item.url)
                        }
                    }
                    .padding(10)
                }
                .focusable(true)
                .focused($gridFocused)
                .onAppear {
                    updateColumnCount(for: geometry.size.width)
                    scrollToCursor(using: proxy)
                    guard state.activeSide == side else { return }
                    DispatchQueue.main.async { gridFocused = true }
                }
                .onChange(of: geometry.size.width) { _, width in
                    updateColumnCount(for: width)
                }
                .onChange(of: model.gridIconSize) { _, _ in
                    updateColumnCount(for: geometry.size.width)
                }
                .onChange(of: model.cursorURL) { _, url in
                    guard let url else { return }
                    // Avoid recentering cells that are already visible.
                    proxy.scrollTo(url)
                }
                .onChange(of: state.activeSide) { _, activeSide in
                    gridFocused = activeSide == side
                }
            }
        }
    }

    private func gridItem(_ item: FileItem) -> some View {
        VStack(spacing: 5) {
            FileIcon(
                url: item.url,
                size: iconSize,
                showsThumbnail: !item.isDirectory && !item.isParentEntry
            )
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: iconSize + 36)
        .padding(6)
        .foregroundStyle(
            model.selection.contains(item.url) && state.activeSide == side
                ? Color.white
                : Color.primary
        )
        .background(
            model.selection.contains(item.url)
                ? (state.activeSide == side
                    ? Color.accentColor
                    : Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
        .controlTooltip(
            item.isParentEntry
                ? "Double-click to open the parent folder"
                : "Double-click to open \(item.name), or drag it to Finder or another app",
            shortcut: item.isParentEntry ? "Return or ⌫" : "Return"
        )
        .overlay {
            if !item.isParentEntry {
                FileDragSource(
                    itemURL: item.url,
                    tooltip: "Double-click to open \(item.name), or drag it to Finder or another app",
                    selectedURLs: { model.selectedItems.map(\.url) },
                    onSelect: { extending, clickCount in
                        select(item, extending: extending)
                        if clickCount == 2 { state.activate(item, in: side) }
                    },
                    onDragEnded: { operation in
                        if operation.contains(.move) { model.reload() }
                    }
                )
            }
        }
        .onTapGesture {
            guard item.isParentEntry else { return }
            let event = NSApp.currentEvent
            select(item, extending: event?.modifierFlags.contains(.command) == true)
            if event?.clickCount == 2 { state.activate(item, in: side) }
        }
    }

    private func updateColumnCount(for width: CGFloat) {
        let availableWidth = max(0, width - 20)
        let count = Int((availableWidth + cellSpacing) / (minimumCellWidth + cellSpacing))
        model.updateGridColumnCount(count)
    }

    private func scrollToCursor(using proxy: ScrollViewProxy) {
        guard let url = model.cursorURL else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(url, anchor: .center)
        }
    }

    private func select(_ item: FileItem, extending: Bool) {
        state.setActive(side)
        model.setCursor(to: item.url)
        gridFocused = true
        if extending {
            if model.selection.contains(item.url) { model.selection.remove(item.url) }
            else { model.selection.insert(item.url) }
        } else {
            model.selection = [item.url]
        }
    }
}
