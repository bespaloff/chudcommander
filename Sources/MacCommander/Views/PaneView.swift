import SwiftUI

struct PaneView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var model: PaneModel
    let side: PaneSide

    var body: some View {
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
                            Text("macOS blocked access to this folder. Grant Full Disk Access once to browse protected locations without separate prompts.")
                        } actions: {
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
                Divider()
                TerminalView(session: model.terminal) { model.toggleTerminal() }
                    .frame(height: 165)
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
        .background(state.activeSide == side ? Color.accentColor.opacity(0.035) : Color.clear)
        .overlay {
            if state.activeSide == side { RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor.opacity(0.65), lineWidth: 1) }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { state.setActive(side) })
    }
}
