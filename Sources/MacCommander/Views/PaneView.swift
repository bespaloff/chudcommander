import AppKit
import SwiftUI

struct PaneView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: PaneModel
    let side: PaneSide
    @State private var isRequestingFolderAccess = false
    @State private var isResizingTerminal = false
    @State private var isHoveringTerminalHandle = false
    @State private var terminalResizeStartHeight = PaneModel.defaultTerminalHeight

    var body: some View {
        GeometryReader { proxy in
            paneContent(paneHeight: proxy.size.height)
        }
        .background(state.activeSide == side ? Color.accentColor.opacity(0.035) : Color.clear)
        .overlay {
            if state.activeSide == side { RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor.opacity(0.65), lineWidth: 1) }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { state.setActive(side) })
    }

    private func paneContent(paneHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            TabStrip(model: model)
            Divider()
            LocationBar(model: model)
            if !model.filterQuery.isEmpty {
                Divider()
                HStack(spacing: 5) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(.secondary)
                    TextField("Filter filenames", text: Binding(
                        get: { model.filterQuery },
                        set: { model.setFilterQuery($0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .onExitCommand { model.clearFilter() }
                    .controlTooltip("Filter filenames in this pane", shortcut: "Esc to clear")
                    Spacer(minLength: 0)
                    Text("\(model.filteredItems.count) match\(model.filteredItems.count == 1 ? "" : "es")")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                    Button { model.clearFilter() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .controlTooltip("Clear the filename filter", shortcut: "Esc")
                }
                .padding(.horizontal, 6)
                .frame(height: 22)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            Divider()

            ZStack {
                if model.viewMode == .list {
                    FileListView(model: model, side: side)
                } else {
                    FileGridView(model: model, side: side)
                }

                if model.isLoading {
                    ProgressView().controlSize(.small).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                } else if let error = model.errorMessage {
                    if model.accessDenied {
                        ContentUnavailableView {
                            Label("Permission Required", systemImage: "lock.shield")
                        } description: {
                            Text("macOS blocked access to this folder. Choose it to grant access, or use Full Disk Access for protected locations across the Mac.")
                        } actions: {
                            Button("Allow Access to This Folder…") {
                                requestFolderAccess()
                            }
                            .disabled(isRequestingFolderAccess)
                            .controlTooltip("Choose this folder to allow Chad Commander to access it")

                            Button("Open Full Disk Access Settings") {
                                PrivacyAccessService.openFullDiskAccessSettings()
                            }
                            .controlTooltip("Open macOS Full Disk Access settings")
                        }
                    } else {
                        ContentUnavailableView("Can’t Open Folder", systemImage: "folder.badge.questionmark", description: Text(error))
                    }
                } else if model.items.isEmpty {
                    ContentUnavailableView("Empty Folder", systemImage: "folder", description: Text(model.location.path))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dropDestination(for: URL.self) { urls, _ in state.acceptDropped(urls, on: side) }

            if model.terminalVisible {
                terminalResizeHandle(paneHeight: paneHeight)
                TerminalView(session: model.terminal) { model.toggleTerminal() }
                    .frame(height: CGFloat(model.terminalHeight(forPaneHeight: Double(paneHeight))))
            }

            Divider()
            HStack {
                let folderCount = model.items.lazy.filter(\.isDirectory).count
                Text("\(model.items.count - folderCount) files, \(folderCount) folders")
                Spacer()
                if !model.selectedItems.isEmpty {
                    Text("\(model.selectedItems.count) selected  |  \(ByteCountFormatter.string(fromByteCount: model.selectedSize, countStyle: .file))")
                }
            }
            .font(.system(size: 9.5)).foregroundStyle(.secondary)
            .padding(.horizontal, 5).frame(height: 17)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func terminalResizeHandle(paneHeight: CGFloat) -> some View {
        let maximum = PaneModel.maximumTerminalHeight(forPaneHeight: Double(paneHeight))
        let isHighlighted = isResizingTerminal || isHoveringTerminalHandle

        return ZStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
            Capsule()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 28, height: 3)
                .opacity(isHighlighted ? 0.95 : 0.45)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 7)
        .background(isHighlighted ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering in
            isHoveringTerminalHandle = isHovering
            if isHovering {
                NSCursor.resizeUpDown.set()
            } else if !isResizingTerminal {
                NSCursor.arrow.set()
            }
        }
        // Global coordinates: the handle slides with the terminal it is
        // resizing, so a translation measured in its own moving coordinate
        // space cancels the drag out instead of following the pointer.
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isResizingTerminal {
                        isResizingTerminal = true
                        terminalResizeStartHeight = model.terminalHeight(forPaneHeight: Double(paneHeight))
                    }
                    NSCursor.resizeUpDown.set()
                    model.setTerminalHeight(
                        terminalResizeStartHeight - Double(value.translation.height),
                        maximum: maximum
                    )
                }
                .onEnded { _ in
                    isResizingTerminal = false
                    if isHoveringTerminalHandle {
                        NSCursor.resizeUpDown.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        )
        .onTapGesture(count: 2) { model.resetTerminalHeight() }
        .accessibilityElement()
        .accessibilityLabel("Resize terminal")
        .accessibilityValue("\(Int(model.terminalHeight(forPaneHeight: Double(paneHeight)))) points")
        .accessibilityAdjustableAction { direction in
            let current = model.terminalHeight(forPaneHeight: Double(paneHeight))
            switch direction {
            case .increment:
                model.setTerminalHeight(current + 20, maximum: maximum)
            case .decrement:
                model.setTerminalHeight(current - 20, maximum: maximum)
            @unknown default:
                break
            }
        }
        .controlTooltip("Drag to resize the terminal; double-click to reset its height")
    }

    private func requestFolderAccess() {
        isRequestingFolderAccess = true
        Task { @MainActor in
            if let folder = await PrivacyAccessService.requestFolderAccess(startingAt: model.location) {
                model.navigate(to: folder)
            }
            isRequestingFolderAccess = false
        }
    }
}
