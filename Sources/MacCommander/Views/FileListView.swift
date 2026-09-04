import AppKit
import SwiftUI

struct FileListView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.interfaceScale) private var scale
    @ObservedObject var model: PaneModel
    let side: PaneSide
    @FocusState private var listFocused: Bool
    @State private var resizingColumn: FileListColumn?
    @State private var resizeStartWidth: CGFloat = 0
    @State private var hoveredResizeColumn: FileListColumn?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: FileListMetrics.columnSpacing * scale) {
                sortButton(.name, width: nil)
                Spacer(minLength: 0)
                ForEach(visibleColumns) { column in
                    resizableSortButton(for: column)
                }
                columnsMenu
                    .frame(width: FileListMetrics.columnsMenuWidth * scale)
            }
            .font(.system(size: 10.5 * scale, weight: .semibold))
            .foregroundStyle(.secondary)
            // Line the header up with the row content: names start after the
            // row inset and icon, and the trailing edge leaves room for the
            // columns menu so every header sits above its own column.
            .padding(.leading, (FileListMetrics.rowInset + FileListMetrics.iconWidth + FileListMetrics.columnSpacing) * scale)
            .padding(.trailing, FileListMetrics.rowInset * scale)
            .frame(height: 20 * scale)
            .background(Color(nsColor: .controlBackgroundColor))

            ScrollViewReader { proxy in
                List(model.displayItems) { item in
                    itemRow(item)
                        .id(item.url)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: FileListMetrics.rowInset * scale,
                            bottom: 0,
                            trailing: (FileListMetrics.rowInset
                                + FileListMetrics.columnsMenuWidth
                                + FileListMetrics.columnSpacing) * scale
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(selectionBackground(for: item))
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 20 * scale)
                .focusable(true)
                .focused($listFocused)
                .onChange(of: model.cursorURL) { _, url in
                    guard let url else { return }
                    // With no anchor, SwiftUI leaves visible rows in place and
                    // only scrolls the minimum needed to reveal an off-screen row.
                    proxy.scrollTo(url)
                }
                .onAppear {
                    focusIfActive()
                    scrollToCursor(using: proxy)
                }
                .onChange(of: state.activeSide) { _, activeSide in
                    listFocused = activeSide == side
                }
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ item: FileItem) -> some View {
        let row = HStack(spacing: FileListMetrics.columnSpacing * scale) {
            FileIcon(url: item.url, size: FileListMetrics.iconWidth * scale)
            Text(item.name).lineLimit(1)
            Spacer(minLength: 3 * scale)
            ForEach(visibleColumns) { column in
                Text(value(for: column, item: item))
                    .foregroundStyle(detailColor(for: item))
                    .lineLimit(1)
                    .frame(width: width(for: column), alignment: alignment(for: column))
            }
        }
        .font(.system(size: 11.5 * scale))
        .foregroundStyle(primaryColor(for: item))
        .frame(height: 20 * scale)
        .contentShape(Rectangle())
        .contextMenu { contextMenu(for: item) }
        .controlTooltip(
            item.isParentEntry
                ? "Double-click to open the parent folder"
                : "Double-click to open \(item.name), or drag it to Finder or another app",
            shortcut: item.isParentEntry ? "Return or ⌫" : "Return"
        )

        if item.isParentEntry {
            row.onTapGesture {
                let event = NSApp.currentEvent
                select(item, extending: event?.modifierFlags.contains(.command) == true)
                if event?.clickCount == 2 { state.activate(item, in: side) }
            }
        } else {
            row.overlay {
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
    }

    @ViewBuilder
    private func sortButton(_ sort: FileSort, width: CGFloat?) -> some View {
        Button {
            if model.sort == sort { model.ascending.toggle() }
            else { model.sort = sort; model.ascending = true }
        } label: {
            HStack(spacing: 3 * scale) {
                Text(sort.rawValue).lineLimit(1)
                if model.sort == sort { Image(systemName: model.ascending ? "chevron.up" : "chevron.down").font(.system(size: 8 * scale)) }
            }
            .frame(width: width, alignment: headerAlignment(for: sort))
        }
        .buttonStyle(.plain)
        .controlTooltip("Sort by \(sort.rawValue)")
    }

    private func resizableSortButton(for column: FileListColumn) -> some View {
        sortButton(column.sort, width: width(for: column))
            .overlay(alignment: .leading) {
                columnResizeHandle(for: column)
            }
    }

    private func columnResizeHandle(for column: FileListColumn) -> some View {
        let isHighlighted = hoveredResizeColumn == column || resizingColumn == column

        // The grab strip stays inside the column it resizes: an overlay that
        // hangs over the neighbouring header is ambiguous to hit-test, so the
        // drag would land on the sort button instead of the handle.
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear)
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .padding(.vertical, 3 * scale)
                .opacity(isHighlighted ? 0.95 : 0.35)
        }
        .frame(width: 10 * scale, height: 20 * scale)
        .contentShape(Rectangle())
        .onHover { isHovering in
            hoveredResizeColumn = isHovering ? column : nil
            if isHovering {
                NSCursor.resizeLeftRight.set()
            } else if resizingColumn == nil {
                NSCursor.arrow.set()
            }
        }
        // Global coordinates: the handle moves with the column edge it
        // drags, and a local translation would cancel its own movement out.
        .highPriorityGesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    let initialWidth: CGFloat
                    if resizingColumn == column {
                        initialWidth = resizeStartWidth
                    } else {
                        initialWidth = CGFloat(model.listColumnWidth(for: column))
                        resizeStartWidth = initialWidth
                        resizingColumn = column
                    }
                    NSCursor.resizeLeftRight.set()
                    // Widths are stored unscaled, so the drag is measured in
                    // the same units the zoom multiplies.
                    model.setListColumnWidth(
                        column,
                        to: Double(initialWidth - value.translation.width / scale)
                    )
                }
                .onEnded { _ in
                    resizingColumn = nil
                    if hoveredResizeColumn == column {
                        NSCursor.resizeLeftRight.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        )
        .onTapGesture(count: 2) {
            model.resetListColumnWidth(column)
        }
        .accessibilityElement()
        .accessibilityLabel("Resize \(column.rawValue) column")
        .accessibilityValue("\(Int(model.listColumnWidth(for: column))) points")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                model.setListColumnWidth(column, to: model.listColumnWidth(for: column) + 12)
            case .decrement:
                model.setListColumnWidth(column, to: model.listColumnWidth(for: column) - 12)
            @unknown default:
                break
            }
        }
        .controlTooltip("Drag to resize the \(column.rawValue) column; double-click to reset it")
    }

    private var visibleColumns: [FileListColumn] {
        FileListColumn.allCases.filter(model.visibleListColumns.contains)
    }

    private func value(for column: FileListColumn, item: FileItem) -> String {
        switch column {
        case .sharedBy: item.sharedBy
        case .modified: item.formattedModifiedDate
        case .created: item.formattedCreatedDate
        case .lastOpened: item.formattedLastOpenedDate
        case .size: model.folderSizeText(for: item)
        case .version: item.version
        case .kind: item.kind
        case .comments: item.comments
        case .tags: item.formattedTags
        case .added: item.formattedAddedDate
        case .iCloudStatus: item.iCloudStatus
        }
    }

    private func width(for column: FileListColumn) -> CGFloat {
        CGFloat(model.listColumnWidth(for: column)) * scale
    }

    private func alignment(for column: FileListColumn) -> Alignment {
        switch column {
        case .size, .modified, .created, .lastOpened, .added: .trailing
        default: .leading
        }
    }

    private func headerAlignment(for sort: FileSort) -> Alignment {
        switch sort {
        case .size, .modified, .created, .lastOpened, .added: .trailing
        default: .leading
        }
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(FileListColumn.allCases) { column in
                Toggle(column.rawValue, isOn: Binding(
                    get: { model.visibleListColumns.contains(column) },
                    set: { model.setListColumn(column, isVisible: $0) }
                ))
                .tint(.blue)
                .controlTooltip("Show or hide the \(column.rawValue) column")
            }
        } label: {
            Image(systemName: "rectangle.3.group")
                .accessibilityLabel("Columns")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .controlTooltip("Choose visible columns")
    }

    @ViewBuilder
    private func contextMenu(for item: FileItem) -> some View {
        if item.isParentEntry {
            Button("Open Parent Folder") { state.activate(item, in: side) }
                .controlTooltip("Open the parent folder", shortcut: "Return or ⌫")
        } else {
            Button("Open") { state.activate(item, in: side) }
                .controlTooltip("Open \(item.name)", shortcut: "F4 or Return")
            Button("Quick Look") { state.setActive(side); state.quickLookURL = item.url }
                .controlTooltip("Preview \(item.name)", shortcut: "F3 or Space")
            Divider()
            Button("Copy to Other Pane") { select(item); state.copySelection() }
                .controlTooltip("Copy \(item.name) to the other pane", shortcut: "F5")
            Button("Move to Other Pane") { select(item); state.moveSelection() }
                .controlTooltip("Move \(item.name) to the other pane", shortcut: "F6")
            Button("Rename...") { select(item); state.requestRename() }
                .controlTooltip("Rename \(item.name)", shortcut: "⇧F6")
            Divider()
            Button("Move to Trash", role: .destructive) { select(item); state.requestTrash() }
                .controlTooltip("Move \(item.name) to the Trash", shortcut: "F8")
        }
    }

    private func select(_ item: FileItem) {
        select(item, extending: false)
    }

    private func select(_ item: FileItem, extending: Bool) {
        state.setActive(side)
        model.setCursor(to: item.url)
        if extending {
            if model.selection.contains(item.url) { model.selection.remove(item.url) }
            else { model.selection.insert(item.url) }
        } else {
            model.selection = [item.url]
        }
        listFocused = true
    }

    private func focusIfActive() {
        guard state.activeSide == side else { return }
        DispatchQueue.main.async { listFocused = true }
    }

    private func scrollToCursor(using proxy: ScrollViewProxy) {
        guard let url = model.cursorURL else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(url, anchor: .center)
        }
    }

    private func selectionBackground(for item: FileItem) -> Color {
        guard model.selection.contains(item.url) else { return .clear }
        return state.activeSide == side
            ? Color.accentColor
            : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    private func primaryColor(for item: FileItem) -> Color {
        model.selection.contains(item.url) && state.activeSide == side ? .white : .primary
    }

    private func detailColor(for item: FileItem) -> Color {
        model.selection.contains(item.url) && state.activeSide == side ? .white.opacity(0.82) : .secondary
    }
}
