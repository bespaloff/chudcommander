import Foundation
import Testing
@testable import MacCommander

@Suite("Dragging tabs")
@MainActor
struct TabDragTests {
    @Test("The anchor tab cannot be dragged")
    func anchorTabStaysPut() throws {
        let workspace = try Workspace()
        defer { workspace.tearDown() }

        let state = workspace.state
        let anchor = state.leftPane.tabs[0]
        state.leftPane.addTab(location: workspace.folder("second"))

        #expect(state.leftPane.isAnchorTab(anchor.id))
        #expect(!state.leftPane.canMoveTab(anchor.id))
        #expect(state.leftPane.canMoveTab(state.leftPane.tabs[1].id))
        #expect(!state.leftPane.moveTab(anchor.id, to: 2))
        #expect(state.leftPane.tabs[0].id == anchor.id)
    }

    @Test("A tab reorders inside its own pane")
    func reordersWithinPane() throws {
        let workspace = try Workspace()
        defer { workspace.tearDown() }

        let state = workspace.state
        state.leftPane.addTab(location: workspace.folder("second"))
        state.leftPane.addTab(location: workspace.folder("third"))
        let moved = state.leftPane.tabs[2]

        state.moveTab(TabDragPayload(side: .left, tabID: moved.id), to: .left, at: 1)

        #expect(state.leftPane.tabs.map(\.id)[1] == moved.id)
        #expect(state.leftPane.tabs.count == 3)
    }

    @Test("A drop in front of the anchor tab lands behind it instead")
    func neverDropsBeforeTheAnchor() throws {
        let workspace = try Workspace()
        defer { workspace.tearDown() }

        let state = workspace.state
        let anchor = state.leftPane.tabs[0]
        state.leftPane.addTab(location: workspace.folder("second"))
        let moved = state.leftPane.tabs[1]

        state.moveTab(TabDragPayload(side: .left, tabID: moved.id), to: .left, at: 0)

        #expect(state.leftPane.tabs.map(\.id) == [anchor.id, moved.id])
    }

    @Test("A tab dragged to the other pane leaves the first and activates the second")
    func movesTabAcrossPanes() throws {
        let workspace = try Workspace()
        defer { workspace.tearDown() }

        let state = workspace.state
        let second = workspace.folder("second")
        state.leftPane.addTab(location: second)
        let moved = state.leftPane.tabs[1]

        state.moveTab(TabDragPayload(side: .left, tabID: moved.id), to: .right, at: 1)

        #expect(state.leftPane.tabs.count == 1)
        #expect(state.rightPane.tabs.map(\.id).contains(moved.id))
        #expect(state.rightPane.tabs[1].id == moved.id)
        #expect(state.rightPane.activeTabID == moved.id)
        #expect(state.rightPane.location == second.standardizedFileURL)
        #expect(state.activeSide == .right)
    }

    @Test("A tab dropped past the end of the other pane goes last")
    func clampsDropIndexToTabCount() throws {
        let workspace = try Workspace()
        defer { workspace.tearDown() }

        let state = workspace.state
        state.rightPane.addTab(location: workspace.folder("right-second"))
        state.leftPane.addTab(location: workspace.folder("second"))
        let moved = state.leftPane.tabs[1]

        state.moveTab(TabDragPayload(side: .left, tabID: moved.id), to: .right, at: .max)

        #expect(state.rightPane.tabs.last?.id == moved.id)
    }

    @Test("The anchor tab cannot be handed to the other pane")
    func anchorTabNeverLeavesItsPane() throws {
        let workspace = try Workspace()
        defer { workspace.tearDown() }

        let state = workspace.state
        let anchor = state.leftPane.tabs[0]
        let moved = state.moveTab(TabDragPayload(side: .left, tabID: anchor.id), to: .right, at: 1)

        #expect(!moved)
        #expect(state.leftPane.tabs.count == 1)
        #expect(state.rightPane.tabs.count == 1)
    }

    @Test("A drag payload survives a round trip and rejects foreign text")
    func encodesAndDecodesPayload() {
        let payload = TabDragPayload(side: .right, tabID: UUID())

        #expect(TabDragPayload(encoded: payload.encoded) == payload)
        #expect(TabDragPayload(encoded: "https://example.com") == nil)
        #expect(TabDragPayload(encoded: "chad-commander.tab:left:not-a-uuid") == nil)
        #expect(TabDragPayload(encoded: "other.app:left:\(UUID().uuidString)") == nil)
    }

    @Test("The insertion slot follows the pointer past each tab's midpoint")
    func computesInsertionIndex() {
        let midpoints: [CGFloat] = [20, 60, 100]

        #expect(TabStripLayout.insertionIndex(forX: 0, tabMidpoints: midpoints) == 1)
        #expect(TabStripLayout.insertionIndex(forX: 30, tabMidpoints: midpoints) == 1)
        #expect(TabStripLayout.insertionIndex(forX: 70, tabMidpoints: midpoints) == 2)
        #expect(TabStripLayout.insertionIndex(forX: 400, tabMidpoints: midpoints) == 3)
        #expect(TabStripLayout.insertionIndex(forX: 400, tabMidpoints: []) == 1)
    }

    @MainActor
    private struct Workspace {
        let state: AppState
        let root: URL
        private let preferences: UserDefaults
        private let suiteName: String

        init() throws {
            suiteName = "TabDragTests.\(UUID().uuidString)"
            preferences = UserDefaults(suiteName: suiteName)!
            root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            state = AppState(onboardingPreferences: preferences)
        }

        func folder(_ name: String) -> URL {
            let url = root.appendingPathComponent(name)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        func tearDown() {
            try? FileManager.default.removeItem(at: root)
            preferences.removePersistentDomain(forName: suiteName)
        }
    }
}
