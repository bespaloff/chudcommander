import Foundation

struct FavoriteFolder: Codable, Hashable, Identifiable, Sendable {
    let path: String

    init(url: URL) {
        path = url.standardizedFileURL.path
    }

    var id: String { path }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    var name: String {
        if path == "/" { return "Macintosh HD" }
        return url.lastPathComponent.isEmpty ? path : url.lastPathComponent
    }

    func matches(_ query: String) -> Bool {
        let terms = query
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }
        guard !terms.isEmpty else { return true }

        return terms.allSatisfy { term in
            name.localizedCaseInsensitiveContains(term)
                || path.localizedCaseInsensitiveContains(term)
        }
    }
}

struct PaneSessionState: Codable, Equatable, Sendable {
    var folderPaths: [String]
    var activeTabIndex: Int

    init(folderPaths: [String], activeTabIndex: Int) {
        self.folderPaths = folderPaths
        self.activeTabIndex = activeTabIndex
    }

    var folderURLs: [URL] {
        folderPaths
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
    }
}

struct WorkspaceSessionState: Codable, Equatable, Sendable {
    var leftPane: PaneSessionState
    var rightPane: PaneSessionState
    var activeSide: PaneSide
}

extension PaneSide: Codable {}

enum FavoritesPresentation: String, Identifiable, Sendable {
    case browser

    var id: String { rawValue }
}
