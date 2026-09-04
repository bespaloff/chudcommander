import SwiftUI

struct LocationBar: View {
    @ObservedObject var model: PaneModel
    @State private var pathText = ""
    @FocusState private var pathIsFocused: Bool

    var body: some View {
        HStack(spacing: 3) {
            Button { model.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!model.canGoBack)
                .controlTooltip("Go back", shortcut: "⌘[")
            Button { model.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!model.canGoForward)
                .controlTooltip("Go forward", shortcut: "⌘]")
            Button { model.goUp() } label: { Image(systemName: "arrow.up") }
                .disabled(model.location.path == "/")
                .controlTooltip("Open the parent folder", shortcut: "⌫")

            Menu {
                Button("Home") { model.navigate(to: FileManager.default.homeDirectoryForCurrentUser) }
                    .controlTooltip("Open the Home folder")
                quickFolder("Desktop", .desktopDirectory)
                quickFolder("Documents", .documentDirectory)
                quickFolder("Downloads", .downloadsDirectory)
                Divider()
                ForEach(FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil) ?? [], id: \.self) { volume in
                    Button(volume.lastPathComponent.isEmpty ? volume.path : volume.lastPathComponent) { model.navigate(to: volume) }
                        .controlTooltip("Open \(volume.lastPathComponent.isEmpty ? volume.path : volume.lastPathComponent)")
                }
            } label: { Image(systemName: "externaldrive") }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .controlTooltip("Choose a favorite folder or mounted volume")

            TextField("Path", text: $pathText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .focused($pathIsFocused)
                .onSubmit { model.navigate(to: FileSystemService.expandedURL(from: pathText, relativeTo: model.location)) }
                .controlTooltip("Enter a folder path to open", shortcut: "Return")

            Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                .controlTooltip("Reload this folder", shortcut: "⌘⇧R")
            Button { model.calculateFolderSizesForTab(forceRefresh: true) } label: {
                if model.isCalculatingFolderSizes {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "ruler")
                }
            }
            .foregroundStyle(model.folderSizesEnabledForActiveTab ? Color.blue : Color.primary)
            .tint(.blue)
            .disabled(model.isLoading || model.isCalculatingFolderSizes)
            .controlTooltip("Calculate folder sizes for this tab", shortcut: "⌘⌥S")
            Button { model.showHidden.toggle(); model.reload() } label: {
                Image(systemName: model.showHidden ? "eye" : "eye.slash")
            }
            .foregroundStyle(model.showHidden ? Color.blue : Color.primary)
            .controlTooltip("\(model.showHidden ? "Hide" : "Show") hidden files", shortcut: "⌘⇧.")
            Picker("View", selection: $model.viewMode) {
                ForEach(PaneViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.symbol)
                        .tag(mode)
                        .controlTooltip(
                            mode == .list ? "Show files in a list" : "Show files as icons",
                            shortcut: mode == .list ? "⌘1" : "⌘2"
                        )
                }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 56)
            .tint(.blue)
            .controlTooltip("Switch between list and icon views", shortcut: "⌘1 for list; ⌘2 for icons")

            if model.viewMode == .grid {
                Menu {
                    ForEach(FileSort.allCases, id: \.self) { sort in
                        Button {
                            if model.sort == sort {
                                model.ascending.toggle()
                            } else {
                                model.sort = sort
                                model.ascending = true
                            }
                        } label: {
                            if model.sort == sort {
                                Label(sort.rawValue, systemImage: model.ascending ? "arrow.up" : "arrow.down")
                            } else {
                                Text(sort.rawValue)
                            }
                        }
                        .controlTooltip("Sort icons by \(sort.rawValue)")
                    }
                    Divider()
                    Button {
                        model.ascending.toggle()
                    } label: {
                        Label(
                            model.ascending ? "Use Descending Order" : "Use Ascending Order",
                            systemImage: model.ascending ? "arrow.down" : "arrow.up"
                        )
                    }
                    .controlTooltip(model.ascending ? "Sort icons in descending order" : "Sort icons in ascending order")
                } label: {
                    Image(systemName: model.ascending ? "arrow.up.arrow.down" : "arrow.down.arrow.up")
                        .accessibilityLabel("Sort Icons")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .controlTooltip("Choose how icons are sorted")

                HStack(spacing: 2) {
                    Image(systemName: "square.grid.3x3")
                    Slider(value: $model.gridIconSize, in: 32...96, step: 4)
                        .labelsHidden()
                        .frame(width: 58)
                        .controlTooltip("Change icon size")
                    Image(systemName: "square.grid.2x2")
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Icon Size")
                .accessibilityValue("\(Int(model.gridIconSize)) points")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.mini)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .onAppear { pathText = model.location.path }
        .onChange(of: model.location) { _, value in pathText = value.path }
    }

    @ViewBuilder
    private func quickFolder(_ title: String, _ directory: FileManager.SearchPathDirectory) -> some View {
        if let url = FileManager.default.urls(for: directory, in: .userDomainMask).first {
            Button(title) { model.navigate(to: url) }
                .controlTooltip("Open the \(title) folder")
        }
    }
}
