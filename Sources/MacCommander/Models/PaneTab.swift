import Foundation

struct PaneTab: Identifiable, Sendable {
    let id: UUID
    var location: URL
    var titleOverride: String?
    var history: [URL]
    var historyIndex: Int
    var virtualItems: [FileItem]?

    init(location: URL, titleOverride: String? = nil, virtualItems: [FileItem]? = nil) {
        self.id = UUID()
        self.location = location.standardizedFileURL
        self.titleOverride = titleOverride
        self.history = [location.standardizedFileURL]
        self.historyIndex = 0
        self.virtualItems = virtualItems
    }

    var title: String {
        if let titleOverride { return titleOverride }
        if location.path == "/" { return "Macintosh HD" }
        return location.lastPathComponent.isEmpty ? location.path : location.lastPathComponent
    }
}
enum PaneSide: String, CaseIterable, Sendable {
    case left
    case right

    var opposite: PaneSide { self == .left ? .right : .left }
}
