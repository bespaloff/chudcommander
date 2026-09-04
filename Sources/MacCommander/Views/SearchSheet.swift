import SwiftUI

struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: AppState
    @State private var options = SearchOptions()
    @State private var results: [SearchMatch] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var root: URL { state.activePane.location }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            criteria
            Divider()
            resultsArea
            Divider()
            footer
        }
        .controlSize(.small)
        .frame(minWidth: 620, idealWidth: 680, minHeight: 460, idealHeight: 510)
        .onDisappear { searchTask?.cancel() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Find files").font(.system(size: 14, weight: .semibold))
                Text(root.path).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if isSearching { ProgressView().controlSize(.small) }
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .controlTooltip("Close search", shortcut: "Esc")
        }
        .padding(.horizontal, 11)
        .frame(height: 39)
    }

    private var criteria: some View {
        VStack(spacing: 7) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                searchField("Name", placeholder: "Filename or pattern", text: $options.nameQuery)
                searchField("Content", placeholder: "Text inside files", text: $options.contentQuery)
                searchField("Exclude", placeholder: "Patterns separated by commas, such as *.tmp, build*", text: $options.excludedNames)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    optionLabel("Scope")
                    Picker("Scope", selection: $options.recursive) {
                        Text("This folder")
                            .tag(false)
                            .controlTooltip("Search only the current folder")
                        Text("Include subfolders")
                            .tag(true)
                            .controlTooltip("Search the current folder and its subfolders")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 230)
                    .controlTooltip("Choose whether to search only this folder or include subfolders")
                    Spacer()
                }
                GridRow {
                    optionLabel("Include")
                    HStack(spacing: 14) {
                        Toggle("Files", isOn: $options.searchFiles)
                            .controlTooltip("Include files in search results")
                        Toggle("Folders", isOn: $options.searchFolders)
                            .controlTooltip("Include folders in search results")
                        Toggle("Hidden items", isOn: $options.includeHidden)
                            .controlTooltip("Include hidden files and folders")
                    }
                    .toggleStyle(.checkbox)
                    .tint(.blue)
                    Spacer()
                }
                GridRow {
                    optionLabel("Matching")
                    HStack(spacing: 14) {
                        Toggle("Case sensitive", isOn: $options.caseSensitive)
                            .controlTooltip("Match uppercase and lowercase letters exactly")
                        Toggle("Regular expression", isOn: $options.useRegularExpression)
                            .controlTooltip("Interpret the name and content fields as regular expressions")
                    }
                    .toggleStyle(.checkbox)
                    .tint(.blue)
                    Spacer()
                }
            }

            HStack {
                Spacer()
                Text("Content search reads text files up to 64 MB")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    @ViewBuilder
    private func searchField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        GridRow {
            optionLabel(title)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { runSearch() }
                .gridCellColumns(2)
                .controlTooltip("Enter the \(title.lowercased()) search criteria", shortcut: "Return to search")
        }
    }

    private func optionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 58, alignment: .trailing)
    }

    @ViewBuilder
    private var resultsArea: some View {
        if let errorMessage {
            compactState(symbol: "exclamationmark.magnifyingglass", title: "Search error", detail: errorMessage)
        } else if results.isEmpty && !isSearching {
            compactState(symbol: "magnifyingglass", title: "Ready to search", detail: "Use a filename, file contents, or both.")
        } else {
            List(results) { result in
                HStack(spacing: 6) {
                    FileIcon(url: result.item.url, size: 15)
                    Text(result.item.name).font(.system(size: 11.5)).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(result.item.url.deletingLastPathComponent().path)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if result.matchedContent {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .help("Matched file contents")
                    }
                }
                .frame(height: 21)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    state.activePane.navigate(to: result.item.url.deletingLastPathComponent(), selecting: result.item.url)
                    dismiss()
                }
                .controlTooltip("Double-click to show \(result.item.name) in the active pane")
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 21)
        }
    }

    private func compactState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 12, weight: .medium))
            Text(detail).font(.system(size: 10.5)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(isSearching ? "Searching..." : "\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { searchTask?.cancel() }
                .disabled(!isSearching)
                .controlTooltip("Cancel the current search")
            Button("Show in pane") {
                state.activePane.showSearchResults(
                    results,
                    query: options.nameQuery.isEmpty ? options.contentQuery : options.nameQuery,
                    root: root
                )
                dismiss()
            }
            .disabled(results.isEmpty || isSearching)
            .controlTooltip("Open these results in the active pane")
            Button("Search") { runSearch() }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(isSearching || (!options.searchFiles && !options.searchFolders))
                .controlTooltip("Start search", shortcut: "⌘Return")
        }
        .padding(.horizontal, 11)
        .frame(height: 40)
    }

    private func runSearch() {
        searchTask?.cancel()
        results = []
        errorMessage = nil
        isSearching = true
        let capturedRoot = root
        let capturedOptions = options
        searchTask = Task {
            do {
                let found = try await SearchEngine.search(root: capturedRoot, options: capturedOptions)
                try Task.checkCancellation()
                results = found
            } catch is CancellationError {
                // Cancellation intentionally keeps the search dialog open.
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
}
