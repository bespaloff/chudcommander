import AppKit
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

    @Test("Wheel events over draggable rows reach the enclosing panel")
    @MainActor
    func forwardsWheelEventsToPanel() throws {
        let scrollView = WheelRecordingScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 640))
        let dragSource = FileDragSourceView(frame: NSRect(x: 0, y: 0, width: 320, height: 20))
        scrollView.documentView = documentView
        documentView.addSubview(dragSource)

        let cgEvent = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 1,
                wheel1: -1,
                wheel2: 0,
                wheel3: 0
            )
        )
        let wheelEvent = try #require(NSEvent(cgEvent: cgEvent))

        dragSource.scrollWheel(with: wheelEvent)

        #expect(scrollView.receivedWheelEvents == 1)
    }
}

@MainActor
private final class WheelRecordingScrollView: NSScrollView {
    private(set) var receivedWheelEvents = 0

    override func scrollWheel(with event: NSEvent) {
        receivedWheelEvents += 1
    }
}
