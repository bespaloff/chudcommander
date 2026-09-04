import Foundation
import Testing
@testable import MacCommander

@Suite("File drag source")
struct FileDragSourceTests {
    @Test("Dragging a selected item carries the full selection")
    func selectedItems() {
        let first = URL(fileURLWithPath: "/tmp/first.txt")
        let second = URL(fileURLWithPath: "/tmp/second.txt")

        #expect(FileDragPayload.urls(for: first, selectedURLs: [first, second]) == [first, second])
    }

    @Test("Dragging an unselected item carries only that item")
    func unselectedItem() {
        let dragged = URL(fileURLWithPath: "/tmp/dragged.txt")
        let selected = URL(fileURLWithPath: "/tmp/selected.txt")

        #expect(FileDragPayload.urls(for: dragged, selectedURLs: [selected]) == [dragged])
    }

    @Test("Native dragging items retain their file URLs")
    @MainActor
    func nativeDraggingItems() {
        let file = URL(fileURLWithPath: "/tmp/drag-me.txt")
        let folder = URL(fileURLWithPath: "/tmp/drag-folder", isDirectory: true)
        let items = FileDragPayload.draggingItems(for: [file, folder], at: .zero)

        #expect(items.compactMap { $0.item as? NSURL }.map { $0 as URL } == [file, folder])
    }
}
