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

/// A tab lifted out of one pane, on its way into the other.
struct DetachedPaneTab: Sendable {
    let tab: PaneTab
    let calculatesFolderSizes: Bool
}

/// Identifies the tab a drag started from. Encoded as plain text so the drag
/// travels through an `NSItemProvider`, and decoded again on drop so a stray
/// text drag from another app can never be mistaken for one of our tabs.
struct TabDragPayload: Equatable, Sendable {
    private static let marker = "chad-commander.tab"

    let side: PaneSide
    let tabID: UUID

    init(side: PaneSide, tabID: UUID) {
        self.side = side
        self.tabID = tabID
    }

    init?(encoded: String) {
        let fields = encoded.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == 3,
              fields[0] == Self.marker,
              let side = PaneSide(rawValue: String(fields[1])),
              let tabID = UUID(uuidString: String(fields[2]))
        else { return nil }
        self.side = side
        self.tabID = tabID
    }

    var encoded: String {
        "\(Self.marker):\(side.rawValue):\(tabID.uuidString)"
    }
}

/// Where a dragged tab would land in a tab strip.
struct TabDropTarget: Equatable, Sendable {
    let side: PaneSide
    let index: Int
}

enum TabStripLayout {
    /// The slot a drop at `x` belongs in, given each tab's horizontal midpoint.
    /// Never returns 0: the anchor tab keeps the first slot.
    static func insertionIndex(forX x: CGFloat, tabMidpoints: [CGFloat]) -> Int {
        let passed = tabMidpoints.reduce(into: 0) { count, midpoint in
            if x > midpoint { count += 1 }
        }
        return min(max(passed, 1), max(tabMidpoints.count, 1))
    }
}
