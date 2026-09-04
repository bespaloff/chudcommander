import AppKit
import SwiftUI

enum FileDragPayload {
    static func urls(for itemURL: URL, selectedURLs: [URL]) -> [URL] {
        selectedURLs.contains(itemURL) ? selectedURLs : [itemURL]
    }

    static func draggingItems(for urls: [URL], at point: NSPoint) -> [NSDraggingItem] {
        urls.enumerated().map { index, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage)
                ?? NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)
            let offset = CGFloat(min(index, 4)) * 3
            let frame = NSRect(
                x: point.x - 16 + offset,
                y: point.y - 16 - offset,
                width: 32,
                height: 32
            )
            item.setDraggingFrame(frame, contents: icon)
            return item
        }
    }
}

struct FileDragSource: NSViewRepresentable {
    let itemURL: URL
    let tooltip: String
    let selectedURLs: () -> [URL]
    let onSelect: (_ extending: Bool, _ clickCount: Int) -> Void
    let onDragEnded: (NSDragOperation) -> Void

    func makeNSView(context: Context) -> FileDragSourceView {
        let view = FileDragSourceView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: FileDragSourceView, context: Context) {
        view.itemURL = itemURL
        view.toolTip = tooltip
        view.selectedURLs = selectedURLs
        view.onSelect = onSelect
        view.onDragEnded = onDragEnded
    }
}

final class FileDragSourceView: NSView, NSDraggingSource {
    var itemURL: URL?
    var selectedURLs: (() -> [URL])?
    var onSelect: ((Bool, Int) -> Void)?
    var onDragEnded: ((NSDragOperation) -> Void)?

    private var mouseDownLocation: NSPoint?
    private var startedDragging = false

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let rightButtonMask = 1 << 1
        if NSEvent.pressedMouseButtons & rightButtonMask != 0
            || NSApp.currentEvent?.type == .rightMouseDown
        {
            return nil
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        startedDragging = false
        onSelect?(event.modifierFlags.contains(.command), event.clickCount)
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            !startedDragging,
            let itemURL,
            let mouseDownLocation,
            hypot(event.locationInWindow.x - mouseDownLocation.x, event.locationInWindow.y - mouseDownLocation.y) >= 3
        else { return }

        startedDragging = true
        let urls = FileDragPayload.urls(for: itemURL, selectedURLs: selectedURLs?() ?? [])
        let point = convert(event.locationInWindow, from: nil)
        let items = FileDragPayload.draggingItems(for: urls, at: point)
        guard !items.isEmpty else { return }

        let session = beginDraggingSession(with: items, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func rightMouseDown(with event: NSEvent) {
        forwardToUnderlyingView(event) { $0.rightMouseDown(with: event) }
    }

    override func scrollWheel(with event: NSEvent) {
        guard let scrollView = enclosingScrollView else {
            super.scrollWheel(with: event)
            return
        }
        scrollView.scrollWheel(with: event)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        [.copy, .move, .link]
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        onDragEnded?(operation)
    }

    private func forwardToUnderlyingView(_ event: NSEvent, action: (NSView) -> Void) {
        guard let contentView = window?.contentView else { return }
        isHidden = true
        let target = contentView.hitTest(contentView.convert(event.locationInWindow, from: nil))
        isHidden = false
        guard let target, target !== self else { return }
        action(target)
    }
}
