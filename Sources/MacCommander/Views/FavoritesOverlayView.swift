import SwiftUI

struct FavoritesOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: AppState
    @State private var query = ""
    @State private var selection: FavoriteFolder.ID?
    @FocusState private var searchFocused: Bool

    private var filteredFavorites: [FavoriteFolder] {
        state.favoriteFolders.filter { $0.matches(query) }
    }

    private var selectedFavorite: FavoriteFolder? {
        filteredFavorites.first { $0.id == selection }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filterBar
            Divider()
            favoritesList
            Divider()
            footer
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 430, idealHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selection = filteredFavorites.first?.id
            searchFocused = true
        }
        .onChange(of: filteredFavorites.map(\.id)) { _, visibleIDs in
            if let selection, visibleIDs.contains(selection) { return }
            selection = visibleIDs.first
        }
        .onExitCommand { dismiss() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.square.on.square.fill")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Favorite Folders")
                    .font(.headline)
                Text("Open a favorite in the latest active tab")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close favorite folders")
            .controlTooltip("Close favorite folders", shortcut: "Esc")
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Filter by folder name or full path", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .controlTooltip("Filter favorites by folder name or full path")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear the favorites filter")
                .controlTooltip("Clear the favorites filter")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var favoritesList: some View {
        if filteredFavorites.isEmpty {
            ContentUnavailableView {
                Label(
                    state.favoriteFolders.isEmpty ? "No Favorite Folders" : "No Matching Favorites",
                    systemImage: state.favoriteFolders.isEmpty ? "star" : "line.3.horizontal.decrease.circle"
                )
            } description: {
                Text(
                    state.favoriteFolders.isEmpty
                        ? "Use ⌘B in a tab to add its folder."
                        : "Try part of a folder name or any part of its path."
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selection) {
                ForEach(filteredFavorites) { favorite in
                    favoriteRow(favorite)
                        .tag(favorite.id)
                }
            }
            .listStyle(.inset)
            .onKeyPress(.return) {
                openSelection()
                return .handled
            }
        }
    }

    private func favoriteRow(_ favorite: FavoriteFolder) -> some View {
        HStack(spacing: 11) {
            FileIcon(url: favorite.url, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(favorite.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(favorite.path)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button {
                state.removeFavorite(favorite)
            } label: {
                Image(systemName: "star.slash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(favorite.name) from favorites")
            .controlTooltip("Remove \(favorite.name) from favorites")
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { selection = favorite.id }
        .onTapGesture(count: 2) { open(favorite) }
        .controlTooltip("Open \(favorite.path)", shortcut: "Return")
        .contextMenu {
            Button("Open") { open(favorite) }
                .controlTooltip("Open \(favorite.path)", shortcut: "Return")
            Button("Remove from Favorites") { state.removeFavorite(favorite) }
                .controlTooltip("Remove \(favorite.name) from favorites")
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("\(filteredFavorites.count) favorite\(filteredFavorites.count == 1 ? "" : "s")  •  ↑↓ select  •  Return open")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Remove") {
                removeSelection()
            }
            .disabled(selectedFavorite == nil)
            .controlTooltip("Remove the selected folder from favorites")

            Button("Open") {
                openSelection()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(selectedFavorite == nil)
            .controlTooltip("Open the selected favorite in the active tab", shortcut: "Return")
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }

    private func moveSelection(by offset: Int) {
        let favorites = filteredFavorites
        guard !favorites.isEmpty else {
            selection = nil
            return
        }
        let current = selection.flatMap { id in favorites.firstIndex(where: { $0.id == id }) } ?? 0
        let next = min(max(current + offset, 0), favorites.count - 1)
        selection = favorites[next].id
    }

    private func removeSelection() {
        guard let favorite = selectedFavorite else { return }
        state.removeFavorite(favorite)
    }

    private func openSelection() {
        guard let favorite = selectedFavorite else { return }
        open(favorite)
    }

    private func open(_ favorite: FavoriteFolder) {
        state.openFavorite(favorite)
        dismiss()
    }
}
