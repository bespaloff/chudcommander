import Foundation
import Testing
@testable import MacCommander

@Suite("Pane keyboard cursor")
@MainActor
struct PaneCursorTests {
    @Test("Parent entry and navigation keys move the selection cursor")
    func cursorMovement() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for index in 0..<30 {
            try Data().write(to: root.appendingPathComponent(String(format: "file-%02d.txt", index)))
        }
        let items = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(FileItem.standardKeys)
        ).compactMap { FileItem.load(url: $0) }

        let pane = PaneModel(location: root)
        pane.showSearchResults(items.map { SearchMatch(item: $0, matchedContent: false) }, query: "test", root: root)

        #expect(pane.itemAtCursor()?.isParentEntry == true)
        #expect(pane.selection == [root.deletingLastPathComponent().standardizedFileURL])

        pane.moveCursor(.next)
        #expect(pane.itemAtCursor()?.name == "file-00.txt")
        pane.moveCursor(.pageDown)
        #expect(pane.itemAtCursor()?.name == "file-18.txt")
        pane.moveCursor(.pageUp)
        #expect(pane.itemAtCursor()?.name == "file-00.txt")
        pane.moveCursor(.pageUp)
        #expect(pane.itemAtCursor()?.isParentEntry == true)
        pane.moveCursor(.pageDown)
        pane.moveCursor(.last)
        #expect(pane.itemAtCursor()?.name == "file-29.txt")
        pane.moveCursor(.first)
        #expect(pane.itemAtCursor()?.isParentEntry == true)

        pane.moveCursor(.right)
        #expect(pane.itemAtCursor()?.name == "file-00.txt")
        pane.moveCursor(.left)
        #expect(pane.itemAtCursor()?.isParentEntry == true)

        pane.viewMode = .grid
        pane.updateGridColumnCount(4)
        pane.moveCursor(.down)
        #expect(pane.itemAtCursor()?.name == "file-03.txt")
        pane.moveCursor(.up)
        #expect(pane.itemAtCursor()?.isParentEntry == true)
    }

    @Test("Filename filtering is case-insensitive and includes extensions")
    func filenameFiltering() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        for name in ["Alpha.TXT", "beta.png", "Meeting Notes.md"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        let items = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(FileItem.standardKeys)
        ).compactMap { FileItem.load(url: $0) }

        let pane = PaneModel(location: root)
        pane.showSearchResults(items.map { SearchMatch(item: $0, matchedContent: false) }, query: "test", root: root)

        pane.setFilterQuery("alpha")
        #expect(pane.filteredItems.map(\.name) == ["Alpha.TXT"])

        pane.setFilterQuery(".PNG")
        #expect(pane.filteredItems.map(\.name) == ["beta.png"])

        pane.setFilterQuery("notes")
        #expect(pane.filteredItems.map(\.name) == ["Meeting Notes.md"])

        pane.clearFilter()
        #expect(pane.filteredItems.count == 3)
    }

    @Test("Hiding the active sort column falls back to Name")
    func listColumnVisibility() {
        let pane = PaneModel(location: FileManager.default.temporaryDirectory)
        pane.sort = .size
        pane.ascending = false

        pane.setListColumn(.size, isVisible: false)

        #expect(!pane.visibleListColumns.contains(.size))
        #expect(pane.sort == .name)
        #expect(pane.ascending)
    }

    @Test("Column chooser contains every Finder list column")
    func finderListColumns() {
        #expect(FileListColumn.allCases.map(\.rawValue) == [
            "Shared By",
            "Date Modified",
            "Date Created",
            "Date Last Opened",
            "Size",
            "Version",
            "Kind",
            "Comments",
            "Tags",
            "Date Added",
            "iCloud Status"
        ])
        #expect(FileListColumn.defaults == [.kind, .size, .modified])
    }

    @Test("List column widths are adjustable, bounded, and resettable")
    func listColumnWidths() {
        let pane = PaneModel(location: FileManager.default.temporaryDirectory)

        #expect(pane.listColumnWidth(for: .size) == FileListColumn.size.defaultWidth)

        pane.setListColumnWidth(.size, to: 144)
        #expect(pane.listColumnWidth(for: .size) == 144)

        pane.setListColumnWidth(.size, to: 1)
        #expect(pane.listColumnWidth(for: .size) == FileListColumn.size.minimumWidth)

        pane.setListColumnWidth(.size, to: 1_000)
        #expect(pane.listColumnWidth(for: .size) == FileListColumn.size.maximumWidth)

        pane.resetListColumnWidth(.size)
        #expect(pane.listColumnWidth(for: .size) == FileListColumn.size.defaultWidth)
    }

    @Test("Terminal height is adjustable, bounded, and resettable")
    func terminalHeight() {
        let pane = PaneModel(location: FileManager.default.temporaryDirectory)

        #expect(pane.terminalHeight == PaneModel.defaultTerminalHeight)

        pane.setTerminalHeight(320)
        #expect(pane.terminalHeight == 320)

        pane.setTerminalHeight(1)
        #expect(pane.terminalHeight == PaneModel.minimumTerminalHeight)

        pane.setTerminalHeight(10_000)
        #expect(pane.terminalHeight == PaneModel.maximumTerminalHeight)

        // A drag can never push the terminal past what the pane can show.
        pane.setTerminalHeight(10_000, maximum: 240)
        #expect(pane.terminalHeight == 240)

        // A short pane trims the stored height without forgetting it.
        pane.setTerminalHeight(400)
        #expect(pane.terminalHeight(forPaneHeight: 500) == 330)
        #expect(pane.terminalHeight(forPaneHeight: 4_000) == 400)
        #expect(pane.terminalHeight(forPaneHeight: 100) == PaneModel.minimumTerminalHeight)
        #expect(pane.terminalHeight == 400)

        pane.resetTerminalHeight()
        #expect(pane.terminalHeight == PaneModel.defaultTerminalHeight)
    }

    @Test("Folder size calculation exposes its active toolbar state")
    func folderSizeToolbarState() {
        let pane = PaneModel(location: FileManager.default.temporaryDirectory)
        #expect(!pane.folderSizesEnabledForActiveTab)

        pane.calculateFolderSizesForTab()

        #expect(pane.folderSizesEnabledForActiveTab)
    }

    @Test("Permission errors are identified without matching localized text")
    func permissionErrors() {
        let cocoa = NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadNoPermission.rawValue)
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.EPERM.rawValue))
        let unrelated = NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileNoSuchFile.rawValue)

        #expect(PaneModel.isPermissionDenied(cocoa))
        #expect(PaneModel.isPermissionDenied(posix))
        #expect(!PaneModel.isPermissionDenied(unrelated))
    }
}
